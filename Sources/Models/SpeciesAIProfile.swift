import Foundation

/// Shared species facts captured from identify results (no image dependency).
struct SpeciesAIProfile: Codable, Identifiable, Hashable {
    var speciesKey: String
    var speciesLatinName: String
    var speciesCommonName: String?
    var family: String?
    var lightRequirement: String?
    var wateringIntervalDays: Int?
    var description: String?
    var nativeRegion: String?
    var matureSize: String?
    var growthRate: String?
    var toxicity: String?
    var funFact: String?
    var createdAt: String?
    var updatedAt: String?

    var id: String { speciesKey }

    enum CodingKeys: String, CodingKey {
        case speciesKey = "species_key"
        case speciesLatinName = "species_latin_name"
        case speciesCommonName = "species_common_name"
        case family
        case lightRequirement = "light_requirement"
        case wateringIntervalDays = "watering_interval_days"
        case description
        case nativeRegion = "native_region"
        case matureSize = "mature_size"
        case growthRate = "growth_rate"
        case toxicity
        case funFact = "fun_fact"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SpeciesAIProfileUpsert: Encodable {
    var speciesKey: String
    var speciesLatinName: String
    var speciesCommonName: String?
    var family: String?
    var lightRequirement: String?
    var wateringIntervalDays: Int?
    var description: String?
    var nativeRegion: String?
    var matureSize: String?
    var growthRate: String?
    var toxicity: String?
    var funFact: String?
    var raw: IdentificationAIResult
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case speciesKey = "species_key"
        case speciesLatinName = "species_latin_name"
        case speciesCommonName = "species_common_name"
        case family
        case lightRequirement = "light_requirement"
        case wateringIntervalDays = "watering_interval_days"
        case description
        case nativeRegion = "native_region"
        case matureSize = "mature_size"
        case growthRate = "growth_rate"
        case toxicity
        case funFact = "fun_fact"
        case raw
        case updatedAt = "updated_at"
    }

    init(from result: IdentificationAIResult) {
        let latin = result.speciesLatinName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.speciesKey = SpeciesCareGuideCache.speciesKey(from: latin)
        self.speciesLatinName = latin
        self.speciesCommonName = result.speciesCommonName
        self.family = result.family
        self.lightRequirement = result.lightRequirement
        self.wateringIntervalDays = result.wateringIntervalDays
        self.description = result.description
        self.nativeRegion = result.nativeRegion
        self.matureSize = result.matureSize
        self.growthRate = result.growthRate
        self.toxicity = result.toxicity
        self.funFact = result.funFact
        self.raw = result
        self.updatedAt = ISO8601DateFormatter().string(from: Date())
    }
}
