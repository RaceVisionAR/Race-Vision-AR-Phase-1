import FirebaseFirestore
import Foundation

final class RunnerRepository {
    private var runnersByBib: [String: RunnerProfile] = [:]
    private let db = Firestore.firestore()

    private static let cacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("runners_cache.json")
    }()

    nonisolated init(runners: [RunnerProfile]) {
        self.runnersByBib = Dictionary(uniqueKeysWithValues: runners.map { ($0.bibNumber, $0) })
    }

    init() {}

    func load() async -> LoadResult {
        do {
            let snapshot = try await db.collection("runners").getDocuments()

            if snapshot.documents.isEmpty {
                try await seedFirestore()
                saveToDiskCache(Array(runnersByBib.values))
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
            saveToDiskCache(runners)
            return .loaded(count: runners.count)
        } catch {
            if loadDiskCache() {
                return .fallback(count: runnersByBib.count)
            }
            loadLocalJSON()
            return .fallback(count: runnersByBib.count)
        }
    }

    enum LoadResult {
        case loaded(count: Int)
        case seeded(count: Int)
        case fallback(count: Int)

        var isOffline: Bool {
            if case .fallback = self { return true }
            return false
        }

        var statusMessage: String {
            switch self {
            case .loaded(let count): return "Ready — \(count) runners"
            case .seeded(let count): return "Ready — \(count) runners (seeded)"
            case .fallback(let count): return "Offline — \(count) runners (cached)"
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

    private func saveToDiskCache(_ runners: [RunnerProfile]) {
        guard let data = try? JSONEncoder().encode(runners) else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
    }

    private func loadDiskCache() -> Bool {
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let runners = try? JSONDecoder().decode([RunnerProfile].self, from: data),
              !runners.isEmpty else {
            return false
        }
        runnersByBib = Dictionary(uniqueKeysWithValues: runners.map { ($0.bibNumber, $0) })
        return true
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
