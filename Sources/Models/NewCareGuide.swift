import Foundation

struct NewCareGuide: Codable {
    var userId: UUID?
    var plantId: UUID?
    var speciesLatinName: String?
    var lightRequirement: String?
    var wateringFrequency: String?
    var wateringAmount: String?
    var soilMix: String?
    var temperatureRange: String?
    var humidityRange: String?
    var difficultyLevel: Int?
    var commonProblems: [CommonProblem]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case plantId = "plant_id"
        case speciesLatinName = "species_latin_name"
        case lightRequirement = "light_requirement"
        case wateringFrequency = "watering_frequency"
        case wateringAmount = "watering_amount"
        case soilMix = "soil_mix"
        case temperatureRange = "temperature_range"
        case humidityRange = "humidity_range"
        case difficultyLevel = "difficulty_level"
        case commonProblems = "common_problems"
    }
}