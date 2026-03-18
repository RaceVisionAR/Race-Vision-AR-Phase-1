import Foundation

final class RunnerRepository {
    private let runnersByBib: [String: RunnerProfile]

    init(runners: [RunnerProfile]) {
        self.runnersByBib = Dictionary(uniqueKeysWithValues: runners.map { ($0.bibNumber, $0) })
    }

    init(bundle: Bundle = .main, resourceName: String = "runners") {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([RunnerProfile].self, from: data) else {
            self.runnersByBib = [:]
            return
        }

        self.runnersByBib = Dictionary(uniqueKeysWithValues: decoded.map { ($0.bibNumber, $0) })
    }

    func matchRunner(bibNumber: String) -> RunnerProfile? {
        for candidate in BibParser.candidateVariants(for: bibNumber) {
            if let runner = runnersByBib[candidate] {
                return runner
            }
        }

        return nil
    }
}
