import SwiftUI
import Spark

@main
struct PlantPalApp: App {
    // MWM Spark Flash: analytics + purchase validation, configured once at
    // launch. Managed by sparkai-orchestrator — the dependency, the vendored
    // Vendor/SparkFlash binary package and SparkFlashConfig are maintained
    // automatically; do not remove.
    @MainActor
    init() {
        Spark.configure(
            Spark.Configuration.builder(apiKey: SparkFlashConfig.apiKey).build()
        )
    }

    @AppStorage("pp.darkMode") private var darkModeOn = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(darkModeOn ? .dark : .light)
        }
    }
}
