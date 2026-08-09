import Foundation
import SwiftUI

enum AppTab: Int, Hashable, CaseIterable {
    case garden, scan, reminders, settings
}

enum ScanMode: String, CaseIterable {
    case identify = "Identify"
    case health = "Health check"
    case log = "Log scan"
}

struct ScanIntent: Equatable {
    var mode: ScanMode
    var plantId: UUID?
}

struct CaptureContext: Hashable {
    var imageData: Data
    var plantId: UUID?
}

enum AppRoute: Hashable {
    case plantDetail(UUID)
    case careGuide(UUID)
}

enum ScanRoute: Hashable {
    case identification(CaptureContext)
    case health(CaptureContext)
}

@MainActor
final class Coordinator: ObservableObject {
    @Published var selectedTab: AppTab = .garden
    @Published var gardenPath = NavigationPath()
    @Published var remindersPath = NavigationPath()
    @Published var scanPath = NavigationPath()
    @Published var scanPresetIntent: ScanIntent?

    func goToPlantDetail(_ id: UUID, from tab: AppTab? = nil) {
        let target = tab ?? .garden
        selectedTab = target
        if target == .garden {
            gardenPath = NavigationPath()
            gardenPath.append(AppRoute.plantDetail(id))
        } else if target == .reminders {
            remindersPath = NavigationPath()
            remindersPath.append(AppRoute.plantDetail(id))
        }
    }

    func goToScan(mode: ScanMode, plantId: UUID? = nil) {
        scanPresetIntent = ScanIntent(mode: mode, plantId: plantId)
        scanPath = NavigationPath()
        selectedTab = .scan
    }
}
