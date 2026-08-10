import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appTheme) private var theme

    var body: some View {
        Group {
            if !appState.isReady {
                ZStack {
                    JournalPaperBackground(showMarginRail: false)
                        .ignoresSafeArea()
                    ScrollView {
                        PlantAnalysisLoadingView(
                            eyebrow: String(localized: "PLANTPAL"),
                            status: String(localized: "Preparing your garden…")
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 72)
                    }
                }
            } else if appState.isSignedIn {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isSignedIn)
    }
}
