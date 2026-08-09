import MapKit
import Foundation
import UIKit
import Supabase

struct AIProxyRequest: Encodable {
    var task: String
    var stream: Bool? = nil
    var image_base64: String? = nil
    var image_mime_type: String? = nil
    var species_latin_name: String? = nil
    var species_common_name: String? = nil
    var messages: [PlantExpertChatMessage.Wire]? = nil
    var plant_context: String? = nil
}

private struct IdentifyEnvelope: Decodable { var task: String; var result: IdentificationAIResult }
private struct HealthEnvelope: Decodable { var task: String; var result: HealthAIResult }
private struct CareGuideEnvelope: Decodable { var task: String; var result: CareGuideAIResult }
private struct PlantExpertEnvelope: Decodable { var task: String; var result: PlantExpertAIResult }

enum AIProxyError: LocalizedError {
    case notConfigured
    case timedOut
    case unavailable
    case failed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "Plant identification isn’t available right now. Please try again in a little while.")
        case .timedOut:
            return String(localized: "That took too long. Check your connection and try again.")
        case .unavailable:
            return String(localized: "We couldn’t reach the plant expert just now. Please try again.")
        case .failed:
            return String(localized: "Something went wrong while analyzing your plant. Please try again.")
        }
    }

    /// Whether the UI should offer the offline/demo fallback (Simulator only).
    var offersDemoFallback: Bool {
        guard DemoContent.isEnabled else { return false }
        switch self {
        case .notConfigured, .timedOut, .unavailable, .failed:
            return true
        }
    }

    /// Maps any thrown error into a friendly AIProxyError (never leaks Edge Function / HTTP jargon).
    static func from(_ error: Error) -> AIProxyError {
        if let known = error as? AIProxyError { return known }
        let message = error.localizedDescription.lowercased()
        if message.contains("timed out") || message.contains("timeout") {
            return .timedOut
        }
        if message.contains("not configured")
            || message.contains("api_key")
            || message.contains("api key")
            || message.contains("openai") {
            return .notConfigured
        }
        if message.contains("502")
            || message.contains("503")
            || message.contains("504")
            || message.contains("edge function")
            || message.contains("non-2xx")
            || message.contains("bad gateway")
            || message.contains("network")
            || message.contains("offline")
            || message.contains("connection") {
            return .unavailable
        }
        if message.contains("500") {
            return .unavailable
        }
        return .failed
    }
}

enum AIProxyService {
    static func identify(imageData: Data) async throws -> IdentificationAIResult {
        let preparedData = ImageCompressor.prepareForAI(imageData)
        guard !preparedData.isEmpty, UIImage(data: preparedData) != nil else {
            throw AIProxyError.failed
        }
        let request = AIProxyRequest(
            task: "identify",
            image_base64: preparedData.base64EncodedString(),
            image_mime_type: "image/jpeg"
        )
        let envelope: IdentifyEnvelope = try await invoke(request, timeout: 90)
        return envelope.result
    }

    static func health(imageData: Data, speciesLatinName: String?) async throws -> HealthAIResult {
        let preparedData = ImageCompressor.prepareForAI(imageData)
        guard !preparedData.isEmpty, UIImage(data: preparedData) != nil else {
            throw AIProxyError.failed
        }
        let request = AIProxyRequest(
            task: "health",
            image_base64: preparedData.base64EncodedString(),
            image_mime_type: "image/jpeg",
            species_latin_name: speciesLatinName
        )
        let envelope: HealthEnvelope = try await invoke(request, timeout: 90)
        return envelope.result
    }

    static func careGuide(speciesLatinName: String?, speciesCommonName: String?) async throws -> CareGuideAIResult {
        let request = AIProxyRequest(
            task: "care_guide",
            species_latin_name: speciesLatinName,
            species_common_name: speciesCommonName
        )
        let envelope: CareGuideEnvelope = try await invoke(request, timeout: 60)
        return envelope.result
    }

    static func plantExpert(
        messages: [PlantExpertChatMessage],
        plantContext: String
    ) async throws -> PlantExpertAIResult {
        let request = AIProxyRequest(
            task: "plant_expert",
            messages: messages.suffix(12).map(\.wire),
            plant_context: plantContext
        )
        let envelope: PlantExpertEnvelope = try await invoke(request, timeout: 60)
        return envelope.result
    }

    private static func invoke<T: Decodable>(_ request: AIProxyRequest, timeout: TimeInterval) async throws -> T {
        do {
            let response: T = try await SupabaseManager.client.functions.invoke(
                "ai-proxy",
                options: FunctionInvokeOptions(body: request, timeoutInterval: timeout)
            )
            return response
        } catch {
            throw AIProxyError.from(error)
        }
    }
}
