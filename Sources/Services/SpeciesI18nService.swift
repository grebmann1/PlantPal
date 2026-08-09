import Foundation
import Supabase

/// Lazily translates English species API payloads into FR/DE via `translate-proxy`,
/// which permanently caches each `(kind, species, locale)` overlay.
enum SpeciesI18nService {
    enum Kind: String {
        case careGuide = "care_guide"
        case aiProfile = "ai_profile"
        case catalog = "catalog"
    }

    private struct TranslateRequest: Encodable {
        var kind: String
        var species_key: String
        var locale: String
        var fields: [String: AnyEncodable]
        var source_updated_at: String?
    }

    private struct TranslateResponse: Decodable {
        var cached: Bool?
        var fields: [String: AnyDecodable]
    }

    // MARK: - Public API

    static func localizeCareGuide(
        _ guide: CareGuide,
        speciesLatinName: String
    ) async -> CareGuide {
        let locale = AppLanguage.contentLocale
        guard locale != "en" else { return guide }

        let key = SpeciesCareGuideCache.speciesKey(from: speciesLatinName)
        guard !key.isEmpty else { return guide }

        var fields: [String: AnyEncodable] = [:]
        if let v = guide.lightRequirement { fields["light_requirement"] = AnyEncodable(v) }
        if let v = guide.wateringFrequency { fields["watering_frequency"] = AnyEncodable(v) }
        if let v = guide.wateringAmount { fields["watering_amount"] = AnyEncodable(v) }
        if let v = guide.soilMix { fields["soil_mix"] = AnyEncodable(v) }
        if let v = guide.temperatureRange { fields["temperature_range"] = AnyEncodable(v) }
        if let v = guide.humidityRange { fields["humidity_range"] = AnyEncodable(v) }
        if let problems = guide.commonProblems {
            fields["common_problems"] = AnyEncodable(problems.map { problem in
                [
                    "problem": problem.problem,
                    "cause": problem.cause,
                    "fix": problem.fix,
                    "recovery_time": problem.recoveryTime
                ] as [String: String]
            })
        }
        guard !fields.isEmpty else { return guide }

        do {
            let translated = try await translate(
                kind: .careGuide,
                speciesKey: key,
                locale: locale,
                fields: fields
            )
            return mergeCareGuide(guide, translated: translated)
        } catch {
            print("species_i18n care_guide failed: \(error.localizedDescription)")
            return guide
        }
    }

    static func localizeIdentification(
        _ result: IdentificationAIResult
    ) async -> IdentificationAIResult {
        let locale = AppLanguage.contentLocale
        guard locale != "en" else { return result }

        let key = SpeciesCareGuideCache.speciesKey(from: result.speciesLatinName)
        guard !key.isEmpty else { return result }

        var fields: [String: AnyEncodable] = [
            "species_common_name": AnyEncodable(result.speciesCommonName),
            "family": AnyEncodable(result.family),
            "light_requirement": AnyEncodable(result.lightRequirement)
        ]
        if let v = result.description { fields["description"] = AnyEncodable(v) }
        if let v = result.nativeRegion { fields["native_region"] = AnyEncodable(v) }
        if let v = result.matureSize { fields["mature_size"] = AnyEncodable(v) }
        if let v = result.growthRate { fields["growth_rate"] = AnyEncodable(v) }
        if let v = result.toxicity { fields["toxicity"] = AnyEncodable(v) }
        if let v = result.funFact { fields["fun_fact"] = AnyEncodable(v) }

        do {
            let translated = try await translate(
                kind: .aiProfile,
                speciesKey: key,
                locale: locale,
                fields: fields
            )
            return mergeIdentification(result, translated: translated)
        } catch {
            print("species_i18n ai_profile failed: \(error.localizedDescription)")
            return result
        }
    }

