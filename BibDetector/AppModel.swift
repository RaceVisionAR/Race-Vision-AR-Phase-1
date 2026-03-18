import ARKit
import AVFoundation
import Combine
import CoreGraphics
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var cameraAuthorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var isARSupported: Bool = ARWorldTrackingConfiguration.isSupported
    @Published var latestDetection: BibDetection?
    @Published var matchedRunner: RunnerProfile?
    @Published var overlayRect: CGRect?
    @Published var debugStatus: String = "Initializing"

    private let repository: RunnerRepository
    private let ocrService: BibOCRService

    private var isProcessingFrame = false
    private var lastOCRTime = Date.distantPast
    private var detectionHistory: [BibDetection] = []

    private let ocrInterval: TimeInterval = 0.2
    private let staleDetectionTTL: TimeInterval = 1.2

    init(ocrService: BibOCRService = BibOCRService()) {
        self.repository = RunnerRepository()
        self.ocrService = ocrService
    }

    func start() {
        cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        isARSupported = ARWorldTrackingConfiguration.isSupported
        debugStatus = "Ready"

        if cameraAuthorizationStatus == .notDetermined {
            Task {
                await requestCameraPermission()
            }
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
        clearStaleDetections()

        guard isARSupported else {
            debugStatus = "AR is not supported on this device"
            return
        }

        guard cameraAuthorizationStatus == .authorized else {
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastOCRTime) >= ocrInterval else {
            return
        }

        guard !isProcessingFrame else {
            return
        }

        isProcessingFrame = true
        lastOCRTime = now
        let pixelBuffer = frame.capturedImage

        Task { @MainActor in
            defer {
                isProcessingFrame = false
            }

            let detected = await ocrService.detectBib(in: pixelBuffer)
            handleOCRResult(detected, viewSize: viewSize)
        }
    }

    private func handleOCRResult(_ result: OCRBibResult?, viewSize: CGSize) {
        guard let result else {
            debugStatus = "Scanning for bib numbers"
            return
        }

        let detection = BibDetection(
            bibNumber: result.bibNumber,
            confidence: result.confidence,
            boundingBox: result.boundingBox,
            timestamp: Date()
        )

        detectionHistory.append(detection)
        detectionHistory = detectionHistory.filter {
            Date().timeIntervalSince($0.timestamp) <= staleDetectionTTL
        }

        guard let stabilized = stabilizedDetection() else {
            return
        }

        latestDetection = stabilized
        matchedRunner = repository.matchRunner(bibNumber: stabilized.bibNumber)
        overlayRect = convertVisionRectToView(stabilized.boundingBox, viewSize: viewSize)

        if let matchedRunner {
            debugStatus = "Bib \(stabilized.bibNumber) -> \(matchedRunner.displayName)"
        } else {
            debugStatus = "Bib \(stabilized.bibNumber) not found"
        }
    }

    private func stabilizedDetection() -> BibDetection? {
        guard !detectionHistory.isEmpty else {
            return nil
        }

        let grouped = Dictionary(grouping: detectionHistory, by: { $0.bibNumber })
        let bestGroup = grouped.max {
            if $0.value.count == $1.value.count {
                let lhsConfidence = $0.value.map(\.confidence).reduce(0, +)
                let rhsConfidence = $1.value.map(\.confidence).reduce(0, +)
                return lhsConfidence < rhsConfidence
            }
            return $0.value.count < $1.value.count
        }

        guard let detections = bestGroup?.value else {
            return nil
        }

        return detections.max(by: { $0.confidence < $1.confidence })
    }

    private func clearStaleDetections() {
        let now = Date()
        detectionHistory = detectionHistory.filter {
            now.timeIntervalSince($0.timestamp) <= staleDetectionTTL
        }

        if detectionHistory.isEmpty {
            latestDetection = nil
            matchedRunner = nil
            overlayRect = nil
        }
    }

    private func convertVisionRectToView(_ normalizedRect: CGRect, viewSize: CGSize) -> CGRect {
        let width = normalizedRect.width * viewSize.width
        let height = normalizedRect.height * viewSize.height
        let x = normalizedRect.minX * viewSize.width
        let y = (1 - normalizedRect.minY - normalizedRect.height) * viewSize.height

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
