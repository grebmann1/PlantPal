import SwiftUI

// MARK: - Theme Definition

/// Centralized design system for this app. Edit tokens freely — all screens
/// should reference theme tokens, never hardcode colors or magic numbers.
///
/// Access in every view via `@Environment(\.appTheme) var theme`.
///
/// Token inventory (stable contract with the coder prompt):
///   Colors (16): primary, secondary, accent, background, surface, surfaceSecondary,
///                textPrimary, textSecondary, error, success,
///                onPrimary, surfaceElevated, surfaceSunken, textTertiary, separator, warning
///   Gradients: primaryGradient, backgroundGradient
///   Glass: glassTint
///   Fonts (legacy): displayFont, headingFont, bodyFont, captionFont
///   Fonts (DS scale): title1Font, title2Font, title3Font, headlineFont, calloutFont, subheadFont, footnoteFont
///   Spacing (legacy): spacingSm, spacingMd, spacingLg, spacingXl, cornerRadius, cornerRadiusSm, cornerRadiusLg
///   Spacing (DS): theme.spacing.s1…s16  (CGFloat)
///   Radii (DS):   theme.radius.xs / .sm / .md / .lg / .xl / .pill  (CGFloat)
///   Shadows:      theme.elevation.e1 / .e2 / .e3  — apply via `.appElevation(theme.elevation.eN)`
///   Motion:       theme.motion.easing (Animation) + .fast / .base / .slow (Double seconds)
struct AppTheme {
    // MARK: Colors — legacy 10-slot
    var primary: Color
    var secondary: Color
    var accent: Color
    var background: Color
    var surface: Color
    var surfaceSecondary: Color
    var textPrimary: Color
    var textSecondary: Color
    var error: Color
    var success: Color

    // MARK: Colors — DS semantic slots
    var onPrimary: Color
    var surfaceElevated: Color
    var surfaceSunken: Color
    var textTertiary: Color
    var separator: Color
    var warning: Color

    // MARK: Gradients & glass
    var primaryGradient: LinearGradient
    var backgroundGradient: LinearGradient
    var glassTint: Color

    // MARK: Typography — legacy Font aliases
    var displayFont: Font
    var headingFont: Font
    var bodyFont: Font
    var captionFont: Font

    // MARK: Typography — 10-step DS scale
    var title1Font: Font
    var title2Font: Font
    var title3Font: Font
    var headlineFont: Font
    var calloutFont: Font
    var subheadFont: Font
    var footnoteFont: Font

    // MARK: Spacing — legacy shortcuts
    var spacingSm: CGFloat
    var spacingMd: CGFloat
    var spacingLg: CGFloat
    var spacingXl: CGFloat
    var cornerRadius: CGFloat
    var cornerRadiusSm: CGFloat
    var cornerRadiusLg: CGFloat

    // MARK: DS scales — nested grouped tokens
    var spacing: Spacing
    var radius: Radius
    var elevation: Elevation
    var motion: Motion

    struct Spacing {
        var s1: CGFloat
        var s2: CGFloat
        var s3: CGFloat
        var s4: CGFloat
        var s5: CGFloat
        var s6: CGFloat
        var s8: CGFloat
        var s10: CGFloat
        var s12: CGFloat
        var s16: CGFloat
    }

    struct Radius {
        var xs: CGFloat
        var sm: CGFloat
        var md: CGFloat
        var lg: CGFloat
        var xl: CGFloat
        var pill: CGFloat
    }

    struct Shadow {
        var color: Color
        var radius: CGFloat
        var x: CGFloat
        var y: CGFloat
    }

    struct Elevation {
        var e1: Shadow
        var e2: Shadow
        var e3: Shadow
    }

    struct Motion {
        var easing: Animation
        var fast: Double
        var base: Double
        var slow: Double
    }
}

// MARK: - View + Elevation convenience

