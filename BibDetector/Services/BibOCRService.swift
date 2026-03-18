import CoreGraphics
import Foundation
import Vision

struct OCRBibResult {
    let bibNumber: String
    let confidence: Float
    let boundingBox: CGRect
}

actor BibOCRService {
    func detectBib(in pixelBuffer: CVPixelBuffer) async -> OCRBibResult? {
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["en_US"]
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
            try handler.perform([request])

            guard let observations = request.results else {
                return nil
            }

            return bestResult(from: observations)
        } catch {
            return nil
        }
    }
    private func bestResult(from observations: [VNRecognizedTextObservation]) -> OCRBibResult? {
        var best: OCRBibResult?

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

            if let currentBest = best {
                if candidate.confidence > currentBest.confidence {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }

        return best
    }
}
