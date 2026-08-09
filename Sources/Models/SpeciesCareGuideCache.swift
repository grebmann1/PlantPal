import Foundation

/// Shared, cross-user care guide cached by normalized species key.
struct SpeciesCareGuideCache: Codable, Identifiable, Hashable {
    var speciesKey: String
    var speciesLatinName: String
    var speciesCommonName: String?
    var lightRequirement: String?
    var wateringFrequency: String?
    var wateringAmount: String?
    var soilMix: String?
    var temperatureRange: String?
    var humidityRange: String?
    var difficultyLevel: Int?
    var commonProblems: [CommonProblem]?
    var createdAt: String?
    var updatedAt: String?

    var id: String { speciesKey }

    enum CodingKeys: String, CodingKey {
        case speciesKey = "species_key"
        case speciesLatinName = "species_latin_name"
        case speciesCommonName = "species_common_name"
        case lightRequirement = "light_requirement"
        case wateringFrequency = "watering_frequency"
        case wateringAmount = "watering_amount"
        case soilMix = "soil_mix"
        case temperatureRange = "temperature_range"
        case humidityRange = "humidity_range"
        case difficultyLevel = "difficulty_level"
        case commonProblems = "common_problems"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func asCareGuide() -> CareGuide {
        CareGuide(
            id: UUID(),
            speciesLatinName: speciesLatinName,
            lightRequirement: lightRequirement,
            wateringFrequency: wateringFrequency,
            wateringAmount: wateringAmount,
            soilMix: soilMix,
            temperatureRange: temperatureRange,
            humidityRange: humidityRange,
            difficultyLevel: difficultyLevel,
            commonProblems: commonProblems
        )
    }

    static func speciesKey(from latinName: String) -> String {
        latinName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

struct SpeciesCareGuideUpsert: Encodable {
    var speciesKey: String
    var speciesLatinName: String
    var speciesCommonName: String?
    var lightRequirement: String?
    var wateringFrequency: String?
    var wateringAmount: String?
    var soilMix: String?
    var temperatureRange: String?
    var humidityRange: String?
    var difficultyLevel: Int?
    var commonProblems: [CommonProblem]?
    var raw: CareGuideAIResult
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case speciesKey = "species_key"
        case speciesLatinName = "species_latin_name"
        case speciesCommonName = "species_common_name"
        case lightRequirement = "light_requirement"
        case wateringFrequency = "watering_frequency"
        case wateringAmount = "watering_amount"
        case soilMix = "soil_mix"
        case temperatureRange = "temperature_range"
        case humidityRange = "humidity_range"
        case difficultyLevel = "difficulty_level"
        case commonProblems = "common_problems"
        case raw
        case updatedAt = "updated_at"
    }
}
