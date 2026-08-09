import Foundation

struct HealthAIResult: Codable {
    var status: String
    var healthScore: Int
    var issues: [HealthIssue]
    var recommendations: [String]

    enum CodingKeys: String, CodingKey {
        case status
        case healthScore = "health_score"
        case issues, recommendations
    }
}