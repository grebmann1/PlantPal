import Foundation

struct SpeciesActivity: Codable, Identifiable, Hashable {
    var species: SpeciesCatalog
    var isFavorite: Bool
    var lastViewedAt: String?

    var id: Int { species.id }

    enum CodingKeys: String, CodingKey {
        case species
        case isFavorite = "is_favorite"
        case lastViewedAt = "last_viewed_at"
    }
}

struct CloudSpeciesActivity: Decodable {
    var speciesId: Int
    var isFavorite: Bool
    var lastViewedAt: String?
    var species: SpeciesCatalog

    enum CodingKeys: String, CodingKey {
        case speciesId = "species_id"
        case isFavorite = "is_favorite"
        case lastViewedAt = "last_viewed_at"
        case species = "species_catalog"
    }
}

struct SpeciesActivityWrite: Encodable {
    var userId: UUID
    var speciesId: Int
    var isFavorite: Bool
    var lastViewedAt: String?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case speciesId = "species_id"
        case isFavorite = "is_favorite"
        case lastViewedAt = "last_viewed_at"
        case updatedAt = "updated_at"
    }
}

struct SpeciesFavoriteWrite: Encodable {
    var userId: UUID
    var speciesId: Int
    var isFavorite: Bool
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case speciesId = "species_id"
        case isFavorite = "is_favorite"
        case updatedAt = "updated_at"
    }
}
