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
    var placement: PlantPlacement
    var addedDate: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, nickname, family, placement
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

    init(
        id: UUID,
        userId: UUID,
        nickname: String,
        speciesCommonName: String? = nil,
        speciesLatinName: String? = nil,
        family: String? = nil,
        photoUrl: String? = nil,
        healthScore: Int? = nil,
        nextWateringDate: String? = nil,
        wateringIntervalDays: Int? = nil,
        wateringAmountMl: Int? = nil,
        placement: PlantPlacement = .unknown,
        addedDate: String,
        createdAt: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.nickname = nickname
        self.speciesCommonName = speciesCommonName
        self.speciesLatinName = speciesLatinName
        self.family = family
        self.photoUrl = photoUrl
        self.healthScore = healthScore
        self.nextWateringDate = nextWateringDate
        self.wateringIntervalDays = wateringIntervalDays
        self.wateringAmountMl = wateringAmountMl
        self.placement = placement
        self.addedDate = addedDate
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        nickname = try c.decode(String.self, forKey: .nickname)
        speciesCommonName = try c.decodeIfPresent(String.self, forKey: .speciesCommonName)
        speciesLatinName = try c.decodeIfPresent(String.self, forKey: .speciesLatinName)
        family = try c.decodeIfPresent(String.self, forKey: .family)
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
        healthScore = try c.decodeIfPresent(Int.self, forKey: .healthScore)
        nextWateringDate = try c.decodeIfPresent(String.self, forKey: .nextWateringDate)
        wateringIntervalDays = try c.decodeIfPresent(Int.self, forKey: .wateringIntervalDays)
        wateringAmountMl = try c.decodeIfPresent(Int.self, forKey: .wateringAmountMl)
        placement = try c.decodeIfPresent(PlantPlacement.self, forKey: .placement) ?? .unknown
        addedDate = try c.decode(String.self, forKey: .addedDate)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    var healthStatus: HealthStatus { HealthStatus(score: healthScore) }
}