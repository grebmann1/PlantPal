import Foundation

/// Thin helpers so non-`Text` call sites participate in the String Catalog.
enum L10n {
    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key)
    }

    static func format(_ key: String.LocalizationValue, _ args: CVarArg...) -> String {
        let format = String(localized: key)
        return String(format: format, locale: .current, arguments: args)
    }
}
