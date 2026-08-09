import Foundation

struct HealthIssue: Codable, Hashable, Identifiable {
    var id: String { label }
    var label: String
    var severity: String
}