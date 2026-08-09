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
        case .healthy: return String(localized: "Healthy")
        case .needsAttention: return String(localized: "Needs attention")
        case .atRisk: return String(localized: "At risk")
        }
    }
}