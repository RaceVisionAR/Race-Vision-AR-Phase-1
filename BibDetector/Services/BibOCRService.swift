import CoreGraphics
import Foundation
import Vision

struct OCRBibResult {
    let bibNumber: String
    let confidence: Float
    let boundingBox: CGRect
}

actor BibOCRService {
    func detectBibs(in pixelBuffer: CVPixelBuffer) async -> [OCRBibResult] {
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["en_US"]
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        // Restrict OCR to the torso band (20%–85% from bottom in Vision coords).
        // Skips ground, feet, and sky — where bib numbers never appear.
        request.regionOfInterest = CGRect(x: 0.0, y: 0.20, width: 1.0, height: 0.65)

        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
            try handler.perform([request])

            guard let observations = request.results else {
                return []
            }

            return bestResults(from: observations)
        } catch {
            return []
        }
    }

    private func bestResults(from observations: [VNRecognizedTextObservation]) -> [OCRBibResult] {
        var resultsByBib: [String: OCRBibResult] = [:]

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first,
                  let bib = BibParser.normalizedBibCandidate(from: topCandidate.string) else {
                continue
            }

            let candidate = OCRBibResult(
                bibNumber: bib,
                confidence: topCandidate.confidence,
                boundingBox: observation.boundingBox
            )

            if let currentBest = resultsByBib[bib] {
                if candidate.confidence > currentBest.confidence {
                    resultsByBib[bib] = candidate
                }
            } else {
                resultsByBib[bib] = candidate
            }
        }

        return resultsByBib.values.sorted { lhs, rhs in
            lhs.confidence > rhs.confidence
        }
    }
}
