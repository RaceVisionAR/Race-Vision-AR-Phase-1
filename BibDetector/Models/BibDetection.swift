import CoreGraphics
import Foundation

struct BibDetection: Equatable {
    let bibNumber: String
    let confidence: Float
    let boundingBox: CGRect // Vision normalized coordinates
    let timestamp: Date
}
