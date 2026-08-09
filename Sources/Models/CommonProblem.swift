import Foundation

struct CommonProblem: Codable, Hashable, Identifiable {
    var id: String { problem }
    var problem: String
    var cause: String
    var fix: String
    var recoveryTime: String

    enum CodingKeys: String, CodingKey {
        case problem, cause, fix
        case recoveryTime = "recovery_time"
    }
}