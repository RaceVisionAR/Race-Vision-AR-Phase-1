import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class RaceService: ObservableObject {
    @Published var races: [Race] = []
    @Published var isLoading = false
    @Published var fetchError: String?

    private let db = Firestore.firestore()

    func fetchRaces() async {
        isLoading = true
        fetchError = nil
        defer { isLoading = false }

        do {
            // Fetch test race and real races in parallel
            async let testDocTask = db.collection("races").document(Race.testRaceID).getDocument()
            async let racesSnapTask = db.collection("races")
                .whereField("isTestRace", isEqualTo: false)
                .whereField("status", in: ["upcoming", "active"])
                .order(by: "date")
                .getDocuments()

            let (testDoc, racesSnap) = try await (testDocTask, racesSnapTask)

            var result: [Race] = racesSnap.documents.compactMap { Race(document: $0) }

            // Always pin test race at the top if it exists in Firestore
            if let testRace = Race(document: testDoc) {
                result.insert(testRace, at: 0)
            }

            races = result
        } catch {
            fetchError = "Couldn't load races. Check your connection."
        }
    }

    func saveSelectedRace(_ race: Race, for uid: String) {
        db.collection("users").document(uid)
            .setData(["selectedRaceId": race.id], merge: true)
    }

    func restoreLastRace(for uid: String) async -> Race? {
        guard let doc = try? await db.collection("users").document(uid).getDocument(),
              let raceId = doc.data()?["selectedRaceId"] as? String else { return nil }
        return races.first { $0.id == raceId }
    }
}
