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

        var variants: [String] = [trimmed]

        let noLeadingZeros = String(trimmed.drop(while: { $0 == "0" }))
        if noLeadingZeros.isEmpty {
            return [trimmed]
        }

        if noLeadingZeros != trimmed {
            variants.append(noLeadingZeros)
        }

        // Also try zero-padded variants so "50" can match a JSON entry stored as "050"
        var seen = Set(variants)
        var padded = noLeadingZeros
        while padded.count < 5 {
            padded = "0" + padded
            if seen.insert(padded).inserted {
                variants.append(padded)
            }
        }

        return variants
    }
}