extension View {
    /// Apply a scaled shadow from AppTheme.Elevation.
    func appElevation(_ s: AppTheme.Shadow) -> some View {
        self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// MARK: - Light & Dark Themes

extension AppTheme {
    static let light = AppTheme(
        primary: Color(hex: "2F6B4F"),
        secondary: Color(hex: "7E9A80"),
        accent: Color(hex: "C97A2B"),
        background: Color(hex: "F7F4E9"),
        surface: Color(hex: "FDFBF2"),
        surfaceSecondary: Color(hex: "EDE8D6"),
        textPrimary: Color(hex: "1E2A20"),
        textSecondary: Color(hex: "54634F"),
        error: Color(hex: "B04B31"),
        success: Color(hex: "3E8E5B"),
        onPrimary: Color(hex: "FBFAF4"),
        surfaceElevated: Color(hex: "FFFEF8"),
        surfaceSunken: Color(hex: "EDE8D6"),
        textTertiary: Color(hex: "8A9083"),
        separator: Color(hex: "1E2A2026"),
        warning: Color(hex: "B5811F"),
        primaryGradient: LinearGradient(
            colors: [Color(hex: "2F6B4F"), Color(hex: "7E9A80")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "F7F4E9"), Color(hex: "FDFBF2")],
            startPoint: .top, endPoint: .bottom
        ),
        glassTint: Color(hex: "2F6B4F"),
        displayFont: .system(size: 34, weight: .bold),
        headingFont: .system(size: 22, weight: .semibold),
        bodyFont: .system(size: 17, weight: .regular),
        captionFont: .system(size: 12, weight: .regular),
        title1Font: .system(size: 28, weight: .bold),
        title2Font: .system(size: 22, weight: .semibold),
        title3Font: .system(size: 20, weight: .semibold),
        headlineFont: .system(size: 17, weight: .semibold),
        calloutFont: .system(size: 16, weight: .regular),
        subheadFont: .system(size: 15, weight: .regular),
        footnoteFont: .system(size: 13, weight: .regular),
        spacingSm: 8, spacingMd: 16, spacingLg: 24, spacingXl: 32,
        cornerRadius: 16, cornerRadiusSm: 8, cornerRadiusLg: 24,
        spacing: AppTheme.Spacing(s1: 4, s2: 8, s3: 12, s4: 16, s5: 20, s6: 24, s8: 32, s10: 40, s12: 48, s16: 64),
        radius: AppTheme.Radius(xs: 4, sm: 8, md: 12, lg: 16, xl: 20, pill: 9999),
        elevation: AppTheme.Elevation(
            e1: AppTheme.Shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1),
            e2: AppTheme.Shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 4),
            e3: AppTheme.Shadow(color: Color.black.opacity(0.14), radius: 32, x: 0, y: 12)
        ),
        motion: AppTheme.Motion(easing: .easeInOut(duration: 0.25), fast: 0.15, base: 0.25, slow: 0.4)
    )

    static let dark = AppTheme(
        primary: Color(hex: "8FC79C"),
        secondary: Color(hex: "5E7C63"),
        accent: Color(hex: "E8A33D"),
        background: Color(hex: "14170F"),
        surface: Color(hex: "1C2016"),
        surfaceSecondary: Color(hex: "242A1D"),
        textPrimary: Color(hex: "EDEDE0"),
        textSecondary: Color(hex: "B0B7A3"),
        error: Color(hex: "E08167"),
        success: Color(hex: "6FBE84"),
        onPrimary: Color(hex: "0E1B12"),
        surfaceElevated: Color(hex: "242A1D"),
        surfaceSunken: Color(hex: "0F120A"),
        textTertiary: Color(hex: "7E8676"),
        separator: Color(hex: "EDEDE026"),
        warning: Color(hex: "E0AC55"),
        primaryGradient: LinearGradient(
            colors: [Color(hex: "8FC79C"), Color(hex: "5E7C63")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "111111"), Color(hex: "1C2016")],
            startPoint: .top, endPoint: .bottom
        ),
        glassTint: Color(hex: "8FC79C"),
        displayFont: .system(size: 34, weight: .bold),
        headingFont: .system(size: 22, weight: .semibold),
        bodyFont: .system(size: 17, weight: .regular),
        captionFont: .system(size: 12, weight: .regular),
        title1Font: .system(size: 28, weight: .bold),
        title2Font: .system(size: 22, weight: .semibold),
        title3Font: .system(size: 20, weight: .semibold),
        headlineFont: .system(size: 17, weight: .semibold),
        calloutFont: .system(size: 16, weight: .regular),
        subheadFont: .system(size: 15, weight: .regular),
        footnoteFont: .system(size: 13, weight: .regular),
        spacingSm: 8, spacingMd: 16, spacingLg: 24, spacingXl: 32,
        cornerRadius: 16, cornerRadiusSm: 8, cornerRadiusLg: 24,
        spacing: AppTheme.Spacing(s1: 4, s2: 8, s3: 12, s4: 16, s5: 20, s6: 24, s8: 32, s10: 40, s12: 48, s16: 64),
        radius: AppTheme.Radius(xs: 4, sm: 8, md: 12, lg: 16, xl: 20, pill: 9999),
        elevation: AppTheme.Elevation(
            e1: AppTheme.Shadow(color: Color.black.opacity(0.30), radius: 2, x: 0, y: 1),
            e2: AppTheme.Shadow(color: Color.black.opacity(0.40), radius: 12, x: 0, y: 4),
            e3: AppTheme.Shadow(color: Color.black.opacity(0.55), radius: 32, x: 0, y: 12)
        ),
        motion: AppTheme.Motion(easing: .easeInOut(duration: 0.25), fast: 0.15, base: 0.25, slow: 0.4)
    )
}
