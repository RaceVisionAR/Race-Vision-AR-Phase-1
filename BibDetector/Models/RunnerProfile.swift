import Foundation

struct RunnerProfile: Codable, Equatable, Identifiable {
    let bibNumber: String
    let name: String
    let nickname: String?
    let team: String? = nil
    let category: String? = nil

    var id: String { bibNumber }

    var displayName: String {
        if let nickname, !nickname.isEmpty {
            return nickname
        }

        return name
    }
}
