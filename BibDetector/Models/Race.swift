import FirebaseFirestore
import Foundation

struct Race: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let date: Date?
    let location: String?
    let status: Status
    let isTestRace: Bool

    enum Status: String {
        case upcoming, active, completed
    }

    /// The fixed Firestore document ID reserved for the test race.
    static let testRaceID = "test"

    var displayName: String {
        isTestRace ? "Test Bibs" : name
    }

    var formattedDate: String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let name = data["name"] as? String, !name.isEmpty else { return nil }
        self.id = document.documentID
        self.name = name
        self.date = (data["date"] as? Timestamp)?.dateValue()
        self.location = data["location"] as? String
        self.isTestRace = data["isTestRace"] as? Bool ?? false
        let statusRaw = data["status"] as? String ?? "upcoming"
        self.status = Status(rawValue: statusRaw) ?? .upcoming
    }

    // For previews and tests
    init(id: String, name: String, date: Date? = nil, location: String? = nil,
         status: Status = .active, isTestRace: Bool = false) {
        self.id = id
        self.name = name
        self.date = date
        self.location = location
        self.status = status
        self.isTestRace = isTestRace
    }
}
