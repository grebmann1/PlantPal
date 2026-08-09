import Foundation

enum HealthStatus: String, Codable {
    case healthy = "Healthy"
    case needsAttention = "Needs Attention"
    case atRisk = "At Risk"

    init(score: Int?) {
        switch score ?? 100 {
        case 80...: self = .healthy
        case 50..<80: self = .needsAttention
        default: self = .atRisk
        }
    }

    var shortLabel: String {
        switch self {
        case .healthy: return "Healthy"
        case .needsAttention: return "Needs attention"
        case .atRisk: return "At risk"
        }
    }
}