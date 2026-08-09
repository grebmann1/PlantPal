import Foundation

struct IdentificationAIResult: Codable {
    var speciesCommonName: String
    var speciesLatinName: String
    var family: String
    var confidence: Double
    var lightRequirement: String
    var wateringIntervalDays: Int
    var alternateMatches: [AlternateMatch]

    // Extended species detail. All optional so older/cached responses that
    // don't include them still decode fine.
    var description: String?
    var nativeRegion: String?
    var matureSize: String?
    var growthRate: String?
    var toxicity: String?
    var funFact: String?

    enum CodingKeys: String, CodingKey {
        case speciesCommonName = "species_common_name"
        case speciesLatinName = "species_latin_name"
        case family, confidence
        case lightRequirement = "light_requirement"
        case wateringIntervalDays = "watering_interval_days"
        case alternateMatches = "alternate_matches"
        case description
        case nativeRegion = "native_region"
        case matureSize = "mature_size"
        case growthRate = "growth_rate"
        case toxicity
        case funFact = "fun_fact"
    }
}