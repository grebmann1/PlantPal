import Foundation

struct Plant: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID
    var nickname: String
    var speciesCommonName: String?
    var speciesLatinName: String?
    var family: String?
    var photoUrl: String?
    var healthScore: Int?
    var nextWateringDate: String?
    var wateringIntervalDays: Int?
    var wateringAmountMl: Int?
    var addedDate: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, nickname, family
        case userId = "user_id"
        case speciesCommonName = "species_common_name"
        case speciesLatinName = "species_latin_name"
        case photoUrl = "photo_url"
        case healthScore = "health_score"
        case nextWateringDate = "next_watering_date"
        case wateringIntervalDays = "watering_interval_days"
        case wateringAmountMl = "watering_amount_ml"
        case addedDate = "added_date"
        case createdAt = "created_at"
    }

    var healthStatus: HealthStatus { HealthStatus(score: healthScore) }
}