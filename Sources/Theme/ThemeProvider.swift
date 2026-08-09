import SwiftUI

// MARK: - Environment Integration

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.light
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - Theme Resolver (auto light/dark)

/// Wraps content and injects the correct theme based on system appearance.
/// Place at the app root (ContentView) — all child views inherit via @Environment(\.appTheme).
/// ⚠️ DO NOT MODIFY THIS FILE — it is infrastructure. Customize AppTheme.swift instead.
struct ThemeProvider<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content.environment(\.appTheme, colorScheme == .dark ? .dark : .light)
    }
}
