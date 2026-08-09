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
        // Re-apply saved language so Bundle lookups match the in-app choice.
        AppLanguage.apply(AppLanguage.stored)
    }

    @AppStorage("pp.darkMode") private var darkModeOn = false
    @AppStorage(AppLanguage.Keys.appLanguage) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, appLanguage.locale)
                .id(appLanguageRaw)
                .preferredColorScheme(darkModeOn ? .dark : nil)
        }
    }
}
