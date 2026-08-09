import Foundation
import Supabase

/// Shared, cross-user cache for species-stable AI outputs.
/// Care guides and identify profiles are written once and reused forever.
enum AISpeciesCacheService {
    static func fetchCareGuide(speciesLatinName: String) async throws -> SpeciesCareGuideCache? {
        let key = SpeciesCareGuideCache.speciesKey(from: speciesLatinName)
        guard !key.isEmpty else { return nil }
        let rows: [SpeciesCareGuideCache] = try await SupabaseManager.client
            .from("species_care_guides")
            .select()
            .eq("species_key", value: key)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    @discardableResult
    static func upsertCareGuide(
        speciesLatinName: String,
        speciesCommonName: String?,
        result: CareGuideAIResult
    ) async throws -> SpeciesCareGuideCache {
        let key = SpeciesCareGuideCache.speciesKey(from: speciesLatinName)
        let payload = SpeciesCareGuideUpsert(
            speciesKey: key,
            speciesLatinName: speciesLatinName.trimmingCharacters(in: .whitespacesAndNewlines),
            speciesCommonName: speciesCommonName,
            lightRequirement: result.lightRequirement,
            wateringFrequency: result.wateringFrequency,
            wateringAmount: result.wateringAmount,
            soilMix: result.soilMix,
            temperatureRange: result.temperatureRange,
            humidityRange: result.humidityRange,
            difficultyLevel: result.difficultyLevel,
            commonProblems: result.commonProblems,
            raw: result,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        let rows: [SpeciesCareGuideCache] = try await SupabaseManager.client
            .from("species_care_guides")
            .upsert(payload, onConflict: "species_key")
            .select()
            .execute()
            .value
        guard let saved = rows.first else {
            throw AIProxyError.failed
        }
        return saved
    }

    static func fetchProfile(speciesLatinName: String) async throws -> SpeciesAIProfile? {
        let key = SpeciesCareGuideCache.speciesKey(from: speciesLatinName)
        guard !key.isEmpty else { return nil }
        let rows: [SpeciesAIProfile] = try await SupabaseManager.client
            .from("species_ai_profiles")
            .select()
            .eq("species_key", value: key)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func upsertProfile(from result: IdentificationAIResult) async {
        let latin = result.speciesLatinName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latin.isEmpty else { return }
        let payload = SpeciesAIProfileUpsert(from: result)
        do {
            try await SupabaseManager.client
                .from("species_ai_profiles")
                .upsert(payload, onConflict: "species_key")
                .execute()
        } catch {
            // Best-effort enrichment — never block identification on cache writes.
            print("species_ai_profiles upsert failed: \(error.localizedDescription)")
        }
    }
}
