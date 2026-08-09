import Foundation

struct PlantScan: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID
    var plantId: UUID?
    var photoUrl: String?
    var scanType: String
    var capturedAt: String
    var confidence: Double?
    var healthStatus: String?
    var healthScore: Int?
    var aiResultJson: AIScanPayload?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case plantId = "plant_id"
        case photoUrl = "photo_url"
        case scanType = "scan_type"
        case capturedAt = "captured_at"
        case confidence
        case healthStatus = "health_status"
        case healthScore = "health_score"
        case aiResultJson = "ai_result_json"
    }
}