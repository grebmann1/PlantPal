import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @EnvironmentObject private var appState: AppState
    @StateObject private var garden = GardenStore()
    @Environment(\.appTheme) private var theme

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            Tab("Garden", systemImage: "leaf.fill", value: AppTab.garden) {
                NavigationStack(path: $coordinator.gardenPath) {
                    MyGardenView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                        }
                }
            }
            Tab("Scan", systemImage: "camera.viewfinder", value: AppTab.scan) {
                NavigationStack(path: $coordinator.scanPath) {
                    ScanPlantView()
                        .navigationDestination(for: ScanRoute.self) { route in
                            switch route {
                            case .identification(let context):
                                IdentificationResultView(context: context)
                            case .health(let context):
                                HealthAssessmentView(context: context)
                            }
                        }
                }
            }
            Tab("Water", systemImage: "drop.fill", value: AppTab.reminders) {
                NavigationStack(path: $coordinator.remindersPath) {
                    RemindersView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                        }
                }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(theme.primary)
        .environmentObject(garden)
        .task(id: appState.effectiveUserId) {
            if let userId = appState.effectiveUserId {
                await garden.loadAll(userId: userId, isGuest: appState.isGuest)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .plantDetail(let id):
            PlantDetailView(plantId: id)
        case .careGuide(let id):
            CareGuideView(plantId: id)
        }
    }
}
