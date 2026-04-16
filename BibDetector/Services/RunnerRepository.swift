import FirebaseFirestore
import Foundation

final class RunnerRepository {
    let raceId: String
    private var runnersByBib: [String: RunnerProfile] = [:]
    private let db = Firestore.firestore()

    private var cacheURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        // Sanitize raceId for use as a filename
        let safeName = raceId.replacingOccurrences(of: "/", with: "_")
        return caches.appendingPathComponent("runners_\(safeName).json")
    }

    init(raceId: String) {
        self.raceId = raceId
    }

    // For previews and unit tests
    init(raceId: String = "preview", runners: [RunnerProfile]) {
        self.raceId = raceId
        self.runnersByBib = Dictionary(uniqueKeysWithValues: runners.map { ($0.bibNumber, $0) })
    }

    func load() async -> LoadResult {
        do {
            let snapshot = try await db
                .collection("races").document(raceId)
                .collection("runners")
                .getDocuments()

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
            return .fallback(count: 0)
        }
    }

    enum LoadResult {
        case loaded(count: Int)
        case fallback(count: Int)

        var isOffline: Bool {
            if case .fallback = self { return true }
            return false
        }

        var statusMessage: String {
            switch self {
            case .loaded(let count): return "Ready — \(count) runners"
            case .fallback(let count):
                return count > 0 ? "Offline — \(count) runners (cached)" : "Offline — no data"
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

    private func saveToDiskCache(_ runners: [RunnerProfile]) {
        guard let data = try? JSONEncoder().encode(runners) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func loadDiskCache() -> Bool {
        guard let data = try? Data(contentsOf: cacheURL),
              let runners = try? JSONDecoder().decode([RunnerProfile].self, from: data),
              !runners.isEmpty else { return false }
        runnersByBib = Dictionary(uniqueKeysWithValues: runners.map { ($0.bibNumber, $0) })
        return true
    }
}
