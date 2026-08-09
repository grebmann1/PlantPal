import Foundation

struct NewScan: Codable {
    var userId: UUID
    var plantId: UUID?
    var photoUrl: String?
    var scanType: String
    var confidence: Double?
    var healthStatus: String?
    var healthScore: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case plantId = "plant_id"
        case photoUrl = "photo_url"
        case scanType = "scan_type"
        case confidence
        case healthStatus = "health_status"
        case healthScore = "health_score"
    }
}