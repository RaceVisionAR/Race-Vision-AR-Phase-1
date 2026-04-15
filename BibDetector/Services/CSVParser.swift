import Foundation

enum CSVParser {

    // MARK: - Output types

    struct ParsedRow: Identifiable {
        let id = UUID()
        let rowNumber: Int
        let raceName: String
        let location: String?
        let bibNumber: String
        let name: String
        let nickname: String?
        let team: String?
        let category: String?
    }

    struct RowError: Identifiable {
        let id = UUID()
        let rowNumber: Int
        let rawLine: String
        let reason: String
    }

    /// Rows belonging to a single race, ready to upload as a group.
    struct RaceGroup: Identifiable {
        let id = UUID()
        let raceName: String
        let location: String?       // taken from the first row for this race
        let rows: [ParsedRow]
        let duplicateBibs: Set<String>
    }

    struct ParseResult {
        let raceGroups: [RaceGroup]
        let errors: [RowError]

        var isEmpty: Bool { raceGroups.isEmpty && errors.isEmpty }
        var totalRunners: Int { raceGroups.reduce(0) { $0 + $1.rows.count } }

        /// No hard errors and at least one runner to upload.
        var canUpload: Bool { !raceGroups.isEmpty && errors.isEmpty }

        var summary: String {
            var parts: [String] = []
            if !raceGroups.isEmpty {
                parts.append("\(raceGroups.count) race\(raceGroups.count == 1 ? "" : "s")")
                parts.append("\(totalRunners) runner\(totalRunners == 1 ? "" : "s")")
            }
            if !errors.isEmpty {
                parts.append("\(errors.count) error\(errors.count == 1 ? "" : "s")")
            }
            let allDupes = raceGroups.reduce(0) { $0 + $1.duplicateBibs.count }
            if allDupes > 0 {
                parts.append("\(allDupes) duplicate\(allDupes == 1 ? "" : "s")")
            }
            return parts.joined(separator: " · ")
        }
    }

    // MARK: - Parse

    /// Expected header (case-insensitive, any column order):
    ///   race, location, bib, name, nickname, team, category
    /// Required: race, bib, name.  Optional: location, nickname, team, category.
    static func parse(_ text: String) -> ParseResult {
        var lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return ParseResult(raceGroups: [], errors: [])
        }

        // Parse header
        let header = splitFields(lines.removeFirst()).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        guard let raceIdx = header.firstIndex(of: "race"),
              let bibIdx  = header.firstIndex(of: "bib"),
              let nameIdx = header.firstIndex(of: "name") else {
            let error = RowError(
                rowNumber: 1,
                rawLine: header.joined(separator: ","),
                reason: "Header must contain 'race', 'bib', and 'name' columns"
            )
            return ParseResult(raceGroups: [], errors: [error])
        }

        let locationIdx = header.firstIndex(of: "location")
        let nicknameIdx = header.firstIndex(of: "nickname")
        let teamIdx     = header.firstIndex(of: "team")
        let categoryIdx = header.firstIndex(of: "category")

        var rows: [ParsedRow] = []
        var errors: [RowError] = []

        for (offset, line) in lines.enumerated() {
            let rowNumber = offset + 2   // header is row 1
            let fields = splitFields(line)

            let maxRequired = max(raceIdx, bibIdx, nameIdx)
            guard fields.count > maxRequired else {
                errors.append(RowError(rowNumber: rowNumber, rawLine: line, reason: "Not enough columns"))
                continue
            }

            let raceName = fields[raceIdx].trimmingCharacters(in: .whitespaces)
            let bib      = fields[bibIdx].trimmingCharacters(in: .whitespaces)
            let name     = fields[nameIdx].trimmingCharacters(in: .whitespaces)

            if raceName.isEmpty {
                errors.append(RowError(rowNumber: rowNumber, rawLine: line, reason: "Race name is missing"))
                continue
            }
            if bib.isEmpty {
                errors.append(RowError(rowNumber: rowNumber, rawLine: line, reason: "Bib number is missing"))
                continue
            }
            if name.isEmpty {
                errors.append(RowError(rowNumber: rowNumber, rawLine: line, reason: "Runner name is missing"))
                continue
            }

            rows.append(ParsedRow(
                rowNumber: rowNumber,
                raceName: raceName,
                location: optionalField(at: locationIdx, in: fields),
                bibNumber: bib,
                name: name,
                nickname: optionalField(at: nicknameIdx, in: fields),
                team:     optionalField(at: teamIdx,     in: fields),
                category: optionalField(at: categoryIdx, in: fields)
            ))
        }

        // Group by race name, preserving order of first appearance
        var groupOrder: [String] = []
        var groupedRows: [String: [ParsedRow]] = [:]
        for row in rows {
            if groupedRows[row.raceName] == nil { groupOrder.append(row.raceName) }
            groupedRows[row.raceName, default: []].append(row)
        }

        let raceGroups: [RaceGroup] = groupOrder.compactMap { raceName in
            guard let groupRows = groupedRows[raceName] else { return nil }
            var bibCounts: [String: Int] = [:]
            groupRows.forEach { bibCounts[$0.bibNumber, default: 0] += 1 }
            let duplicateBibs = Set(bibCounts.filter { $0.value > 1 }.keys)
            return RaceGroup(
                raceName: raceName,
                location: groupRows.first?.location,
                rows: groupRows,
                duplicateBibs: duplicateBibs
            )
        }

        return ParseResult(raceGroups: raceGroups, errors: errors)
    }

    // MARK: - Helpers

    private static func optionalField(at index: Int?, in fields: [String]) -> String? {
        guard let idx = index, idx < fields.count else { return nil }
        let val = fields[idx].trimmingCharacters(in: .whitespaces)
        return val.isEmpty ? nil : val
    }

    /// Splits a CSV line into fields, respecting double-quoted values.
    private static func splitFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            switch char {
            case "\"":
                inQuotes.toggle()
            case "," where !inQuotes:
                fields.append(current)
                current = ""
            default:
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
