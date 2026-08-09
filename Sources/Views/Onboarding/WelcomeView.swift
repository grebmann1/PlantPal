import SwiftUI
import Spark

struct WelcomeView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator
    @State private var showAuth = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1463936578469-0c2c4c6f5c0c?w=1200&q=80")) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                LinearGradient(
                                    colors: [theme.primary, theme.secondary],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height * 0.53)
                        .clipped()

                        LinearGradient(
                            colors: [.black.opacity(0.55), .black.opacity(0.15), .black.opacity(0.45)],
                            startPoint: .top, endPoint: .bottom
                        )

                        HStack(spacing: 8) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("PLANTPAL")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(2.0)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, max(16, proxy.safeAreaInsets.top + 8))
                        .padding(.leading, 20)

                        VStack(alignment: .leading, spacing: 6) {
                            SpecimenLabel(text: "Field Journal \u{00B7} Est. 2024", tint: .white.opacity(0.9))
                            Text("Every plant,\nkept thriving.")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                        }
                        .padding(20)
                        .padding(.bottom, 16)
                    }
                    .frame(height: proxy.size.height * 0.53)
                    .clipped()

                    TornEdge(fill: theme.background)
                        .offset(y: -7)
                        .zIndex(1)

                    ScrollView {
                        ZStack(alignment: .bottomTrailing) {
                            LeafWatermark(opacity: 0.07, rotation: 12, color: theme.primary)
                                .frame(width: 160, height: 200)
                                .offset(x: 40, y: 30)

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
                            showAuth = true
                        } label: {
                            Text("Sign in to sync")
                                .font(theme.headlineFont)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .tint(theme.primary)
                        .clipShape(Capsule())

                        Text("Guest mode keeps plants on this device only — sign in to sync across devices.")
                            .font(theme.footnoteFont)
                            .foregroundStyle(theme.textTertiary)
                            .multilineTextAlignment(.center)

                        Button {
                            continueAsGuest(on: .garden)
                        } label: {
                            Text("Continue as guest")
                                .font(.subheadline.weight(.medium))
                                .underline()
                                .foregroundStyle(theme.textSecondary)
                        }
                        .accessibilityHint("Continues as a guest without creating an account")
                    }
                    .padding(20)
                    .padding(.bottom, 8)
                    .background(theme.background)
                }
            }
            .ignoresSafeArea(edges: .top)
            .sheet(isPresented: $showAuth) {
                NavigationStack {
                    AuthView(postSignInTab: .garden)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showAuth = false }
                            }
                        }
                }
                .environmentObject(appState)
                .environmentObject(coordinator)
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
            HStack {
                Text(number)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(tint)
                Spacer()
                Circle()
                    .stroke(tint.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 8, height: 8)
            }
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
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 2,
                bottomLeadingRadius: 2,
                bottomTrailingRadius: 10,
                topTrailingRadius: 10
            )
        )
        .appElevation(theme.elevation.e1)
    }
}

#Preview {
    ThemeProvider { WelcomeView() }
        .environmentObject(AppState())
        .environmentObject(Coordinator())
}
