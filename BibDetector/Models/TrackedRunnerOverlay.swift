import CoreGraphics
import Foundation

enum TrackVisibilityStatus: String, Equatable {
    case probing
    case visible
    case fading
}

struct TrackedRunnerOverlay: Identifiable, Equatable {
    let bibNumber: String
    var runnerProfile: RunnerProfile?
    var latestDetection: BibDetection
    var overlayRect: CGRect
    var visibilityStatus: TrackVisibilityStatus
    var recentDetections: [BibDetection]
    let firstSeenAt: Date
    var lastSeenAt: Date
    var hasMetVisibilityThreshold: Bool

    var id: String { bibNumber }

    var latestBoundingBox: CGRect {
        latestDetection.boundingBox
    }

    var confidenceHistory: [Float] {
        recentDetections.map(\.confidence)
    }

    var displayName: String {
        runnerProfile?.displayName ?? "Bib \(bibNumber)"
    }

    var isRenderable: Bool {
        visibilityStatus == .visible || visibilityStatus == .fading
    }

    var overlayOpacity: Double = 1.0
}