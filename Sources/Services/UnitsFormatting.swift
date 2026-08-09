import Foundation

enum UnitsFormatting {
    static var usesMetric: Bool {
        UserDefaults.standard.object(forKey: "pp.unitsMetric") as? Bool ?? true
    }

    static var homeRegion: String {
        UserDefaults.standard.string(forKey: "pp.homeRegion") ?? "Lisbon, PT"
    }

    /// Formats a milliliter amount according to the user's unit preference.
    static func waterAmount(ml: Int) -> String {
        if usesMetric {
            return String(localized: "\(ml) ml")
        }
        let oz = Double(ml) / 29.5735
        return String(format: String(localized: "%.1f fl oz"), locale: .current, oz)
    }

    static func waterAmount(label: String?) -> String {
        guard let label, !label.isEmpty else { return String(localized: "—") }
        // If label already looks like a free-form string with units, pass through when metric;
        // when imperial and pure integer ml, convert.
        if usesMetric { return label }
        let digits = label.filter(\.isNumber)
        if let ml = Int(digits), label.lowercased().contains("ml") || digits.count == label.filter { !$0.isWhitespace }.count {
            return waterAmount(ml: ml)
        }
        return label
    }
}
