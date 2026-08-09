import Foundation

struct CareGuide: Codable, Identifiable, Hashable {
    var id: UUID
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
        case id
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