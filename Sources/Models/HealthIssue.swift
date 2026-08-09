import Foundation

struct HealthIssue: Codable, Hashable, Identifiable {
    var id: String { label }
    var label: String
    var severity: String
    /// Optional subline (e.g. "4 leaves affected · likely overwatering"). Decode-tolerant.
    var detail: String?

    enum CodingKeys: String, CodingKey {
        case label, severity, detail
    }

    init(label: String, severity: String, detail: String? = nil) {
        self.label = label
        self.severity = severity
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        severity = try c.decode(String.self, forKey: .severity)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
    }
}
