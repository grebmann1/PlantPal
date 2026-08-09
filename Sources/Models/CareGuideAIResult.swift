import Foundation

struct CareGuideAIResult: Codable, Hashable {
    var lightRequirement: String
    var wateringFrequency: String
    var wateringAmount: String
    var soilMix: String
    var temperatureRange: String
    var humidityRange: String
    var difficultyLevel: Int
    var commonProblems: [CommonProblem]

    enum CodingKeys: String, CodingKey {
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