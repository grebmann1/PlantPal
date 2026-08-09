import Foundation
import Supabase

struct SpeciesSearchResponse: Decodable {
    var cached: Bool
    var page: Int?
    var lastPage: Int?
    var total: Int?
    var data: [SpeciesCatalog]

    enum CodingKeys: String, CodingKey {
        case cached, page, total, data
        case lastPage = "last_page"
    }
}

struct SpeciesDetailsResponse: Decodable {
    var cached: Bool
    var data: SpeciesCatalog?
}

enum SpeciesCatalogError: LocalizedError {
    case notConfigured
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "Plant catalog isn't ready yet — add a Perenual API key to the perenual-proxy edge function.")
        case .failed(let message):
            return message
        }
    }
}

/// Client for the caching Perenual proxy (`perenual-proxy` edge function).
enum SpeciesCatalogService {
    private struct ProxyRequest: Encodable {
        var action: String
        var q: String?
        var page: Int?
        var indoor: Bool?
        var id: Int?
        var scientific_name: String?
    }

    static func search(
        query: String = "",
        page: Int = 1,
        indoor: Bool = true
    ) async throws -> SpeciesSearchResponse {
        let request = ProxyRequest(
            action: "search",
            q: query.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            page: page,
            indoor: indoor
        )
        return try await invoke(request)
    }

    static func details(id: Int) async throws -> SpeciesCatalog {
        let response: SpeciesDetailsResponse = try await invoke(
            ProxyRequest(action: "details", id: id)
        )
        guard let species = response.data else {
            throw SpeciesCatalogError.failed(String(localized: "Species \(id) was not found."))
        }
        return species
    }

    static func lookup(scientificName: String) async throws -> SpeciesCatalog? {
        let trimmed = scientificName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let response: SpeciesDetailsResponse = try await invoke(
            ProxyRequest(action: "lookup", scientific_name: trimmed)
        )
        return response.data
    }

    private static func invoke<T: Decodable>(_ request: ProxyRequest) async throws -> T {
        do {
            return try await SupabaseManager.client.functions.invoke(
                "perenual-proxy",
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            let message = error.localizedDescription
            if message.contains("500")
                || message.lowercased().contains("not_configured")
                || message.lowercased().contains("perenual_api_key")
            {
                throw SpeciesCatalogError.notConfigured
            }
            throw SpeciesCatalogError.failed(message)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
