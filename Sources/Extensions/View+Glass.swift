import SwiftUI

// MARK: - Glass Helpers (iOS 26 Liquid Glass with automatic fallback)
// ⚠️ DO NOT MODIFY THIS FILE — these helpers are used by all views.

extension View {
    @ViewBuilder
    func glassed(in shape: some Shape = Capsule(), interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let glass = interactive ? Glass.regular.interactive() : .regular
            self.glassEffect(glass, in: shape)
        } else {
            self.background(shape.fill(.ultraThinMaterial))
        }
        #else
        self.background(shape.fill(.ultraThinMaterial))
        #endif
    }

    @ViewBuilder
    func glassedTinted(_ color: Color, in shape: some Shape = Capsule()) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(color), in: shape)
        } else {
            self.background(shape.fill(.ultraThinMaterial))
                .tint(color)
        }
        #else
        self.background(shape.fill(.ultraThinMaterial))
            .tint(color)
        #endif
    }

    /// Wraps content in GlassEffectContainer on iOS 26 (enables glass morphing between nearby elements).
    @ViewBuilder
    func glassEffectContainerIfAvailable() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer { self }
        } else {
            self
        }
        #else
        self
        #endif
    }
}

// MARK: - Glass-Aware Theme Helpers

extension View {
    /// Card surface: Liquid Glass on iOS 26, solid surface + shadow on older iOS.
    @ViewBuilder
    func themeCard(_ theme: AppTheme) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
                .padding(theme.spacingMd)
                .glassEffect(.regular, in: .rect(cornerRadius: theme.cornerRadius))
        } else {
            self
                .padding(theme.spacingMd)
                .background(theme.surface)
                .clipShape(.rect(cornerRadius: theme.cornerRadius))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        #else
        self
            .padding(theme.spacingMd)
            .background(theme.surface)
            .clipShape(.rect(cornerRadius: theme.cornerRadius))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        #endif
    }

    /// Tinted glass card: uses theme.glassTint for branded glass surfaces.
    @ViewBuilder
    func themeTintedCard(_ theme: AppTheme) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
                .padding(theme.spacingMd)
                .glassEffect(.regular.tint(theme.glassTint), in: .rect(cornerRadius: theme.cornerRadius))
        } else {
            self
                .padding(theme.spacingMd)
                .background(theme.glassTint.opacity(0.1))
                .clipShape(.rect(cornerRadius: theme.cornerRadius))
        }
        #else
        self
            .padding(theme.spacingMd)
            .background(theme.glassTint.opacity(0.1))
            .clipShape(.rect(cornerRadius: theme.cornerRadius))
        #endif
    }

    /// Floating action: interactive glass capsule for buttons and CTAs.
    @ViewBuilder
    func themeFloatingAction(_ theme: AppTheme) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self.background(Capsule().fill(.ultraThinMaterial))
        }
        #else
        self.background(Capsule().fill(.ultraThinMaterial))
        #endif
    }
}
