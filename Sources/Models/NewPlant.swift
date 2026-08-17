import Foundation

struct NewPlant: Codable {
    var id: UUID? = nil
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
    }

    init(
        id: UUID? = nil,
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
        placement: PlantPlacement = .indoor
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
    }
}
