import FirebaseFirestore
import SwiftUI
import UniformTypeIdentifiers

struct AdminUploadView: View {
    @EnvironmentObject private var raceService: RaceService
    @Environment(\.dismiss) private var dismiss

    @State private var parseResult: CSVParser.ParseResult?
    @State private var showFilePicker = false
    @State private var uploadState: UploadState = .idle
    @State private var errorMessage: String?

    enum UploadState {
        case idle, uploading, done(uploaded: Int, races: Int)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        csvFormatHint
                        filePickerButton

                        if let result = parseResult, !result.isEmpty {
                            summaryBanner(result)

                            if !result.raceGroups.isEmpty {
                                ForEach(result.raceGroups) { group in
                                    raceGroupCard(group)
                                }
                            }

                            if !result.errors.isEmpty {
                                errorCard(result.errors)
                            }
                        }

                        if let errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(errorMessage).font(.system(size: 14))
                            }
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.horizontal, 24)
                        }

                        uploadButton
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 48)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Color(white: 0.18), in: Circle())
            }
            Spacer()
            Text("Upload Runners")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - CSV format hint

    private var csvFormatHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Required CSV Format", systemImage: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))

            Text("race, location, bib, name, nickname, team, category")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.green.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 10))

            Text("race, bib, name are required. Races are created automatically if they don't exist.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 24)
    }

    // MARK: - File picker button

    private var filePickerButton: some View {
        Button {
            parseResult = nil
            errorMessage = nil
            uploadState = .idle
            showFilePicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.plus").font(.system(size: 17))
                Text(parseResult == nil ? "Select CSV File" : "Choose Different File")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(white: 0.18), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Summary banner

    private func summaryBanner(_ result: CSVParser.ParseResult) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                summaryPill("\(result.raceGroups.count) race\(result.raceGroups.count == 1 ? "" : "s")",
                            icon: "flag.checkered", color: .green)
                summaryPill("\(result.totalRunners) runner\(result.totalRunners == 1 ? "" : "s")",
                            icon: "person.fill", color: .green)
                let dupes = result.raceGroups.reduce(0) { $0 + $1.duplicateBibs.count }
                if dupes > 0 {
                    summaryPill("\(dupes) duplicate\(dupes == 1 ? "" : "s")",
                                icon: "exclamationmark.circle.fill", color: .orange)
                }
                if !result.errors.isEmpty {
                    summaryPill("\(result.errors.count) error\(result.errors.count == 1 ? "" : "s")",
                                icon: "xmark.circle.fill", color: .red)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func summaryPill(_ label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(label).font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Race group card

    private func raceGroupCard(_ group: CSVParser.RaceGroup) -> some View {
        VStack(spacing: 0) {
            // Card header
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 1) {
                    Text(group.raceName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    if let location = group.location {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                Text("\(group.rows.count) runner\(group.rows.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(Color(white: 0.22))

            // Runner rows
            ForEach(group.rows) { row in
                RunnerPreviewRow(
                    bib: row.bibNumber,
                    name: row.name,
                    detail: [row.team, row.category].compactMap { $0 }.joined(separator: " · "),
                    isDuplicate: group.duplicateBibs.contains(row.bibNumber)
                )
                if row.id != group.rows.last?.id {
                    Divider().background(Color(white: 0.18)).padding(.leading, 16)
                }
            }
        }
        .background(Color(white: 0.13), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    // MARK: - Error card

    private func errorCard(_ errors: [CSVParser.RowError]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text("\(errors.count) row\(errors.count == 1 ? "" : "s") could not be parsed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(Color(white: 0.22))

            ForEach(errors) { err in
                VStack(alignment: .leading, spacing: 3) {
                    Text("Row \(err.rowNumber): \(err.reason)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red.opacity(0.9))
                    Text(err.rawLine)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if err.id != errors.last?.id {
                    Divider().background(Color(white: 0.18)).padding(.leading, 16)
                }
            }
        }
        .background(Color(white: 0.13), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    // MARK: - Upload button

    @ViewBuilder
    private var uploadButton: some View {
        switch uploadState {
        case .done(let count, let races):
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("\(count) runners uploaded across \(races) race\(races == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Button("Done") { dismiss() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)

        case .uploading:
            HStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Uploading…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(white: 0.18), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

        case .idle:
            let canUpload = parseResult?.canUpload ?? false
            Button {
                Task { await performUpload() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Upload \(parseResult?.totalRunners ?? 0) Runners")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.green, Color(red: 0, green: 0.6, blue: 0.4)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .shadow(color: .green.opacity(canUpload ? 0.3 : 0), radius: 10, y: 4)
                .padding(.horizontal, 24)
            }
            .disabled(!canUpload)
            .opacity(canUpload ? 1 : 0.4)
        }
    }

    // MARK: - File handler

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let text = try String(contentsOf: url, encoding: .utf8)
            let parsed = CSVParser.parse(text)

            if parsed.isEmpty {
                errorMessage = "The file appears to be empty."
            } else {
                parseResult = parsed
                errorMessage = nil
            }
        } catch {
            errorMessage = "Failed to read file: \(error.localizedDescription)"
        }
    }

    // MARK: - Upload

    private func performUpload() async {
        guard let result = parseResult, result.canUpload else { return }
        uploadState = .uploading
        errorMessage = nil

        do {
            var totalUploaded = 0
            for group in result.raceGroups {
                let raceId = try await findOrCreateRace(name: group.raceName, location: group.location)
                try await batchWriteRunners(group.rows, to: raceId)
                totalUploaded += group.rows.count
            }
            await raceService.fetchRaces()
            uploadState = .done(uploaded: totalUploaded, races: result.raceGroups.count)
        } catch {
            uploadState = .idle
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }

    /// Finds an existing race by name, or creates one with an auto-generated Firestore ID.
    private func findOrCreateRace(name: String, location: String?) async throws -> String {
        let db = Firestore.firestore()

        let snap = try await db.collection("races")
            .whereField("name", isEqualTo: name)
            .limit(to: 1)
            .getDocuments()

        if let existing = snap.documents.first {
            if let location, existing.data()["location"] as? String != location {
                try await existing.reference.updateData(["location": location])
            }
            return existing.documentID
        }

        // Auto-generated document ID
        let ref = db.collection("races").document()
        var data: [String: Any] = [
            "name": name,
            "status": "active",
            "isTestRace": false,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let location { data["location"] = location }
        try await ref.setData(data)
        return ref.documentID
    }

    /// Batch-writes runners to races/{raceId}/runners/{bibNumber} in chunks of 400.
    private func batchWriteRunners(_ rows: [CSVParser.ParsedRow], to raceId: String) async throws {
        let db = Firestore.firestore()
        let chunks = stride(from: 0, to: rows.count, by: 400).map {
            Array(rows[$0 ..< min($0 + 400, rows.count)])
        }
        for chunk in chunks {
            let batch = db.batch()
            for row in chunk {
                let ref = db.collection("races").document(raceId)
                    .collection("runners").document(row.bibNumber)
                var data: [String: Any] = ["name": row.name, "bibNumber": row.bibNumber]
                if let v = row.nickname { data["nickname"] = v }
                if let v = row.team     { data["team"] = v }
                if let v = row.category { data["category"] = v }
                batch.setData(data, forDocument: ref)
            }
            try await batch.commit()
        }
    }
}

// MARK: - Runner preview row

private struct RunnerPreviewRow: View {
    let bib: String
    let name: String
    let detail: String
    let isDuplicate: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(bib)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isDuplicate ? .orange : .green)
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                } else if isDuplicate {
                    Text("Duplicate — last entry used")
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.7))
                }
            }

            Spacer()

            Image(systemName: isDuplicate ? "exclamationmark.circle" : "checkmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(isDuplicate ? Color.orange.opacity(0.6) : Color.green.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    AdminUploadView()
        .environmentObject({
            let s = RaceService()
            s.races = [Race(id: "test", name: "Test Bibs", isTestRace: true)]
            return s
        }())
}
