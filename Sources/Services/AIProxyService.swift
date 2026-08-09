import MapKit
import Foundation
import Supabase

struct AIProxyRequest: Encodable {
    var task: String
    var stream: Bool?
    var image_base64: String?
    var image_mime_type: String?
    var species_latin_name: String?
    var species_common_name: String?
}

private struct IdentifyEnvelope: Decodable { var task: String; var result: IdentificationAIResult }
private struct HealthEnvelope: Decodable { var task: String; var result: HealthAIResult }
private struct CareGuideEnvelope: Decodable { var task: String; var result: CareGuideAIResult }

enum AIProxyError: LocalizedError {
    case notConfigured
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI features aren't ready yet — the app owner still needs to connect an OpenAI key. Please try again later."
        case .failed(let message):
            return message
        }
    }
}

enum AIProxyService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    static func identify(imageData: Data) async throws -> IdentificationAIResult {
        let preparedData = ImageCompressor.prepareForAI(imageData)
        let request = AIProxyRequest(
            task: "identify",
            stream: nil,
            image_base64: preparedData.base64EncodedString(),
            image_mime_type: "image/jpeg"
        )
        let envelope: IdentifyEnvelope = try await invoke(request)
        return envelope.result
    }

    static func health(imageData: Data, speciesLatinName: String?) async throws -> HealthAIResult {
        let preparedData = ImageCompressor.prepareForAI(imageData)
        let request = AIProxyRequest(
            task: "health",
            stream: nil,
            image_base64: preparedData.base64EncodedString(),
            image_mime_type: "image/jpeg",
            species_latin_name: speciesLatinName
        )
        let envelope: HealthEnvelope = try await invoke(request)
        return envelope.result
    }

    static func careGuide(speciesLatinName: String?, speciesCommonName: String?) async throws -> CareGuideAIResult {
        let request = AIProxyRequest(
            task: "care_guide",
            stream: nil,
            species_latin_name: speciesLatinName,
            species_common_name: speciesCommonName
        )
        let envelope: CareGuideEnvelope = try await invoke(request)
        return envelope.result
    }

    private static func invoke<T: Decodable>(_ request: AIProxyRequest) async throws -> T {
        do {
            let response: T = try await SupabaseManager.client.functions.invoke(
                "ai-proxy",
                options: FunctionInvokeOptions(body: request)
            )
            return response
        } catch {
            let message = error.localizedDescription
            if message.lowercased().contains("timed out") || message.lowercased().contains("timeout") {
                throw AIProxyError.failed("The request timed out. Please check your connection and try again.")
            }
            if message.contains("500") || message.lowercased().contains("not configured") || message.lowercased().contains("api_key") {
                throw AIProxyError.notConfigured
            }
            throw AIProxyError.failed(message)
        }
    }
}
