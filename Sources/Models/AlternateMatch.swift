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
}