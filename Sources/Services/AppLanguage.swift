import Foundation

/// In-app language override. `system` follows the device language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case french = "fr"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: String(localized: "System")
        case .english: "English"
        case .french: "Français"
        case .german: "Deutsch"
        }
    }

    var shortLabel: String {
        switch self {
        case .system: String(localized: "System")
        case .english: "EN"
        case .french: "FR"
        case .german: "DE"
        }
    }

    /// Locale injected into the SwiftUI environment (`nil` = autoupdating system).
    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .english: Locale(identifier: "en")
        case .french: Locale(identifier: "fr")
        case .german: Locale(identifier: "de")
        }
    }

    /// BCP-47 language code used for API content translation (`en` means no translate).
    var contentLocaleCode: String {
        switch self {
        case .english: return "en"
        case .french: return "fr"
        case .german: return "de"
        case .system:
            let code = Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
            if code.hasPrefix("fr") { return "fr" }
            if code.hasPrefix("de") { return "de" }
            return "en"
        }
    }

    /// Active content locale for the current in-app language setting.
    static var contentLocale: String { stored.contentLocaleCode }

    static var stored: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: Keys.appLanguage) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }

    static func apply(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: Keys.appLanguage)
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english, .french, .german:
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }

    enum Keys {
        static let appLanguage = "pp.appLanguage"
    }
}
