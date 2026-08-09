import Foundation

struct IdentificationAIResult: Codable, Hashable {
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

    init(
        speciesCommonName: String,
        speciesLatinName: String,
        family: String,
        confidence: Double,
        lightRequirement: String,
        wateringIntervalDays: Int,
        alternateMatches: [AlternateMatch],
        description: String? = nil,
        nativeRegion: String? = nil,
        matureSize: String? = nil,
        growthRate: String? = nil,
        toxicity: String? = nil,
        funFact: String? = nil
    ) {
        self.speciesCommonName = speciesCommonName
        self.speciesLatinName = speciesLatinName
        self.family = family
        self.confidence = Self.normalizeConfidence(confidence)
        self.lightRequirement = lightRequirement
        self.wateringIntervalDays = wateringIntervalDays
        self.alternateMatches = alternateMatches
        self.description = description
        self.nativeRegion = nativeRegion
        self.matureSize = matureSize
        self.growthRate = growthRate
        self.toxicity = toxicity
        self.funFact = funFact
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        speciesCommonName = try c.decode(String.self, forKey: .speciesCommonName)
        speciesLatinName = try c.decode(String.self, forKey: .speciesLatinName)
        family = try c.decode(String.self, forKey: .family)
        confidence = Self.normalizeConfidence(try c.decode(Double.self, forKey: .confidence))
        lightRequirement = try c.decode(String.self, forKey: .lightRequirement)
        if let days = try? c.decode(Int.self, forKey: .wateringIntervalDays) {
            wateringIntervalDays = days
        } else if let days = try? c.decode(Double.self, forKey: .wateringIntervalDays) {
            wateringIntervalDays = Int(days.rounded())
        } else {
            wateringIntervalDays = 7
        }
        alternateMatches = try c.decodeIfPresent([AlternateMatch].self, forKey: .alternateMatches) ?? []
        description = try c.decodeIfPresent(String.self, forKey: .description)
        nativeRegion = try c.decodeIfPresent(String.self, forKey: .nativeRegion)
        matureSize = try c.decodeIfPresent(String.self, forKey: .matureSize)
        growthRate = try c.decodeIfPresent(String.self, forKey: .growthRate)
        toxicity = try c.decodeIfPresent(String.self, forKey: .toxicity)
        funFact = try c.decodeIfPresent(String.self, forKey: .funFact)
    }

    static func normalizeConfidence(_ value: Double) -> Double {
        value > 1 ? value / 100 : value
    }
}
