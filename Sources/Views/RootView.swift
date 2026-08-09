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
                    ProgressView()
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
