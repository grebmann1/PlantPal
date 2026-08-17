import Foundation

struct NewScan: Codable {
    var id: UUID? = nil
    var userId: UUID
    var plantId: UUID?
    var photoUrl: String?
    var scanType: String
    var confidence: Double?
    var healthStatus: String?
    var healthScore: Int?
    var aiResultJson: AIScanPayload?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case plantId = "plant_id"
        case photoUrl = "photo_url"
        case scanType = "scan_type"
        case confidence
        case healthStatus = "health_status"
        case healthScore = "health_score"
        case aiResultJson = "ai_result_json"
    }

    init(
        id: UUID? = nil,
        userId: UUID,
        plantId: UUID? = nil,
        photoUrl: String? = nil,
        scanType: String,
        confidence: Double? = nil,
        healthStatus: String? = nil,
        healthScore: Int? = nil,
        aiResultJson: AIScanPayload? = nil
    ) {
        self.id = id
        self.userId = userId
        self.plantId = plantId
        self.photoUrl = photoUrl
        self.scanType = scanType
        self.confidence = confidence
        self.healthStatus = healthStatus
        self.healthScore = healthScore
        self.aiResultJson = aiResultJson
    }
}

/// Typed wrapper so identify/health payloads can be stored in `scans.ai_result_json`.
enum AIScanPayload: Codable, Hashable {
    case identify(IdentificationAIResult)
    case health(HealthAIResult)

    private enum CodingKeys: String, CodingKey {
        case task, result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let task = try container.decode(String.self, forKey: .task)
        switch task {
        case "identify":
            self = .identify(try container.decode(IdentificationAIResult.self, forKey: .result))
        case "health":
            self = .health(try container.decode(HealthAIResult.self, forKey: .result))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .task,
                in: container,
                debugDescription: "Unknown AI scan task \(task)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .identify(let result):
            try container.encode("identify", forKey: .task)
            try container.encode(result, forKey: .result)
        case .health(let result):
            try container.encode("health", forKey: .task)
            try container.encode(result, forKey: .result)
        }
    }
}
