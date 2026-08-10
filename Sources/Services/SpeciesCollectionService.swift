import Foundation
import Supabase

enum SpeciesCollectionService {
    static func fetch(userId: UUID) async throws -> [SpeciesActivity] {
        let favorites: [CloudSpeciesActivity] = try await baseQuery(userId: userId)
            .eq("is_favorite", value: true)
            .execute()
            .value
        let recents: [CloudSpeciesActivity] = try await baseQuery(userId: userId)
            .order("last_viewed_at", ascending: false, nullsFirst: false)
            .limit(100)
            .execute()
            .value

        var rowsById: [Int: CloudSpeciesActivity] = [:]
        for row in favorites + recents {
            rowsById[row.speciesId] = row
        }

        return rowsById.values.map {
            SpeciesActivity(
                species: $0.species,
                isFavorite: $0.isFavorite,
                lastViewedAt: $0.lastViewedAt
            )
        }
    }

    private static func baseQuery(userId: UUID) -> PostgrestFilterBuilder {
        SupabaseManager.client
            .from("user_species_activity")
            .select(
                """
                species_id,is_favorite,last_viewed_at,
                species_catalog(
                  id,common_name,scientific_name,other_names,family,genus,cycle,
                  watering,sunlight,indoor,description,care_level,growth_rate,
                  image_url,image_urls,image_license,image_license_url,details_fetched
                )
                """
            )
            .eq("user_id", value: userId)
    }

    static func save(_ activity: SpeciesActivity, userId: UUID) async throws {
        let write = SpeciesActivityWrite(
            userId: userId,
            speciesId: activity.species.id,
            isFavorite: activity.isFavorite,
            lastViewedAt: activity.lastViewedAt,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        try await SupabaseManager.client
            .from("user_species_activity")
            .upsert(write, onConflict: "user_id,species_id")
            .execute()
    }

    static func saveFavorite(speciesId: Int, isFavorite: Bool, userId: UUID) async throws {
        let write = SpeciesFavoriteWrite(
            userId: userId,
            speciesId: speciesId,
            isFavorite: isFavorite,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        try await SupabaseManager.client
            .from("user_species_activity")
            .upsert(write, onConflict: "user_id,species_id")
            .execute()
    }

    static func delete(speciesId: Int, userId: UUID) async throws {
        try await SupabaseManager.client
            .from("user_species_activity")
            .delete()
            .eq("user_id", value: userId)
            .eq("species_id", value: speciesId)
            .execute()
    }
}

enum LocalSpeciesCollectionStore {
    private static let key = "pp.local.speciesActivity"

    static func load() -> [SpeciesActivity] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let activities = try? JSONDecoder().decode([SpeciesActivity].self, from: data) else {
            return []
        }
        return activities
    }

    static func save(_ activities: [SpeciesActivity]) {
        guard let data = try? JSONEncoder().encode(activities) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
