import Foundation

enum BibParser {
    nonisolated static func normalizedBibCandidate(from text: String) -> String? {
        let digits = text.filter(\.isNumber)
        guard (2...5).contains(digits.count) else {
            return nil
        }

        return digits
    }

    nonisolated static func candidateVariants(for bib: String) -> [String] {
        let trimmed = bib.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let noLeadingZeros = String(trimmed.drop(while: { $0 == "0" }))
        if noLeadingZeros.isEmpty {
            return [trimmed]
        }

        if noLeadingZeros == trimmed {
            return [trimmed]
        }

        return [trimmed, noLeadingZeros]
    }
}
