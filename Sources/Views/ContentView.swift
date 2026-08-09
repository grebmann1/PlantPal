import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var coordinator = Coordinator()

    var body: some View {
        ThemeProvider {
            RootView()
                .environmentObject(appState)
                .environmentObject(coordinator)
        }
    }
}

#Preview {
    ContentView()
}
