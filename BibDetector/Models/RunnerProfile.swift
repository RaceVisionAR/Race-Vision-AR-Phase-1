import Foundation

struct RunnerProfile: Codable, Equatable, Identifiable {
    let bibNumber: String
    let name: String
    let nickname: String?
    let team: String?
    let category: String?

    var id: String { bibNumber }

    var displayName: String {
        if let nickname, !nickname.isEmpty {
            return nickname
        }

        return name
    }
}
