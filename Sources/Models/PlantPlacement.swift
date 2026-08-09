import Foundation

enum PlantPlacement: String, Codable, CaseIterable, Hashable {
    case indoor
    case balcony
    case unknown

    var label: String {
        switch self {
        case .indoor: return String(localized: "Indoor")
        case .balcony: return String(localized: "Balcony")
        case .unknown: return String(localized: "Unspecified")
        }
    }
}
