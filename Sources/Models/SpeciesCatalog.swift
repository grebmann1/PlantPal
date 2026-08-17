import Foundation

/// Canonical plant species from the Perenual-backed catalog.
/// Separate from user `Plant` specimens in the garden.
struct SpeciesCatalog: Codable, Identifiable, Hashable {
    var id: Int
    var commonName: String?
    var scientificName: String?
    var otherNames: [String]
    var family: String?
    var genus: String?
    var cycle: String?
    var watering: String?
    var sunlight: [String]
    var indoor: Bool?
    var description: String?
    var careLevel: String?
    var growthRate: String?
    /// Primary / hero image (first of `imageUrls`).
    var imageUrl: String?
    /// Up to 3 reference images (mirrored when available).
    var imageUrls: [String]
    var imageLicense: String?
    var imageLicenseUrl: String?
    var detailsFetched: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case otherNames = "other_names"
        case family, genus, cycle, watering, sunlight, indoor, description
        case careLevel = "care_level"
        case growthRate = "growth_rate"
        case imageUrl = "image_url"
        case imageUrls = "image_urls"
        case imageLicense = "image_license"
        case imageLicenseUrl = "image_license_url"
        case detailsFetched = "details_fetched"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        commonName = try c.decodeIfPresent(String.self, forKey: .commonName)
        scientificName = try c.decodeIfPresent(String.self, forKey: .scientificName)
        otherNames = try c.decodeIfPresent([String].self, forKey: .otherNames) ?? []
        family = try c.decodeIfPresent(String.self, forKey: .family)
        genus = try c.decodeIfPresent(String.self, forKey: .genus)
        cycle = try c.decodeIfPresent(String.self, forKey: .cycle)
        watering = try c.decodeIfPresent(String.self, forKey: .watering)
        sunlight = try c.decodeIfPresent([String].self, forKey: .sunlight) ?? []
        indoor = try c.decodeIfPresent(Bool.self, forKey: .indoor)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        careLevel = try c.decodeIfPresent(String.self, forKey: .careLevel)
        growthRate = try c.decodeIfPresent(String.self, forKey: .growthRate)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        let urls = try c.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        imageUrls = urls
        imageLicense = try c.decodeIfPresent(String.self, forKey: .imageLicense)
        imageLicenseUrl = try c.decodeIfPresent(String.self, forKey: .imageLicenseUrl)
        detailsFetched = try c.decodeIfPresent(Bool.self, forKey: .detailsFetched) ?? false
    }

    /// Resolved gallery URLs (falls back to single `imageUrl` for older payloads).
    var displayImageUrls: [String] {
        let trimmed = imageUrls
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !trimmed.isEmpty { return Array(trimmed.prefix(3)) }
        if let imageUrl, !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [imageUrl]
        }
        return []
    }

    var displayName: String {
        commonName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? scientificName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? String(localized: "Unknown species")
    }

    var sunlightLabel: String {
        sunlight.filter { !$0.isEmpty }.joined(separator: ", ").nilIfEmpty ?? String(localized: "—")
    }

    var wateringLabel: String {
        watering?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? String(localized: "—")
    }

    /// List responses can carry `details_fetched` from an older cached row while
    /// lacking the fields that only the details endpoint supplies.
    var hasUsableDetails: Bool {
        [description, careLevel, growthRate].contains { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty != nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
