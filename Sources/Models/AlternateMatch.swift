import Foundation

struct AlternateMatch: Codable, Hashable, Identifiable {
    var id: String { speciesLatinName }
    var speciesCommonName: String
    var speciesLatinName: String
    var confidence: Double

    enum CodingKeys: String, CodingKey {
        case speciesCommonName = "species_common_name"
        case speciesLatinName = "species_latin_name"
        case confidence
    }

    init(speciesCommonName: String, speciesLatinName: String, confidence: Double) {
        self.speciesCommonName = speciesCommonName
        self.speciesLatinName = speciesLatinName
        self.confidence = IdentificationAIResult.normalizeConfidence(confidence)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        speciesCommonName = try c.decode(String.self, forKey: .speciesCommonName)
        speciesLatinName = try c.decode(String.self, forKey: .speciesLatinName)
        confidence = IdentificationAIResult.normalizeConfidence(try c.decode(Double.self, forKey: .confidence))
    }
}
