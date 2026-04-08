import FirebaseFirestore
import Foundation

final class RunnerRepository {
    private var runnersByBib: [String: RunnerProfile] = [:]
    private let db = Firestore.firestore()

    nonisolated init(runners: [RunnerProfile]) {
        self.runnersByBib = Dictionary(uniqueKeysWithValues: runners.map { ($0.bibNumber, $0) })
    }

    init() {}

    func load() async -> LoadResult {
        do {
            let snapshot = try await db.collection("runners").getDocuments()

            if snapshot.documents.isEmpty {
                try await seedFirestore()
                return .seeded(count: runnersByBib.count)
            }

            let runners: [RunnerProfile] = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let name = data["name"] as? String, !name.isEmpty else { return nil }
                return RunnerProfile(
                    bibNumber: doc.documentID,
                    name: name,
                    nickname: data["nickname"] as? String,
                    team: data["team"] as? String,
                    category: data["category"] as? String
                )
            }

            runnersByBib = Dictionary(uniqueKeysWithValues: runners.map { ($0.bibNumber, $0) })
            return .loaded(count: runners.count)
        } catch {
            loadLocalJSON()
            return .fallback(count: runnersByBib.count)
        }
    }

    enum LoadResult {
        case loaded(count: Int)
        case seeded(count: Int)
        case fallback(count: Int)

        var statusMessage: String {
            switch self {
            case .loaded(let count): return "Ready — \(count) runners (Firestore)"
            case .seeded(let count): return "Ready — \(count) runners (seeded)"
            case .fallback(let count): return "Ready — \(count) runners (offline)"
            }
        }
    }

    func matchRunner(bibNumber: String) -> RunnerProfile? {
        for candidate in BibParser.candidateVariants(for: bibNumber) {
            if let runner = runnersByBib[candidate] {
                return runner
            }
        }
        return nil
    }

    // One-time migration: writes runners.json into Firestore then reloads.
    private func seedFirestore() async throws {
        guard let url = Bundle.main.url(forResource: "runners", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let runners = try? JSONDecoder().decode([RunnerProfile].self, from: data) else {
            loadLocalJSON()
            return
        }

        let batch = db.batch()
        for runner in runners {
            let ref = db.collection("runners").document(runner.bibNumber)
            var fields: [String: Any] = ["name": runner.name, "bibNumber": runner.bibNumber]
            if let nickname = runner.nickname { fields["nickname"] = nickname }
            if let team = runner.team { fields["team"] = team }
            if let category = runner.category { fields["category"] = category }
            batch.setData(fields, forDocument: ref)
        }
        try await batch.commit()

        runnersByBib = Dictionary(uniqueKeysWithValues: runners.map { ($0.bibNumber, $0) })
    }

    private func loadLocalJSON() {
        guard let url = Bundle.main.url(forResource: "runners", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([RunnerProfile].self, from: data) else {
            return
        }
        runnersByBib = Dictionary(uniqueKeysWithValues: decoded.map { ($0.bibNumber, $0) })
    }
}
