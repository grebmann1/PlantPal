import SwiftUI
import Spark

struct WelcomeView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [theme.primary, theme.secondary],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        LeafWatermark(opacity: 0.14, rotation: -18, color: .white)
                            .frame(width: proxy.size.width * 0.9)
                            .offset(x: proxy.size.width * 0.25, y: -30)

                        LinearGradient(
                            colors: [.black.opacity(0.42), .clear, .black.opacity(0.32)],
                            startPoint: .top, endPoint: .bottom
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            SpecimenLabel(text: "Field Journal \u{00B7} Est. 2024", tint: .white.opacity(0.9))
                            Text("Every plant,\nkept thriving.")
                                .font(.system(size: 31, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(20)
                        .padding(.bottom, 12)

                        VStack(spacing: 1) {
                            Text("14k")
                                .font(.system(size: 19, weight: .bold))
                            Text("SPECIES")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1.2)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 70)
                        .background(Circle().stroke(.white, lineWidth: 2))
                        .rotationEffect(.degrees(-8))
                        .position(x: proxy.size.width - 56, y: proxy.size.height * 0.53 - 46)
                    }
                    .frame(height: proxy.size.height * 0.5)
                    .clipped()

                    TornEdge(fill: theme.background)
                        .offset(y: -7)
                        .zIndex(1)

                    ScrollView {
                        HStack(alignment: .top, spacing: 12) {
                            PageDotRail(count: 3, color: theme.primary)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 12) {
                                introStep(number: "STEP ONE \u{00B7} IDENTIFY", title: "Snap a leaf, name the plant", subtitle: "Point your camera at any plant and get its species in seconds.", tint: theme.primary)
                                introStep(number: "STEP TWO \u{00B7} DIAGNOSE", title: "Check its health", subtitle: "Spot yellowing, pests and overwatering before they spread.", tint: theme.secondary)
                                introStep(number: "STEP THREE \u{00B7} TEND", title: "Keep a watering ledger", subtitle: "Reminders tuned to each plant, logged like a real journal.", tint: theme.accent)
                            }
                        }
                        .padding(20)
                        .padding(.top, -8)
                    }
                    .background(theme.background)

                    VStack(spacing: 12) {
                        HStack {
                            Text("BEGIN YOUR COLLECTION")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(theme.textTertiary)
                            Spacer()
                            Text("No. 001")
                                .font(.footnote)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Button {
                            continueAsGuest(on: .scan)
                        } label: {
                            Text("Scan my first plant")
                                .font(theme.headlineFont)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.primary)
                        .foregroundStyle(theme.onPrimary)
                        .clipShape(Capsule())

                        Button {
                            continueAsGuest(on: .garden)
                        } label: {
                            Text("Skip for now")
                                .font(.subheadline.weight(.medium))
                                .underline()
                                .foregroundStyle(theme.textSecondary)
                        }
                        .accessibilityHint("Continues as a guest with demo plants")
                    }
                    .padding(20)
                    .padding(.bottom, 8)
                    .background(theme.background)
                }
            }
        }
    }

    private func continueAsGuest(on tab: AppTab) {
        coordinator.selectedTab = tab
        appState.continueAsGuest()
        Spark.shared.analytics.logEvent(
            type: "onboarding_completed",
            properties: ["access_mode": "guest", "destination": tab == .scan ? "scan" : "garden"]
        )
    }

    private func introStep(number: String, title: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .overlay(Rectangle().fill(tint).frame(width: 3), alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .appElevation(theme.elevation.e1)
    }
}

#Preview {
    ThemeProvider { WelcomeView() }
        .environmentObject(AppState())
        .environmentObject(Coordinator())
}
