import ARKit
import AVFoundation
import Combine
import CoreGraphics
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var cameraAuthorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var isARSupported: Bool = ARWorldTrackingConfiguration.isSupported
    @Published var trackedOverlays: [String: TrackedRunnerOverlay] = [:]
    @Published var debugStatus: String = "Initializing"
    @Published var isLoadingRunners = false
    @Published var isOffline = false
    @Published var selectedRace: Race?

    private var repository: RunnerRepository = RunnerRepository(raceId: "preview")
    private let ocrService: BibOCRService

    private var isProcessingFrame = false
    private var lastOCRTime: Date = .distantPast
    private var recentStabilizedBibs: [String] = []
    private var cameraPortraitAspectRatio: CGFloat = 3.0 / 4.0

    /// Minimum interval between OCR passes. Keeps CPU/battery in check while
    /// still feeling responsive (~8 passes/sec).
    private let ocrInterval: TimeInterval = 0.12

    private let stabilizationWindow: TimeInterval = 0.8
    private let visibleGracePeriod: TimeInterval = 1.8
    private let fadeOutDuration: TimeInterval = 0.35
    private let minimumTrackConfidence: Float = 0.50
    private let maxTrackedCards: Int = 4

    /// True when at least one bib is in the stabilization phase but not yet confirmed.
    var isProbingBibs: Bool {
        trackedOverlays.values.contains { $0.visibilityStatus == .probing }
    }

    var visibleTracks: [TrackedRunnerOverlay] {
        trackedOverlays.values
            .filter(\.isRenderable)
            .filter { $0.runnerProfile != nil }
            .sorted { lhs, rhs in
                if lhs.visibilityStatus != rhs.visibilityStatus {
                    return lhs.visibilityStatus == .visible
                }
                return lhs.lastSeenAt > rhs.lastSeenAt
            }
    }

    init(ocrService: BibOCRService = BibOCRService()) {
        self.ocrService = ocrService
    }

    /// Clears all race and scan state — called on sign-out so a new user starts fresh.
    func reset() {
        selectedRace = nil
        trackedOverlays = [:]
        recentStabilizedBibs = []
        isLoadingRunners = false
        isOffline = false
        debugStatus = "Initializing"
        repository = RunnerRepository(raceId: "preview")
        lastOCRTime = .distantPast
    }

    /// Called by RaceSelectionView when a race is tapped. Resets all scan state
    /// and replaces the repository so the next start() loads the correct bibs.
    func selectRace(_ race: Race) {
        selectedRace = race
        repository = RunnerRepository(raceId: race.id)
        trackedOverlays = [:]
        recentStabilizedBibs = []
        debugStatus = "Race selected"
    }

    /// Called by ContentView.task — loads runners for the current race and
    /// ensures camera permission is resolved.
    func start() {
        guard selectedRace != nil else { return }

        cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        isARSupported = ARWorldTrackingConfiguration.isSupported
        debugStatus = "Loading runners..."
        isLoadingRunners = true
        isOffline = false

        Task {
            let result = await repository.load()
            isLoadingRunners = false
            isOffline = result.isOffline
            debugStatus = result.statusMessage
        }

        if cameraAuthorizationStatus == .notDetermined {
            Task { await requestCameraPermission() }
        }
    }

    func requestCameraPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraAuthorizationStatus = granted ? .authorized : .denied
        if !granted {
            debugStatus = "Camera permission denied"
        }
    }

    func processFrame(_ frame: ARFrame, viewSize: CGSize) {
        let res = frame.camera.imageResolution
        if res.width > 0 {
            cameraPortraitAspectRatio = res.height / res.width
        }
        refreshTrackLifecycle(viewSize: viewSize, now: Date())

        guard isARSupported else {
            debugStatus = "AR is not supported on this device"
            return
        }

        guard cameraAuthorizationStatus == .authorized else { return }
        guard !isProcessingFrame else { return }

        let now = Date()
        guard now.timeIntervalSince(lastOCRTime) >= ocrInterval else { return }

        isProcessingFrame = true
        lastOCRTime = now
        let pixelBuffer = frame.capturedImage
        let deviceOrientation = UIDevice.current.orientation

        Task { @MainActor in
            defer { isProcessingFrame = false }
            let detected = await ocrService.detectBibs(in: pixelBuffer, deviceOrientation: deviceOrientation)
            ingestOCRResults(detected, viewSize: viewSize, now: Date())
        }
    }

    func ingestOCRResults(_ results: [OCRBibResult], viewSize: CGSize, now: Date = Date()) {
        let prioritizedResults = Array(
            results
                .filter { $0.confidence >= minimumTrackConfidence }
                .sorted { $0.confidence > $1.confidence }
                .prefix(maxTrackedCards)
        )

        var detectedBibs = Set<String>()
        for result in prioritizedResults {
            upsertTrack(for: result, viewSize: viewSize, now: now)
            detectedBibs.insert(result.bibNumber)
        }

        refreshTrackLifecycle(viewSize: viewSize, now: now, detectedBibs: detectedBibs)
    }

    private func upsertTrack(for result: OCRBibResult, viewSize: CGSize, now: Date) {
        let detection = BibDetection(
            bibNumber: result.bibNumber,
            confidence: result.confidence,
            boundingBox: result.boundingBox,
            timestamp: now
        )

        let overlayRect = convertVisionRectToView(result.boundingBox, viewSize: viewSize)

        if var track = trackedOverlays[result.bibNumber] {
            track.latestDetection = detection
            track.overlayRect = overlayRect
            track.lastSeenAt = now
            track.recentDetections.append(detection)
            track.recentDetections = track.recentDetections.filter {
                now.timeIntervalSince($0.timestamp) <= stabilizationWindow
            }

            if track.hasMetVisibilityThreshold {
                track.visibilityStatus = .visible
            }

            trackedOverlays[result.bibNumber] = track
            return
        }

        // Single detection triggers overlay immediately
        let runnerProfile = repository.matchRunner(bibNumber: result.bibNumber)
        
        trackedOverlays[result.bibNumber] = TrackedRunnerOverlay(
            bibNumber: result.bibNumber,
            runnerProfile: runnerProfile,
            latestDetection: detection,
            overlayRect: overlayRect,
            visibilityStatus: .visible,
            recentDetections: [detection],
            firstSeenAt: now,
            lastSeenAt: now,
            hasMetVisibilityThreshold: true
        )
        
        registerStabilizedBib(result.bibNumber)
    }

    private func refreshTrackLifecycle(viewSize: CGSize, now: Date, detectedBibs: Set<String> = []) {
        var nextTracks = trackedOverlays

        for bibNumber in Array(nextTracks.keys) {
            guard var track = nextTracks[bibNumber] else { continue }

            track.recentDetections = track.recentDetections.filter {
                now.timeIntervalSince($0.timestamp) <= stabilizationWindow
            }
            track.overlayRect = convertVisionRectToView(track.latestBoundingBox, viewSize: viewSize)

            if detectedBibs.contains(bibNumber) {
                if track.hasMetVisibilityThreshold {
                    track.visibilityStatus = .visible
                    track.overlayOpacity = 1.0
                }
                nextTracks[bibNumber] = track
                continue
            }

            let timeSinceLastSeen = now.timeIntervalSince(track.lastSeenAt)

            if track.hasMetVisibilityThreshold {
                if timeSinceLastSeen > visibleGracePeriod + fadeOutDuration {
                    nextTracks.removeValue(forKey: bibNumber)
                    continue
                }

                if timeSinceLastSeen > visibleGracePeriod {
                    track.visibilityStatus = .fading
                    let fadeProgress = (timeSinceLastSeen - visibleGracePeriod) / fadeOutDuration
                    track.overlayOpacity = max(0.0, 1.0 - fadeProgress)
                } else {
                    track.visibilityStatus = .visible
                    track.overlayOpacity = 1.0
                }
                nextTracks[bibNumber] = track
                continue
            }

            if timeSinceLastSeen > stabilizationWindow {
                nextTracks.removeValue(forKey: bibNumber)
                continue
            }

            nextTracks[bibNumber] = track
        }

        trackedOverlays = nextTracks
        updateDebugStatus()
    }

    private func registerStabilizedBib(_ bibNumber: String) {
        recentStabilizedBibs.removeAll { $0 == bibNumber }
        recentStabilizedBibs.insert(bibNumber, at: 0)
        recentStabilizedBibs = Array(recentStabilizedBibs.prefix(3))
    }

    private func updateDebugStatus() {
        let visible = visibleTracks
        let probing = trackedOverlays.values
            .filter { $0.visibilityStatus == .probing }
            .sorted { $0.firstSeenAt < $1.firstSeenAt }

        var segments: [String] = []

        if !visible.isEmpty {
            let trackedLabels = visible.map(\.bibNumber).sorted().joined(separator: ", ")
            segments.append("Tracking \(visible.count) bib(s): \(trackedLabels)")
        } else if !probing.isEmpty {
            let probingLabels = probing.map(\.bibNumber).joined(separator: ", ")
            segments.append("Stabilizing \(probing.count) bib(s): \(probingLabels)")
        } else {
            segments.append("Scanning for bib numbers")
        }

        if !recentStabilizedBibs.isEmpty {
            segments.append("Recent: \(recentStabilizedBibs.joined(separator: ", "))")
        }

        debugStatus = segments.joined(separator: " • ")
    }

    private func convertVisionRectToView(_ normalizedRect: CGRect, viewSize: CGSize) -> CGRect {
        let viewAR = viewSize.width / viewSize.height

        let displayedWidth: CGFloat
        let displayedHeight: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if cameraPortraitAspectRatio > viewAR {
            displayedHeight = viewSize.height
            displayedWidth = viewSize.height * cameraPortraitAspectRatio
            offsetX = (displayedWidth - viewSize.width) / 2
            offsetY = 0
        } else {
            displayedWidth = viewSize.width
            displayedHeight = viewSize.width / cameraPortraitAspectRatio
            offsetX = 0
            offsetY = (displayedHeight - viewSize.height) / 2
        }

        let x = normalizedRect.minX * displayedWidth - offsetX
        let y = (1 - normalizedRect.maxY) * displayedHeight - offsetY
        let w = normalizedRect.width * displayedWidth
        let h = normalizedRect.height * displayedHeight

        return CGRect(x: x, y: y, width: w, height: h)
    }
}