    static func localizeCatalog(_ species: SpeciesCatalog) async -> SpeciesCatalog {
        let locale = AppLanguage.contentLocale
        guard locale != "en" else { return species }

        let key = "catalog:\(species.id)"
        var fields: [String: AnyEncodable] = [:]
        if let v = species.commonName { fields["common_name"] = AnyEncodable(v) }
        if let v = species.description { fields["description"] = AnyEncodable(v) }
        if let v = species.watering { fields["watering"] = AnyEncodable(v) }
        if let v = species.careLevel { fields["care_level"] = AnyEncodable(v) }
        if let v = species.growthRate { fields["growth_rate"] = AnyEncodable(v) }
        if let v = species.cycle { fields["cycle"] = AnyEncodable(v) }
        guard !fields.isEmpty else { return species }

        do {
            let translated = try await translate(
                kind: .catalog,
                speciesKey: key,
                locale: locale,
                fields: fields
            )
            return mergeCatalog(species, translated: translated)
        } catch {
            print("species_i18n catalog failed: \(error.localizedDescription)")
            return species
        }
    }

    // MARK: - Proxy

    private static func translate(
        kind: Kind,
        speciesKey: String,
        locale: String,
        fields: [String: AnyEncodable]
    ) async throws -> [String: Any] {
        let request = TranslateRequest(
            kind: kind.rawValue,
            species_key: speciesKey,
            locale: locale,
            fields: fields,
            source_updated_at: nil
        )
        let response: TranslateResponse = try await SupabaseManager.client.functions.invoke(
            "translate-proxy",
            options: FunctionInvokeOptions(body: request)
        )
        return response.fields.mapValues(\.value)
    }

    // MARK: - Merge helpers

    private static func mergeCareGuide(_ guide: CareGuide, translated: [String: Any]) -> CareGuide {
        var out = guide
        if let v = translated["light_requirement"] as? String { out.lightRequirement = v }
        if let v = translated["watering_frequency"] as? String { out.wateringFrequency = v }
        if let v = translated["watering_amount"] as? String { out.wateringAmount = v }
        if let v = translated["soil_mix"] as? String { out.soilMix = v }
        if let v = translated["temperature_range"] as? String { out.temperatureRange = v }
        if let v = translated["humidity_range"] as? String { out.humidityRange = v }
        if let rawProblems = translated["common_problems"] as? [[String: Any]] {
            out.commonProblems = rawProblems.compactMap { dict in
                guard let problem = dict["problem"] as? String else { return nil }
                return CommonProblem(
                    problem: problem,
                    cause: dict["cause"] as? String ?? "",
                    fix: dict["fix"] as? String ?? "",
                    recoveryTime: dict["recovery_time"] as? String ?? ""
                )
            }
        }
        return out
    }

    private static func mergeIdentification(
        _ result: IdentificationAIResult,
        translated: [String: Any]
    ) -> IdentificationAIResult {
        var out = result
        if let v = translated["species_common_name"] as? String { out.speciesCommonName = v }
        if let v = translated["family"] as? String { out.family = v }
        if let v = translated["light_requirement"] as? String { out.lightRequirement = v }
        if let v = translated["description"] as? String { out.description = v }
        if let v = translated["native_region"] as? String { out.nativeRegion = v }
        if let v = translated["mature_size"] as? String { out.matureSize = v }
        if let v = translated["growth_rate"] as? String { out.growthRate = v }
        if let v = translated["toxicity"] as? String { out.toxicity = v }
        if let v = translated["fun_fact"] as? String { out.funFact = v }
        return out
    }

    private static func mergeCatalog(
        _ species: SpeciesCatalog,
        translated: [String: Any]
    ) -> SpeciesCatalog {
        var out = species
        if let v = translated["common_name"] as? String { out.commonName = v }
        if let v = translated["description"] as? String { out.description = v }
        if let v = translated["watering"] as? String { out.watering = v }
        if let v = translated["care_level"] as? String { out.careLevel = v }
        if let v = translated["growth_rate"] as? String { out.growthRate = v }
        if let v = translated["cycle"] as? String { out.cycle = v }
        return out
    }
}

// MARK: - Type-erased JSON helpers

struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        encodeFunc = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }
}
