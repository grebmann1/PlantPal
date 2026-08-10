import Foundation
import SwiftUI

enum AppTab: Int, Hashable, CaseIterable {
    case garden, catalog, scan, reminders, settings
}

enum ScanMode: String, CaseIterable {
    case identify = "Identify"
    case health = "Health check"
    case log = "Log scan"

    var title: String {
        switch self {
        case .identify: String(localized: "Identify")
        case .health: String(localized: "Health check")
        case .log: String(localized: "Log scan")
        }
    }
}

struct ScanIntent: Equatable {
    var mode: ScanMode
    var plantId: UUID?
}

struct CaptureContext: Hashable {
    /// One or more photos of the same plant (first is used for AI identify / cover).
    var images: [Data]
    var plantId: UUID?

    /// Primary capture used for AI and the plant cover photo.
    var imageData: Data { images.first ?? Data() }

    init(imageData: Data, plantId: UUID? = nil) {
        self.images = [imageData]
        self.plantId = plantId
    }

    init(images: [Data], plantId: UUID? = nil) {
        self.images = images
        self.plantId = plantId
    }
}

enum AppRoute: Hashable {
    case plantDetail(UUID)
    case careGuide(UUID)
    case speciesDetail(Int)
}

/// Lightweight scan destinations — photo bytes live in ``Coordinator/scanCaptures``,
/// not in the navigation path (large `Data` in `NavigationPath` breaks identify on device).
enum ScanRoute: Hashable {
    case preparation(UUID, ScanMode)
    case identification(UUID)
    case health(UUID)
}

@MainActor
final class Coordinator: ObservableObject {
    @Published var selectedTab: AppTab = .garden
    @Published var gardenPath = NavigationPath()
    @Published var catalogPath = NavigationPath()
    @Published var remindersPath = NavigationPath()
    @Published var scanPath = NavigationPath()
    @Published var scanPresetIntent: ScanIntent?
    /// Species detail presented as a sheet over Scan (avoids leaving the ID flow).
    @Published var scanSpeciesSheetId: Int?

    /// Capture payloads keyed by scan route id (kept out of NavigationPath).
    private(set) var scanCaptures: [UUID: CaptureContext] = [:]

    func pushPreparation(_ context: CaptureContext, mode: ScanMode) {
        let id = UUID()
        scanCaptures[id] = context
        scanPath.append(ScanRoute.preparation(id, mode))
    }

    func startIdentification(for captureId: UUID, context: CaptureContext) {
        scanCaptures[captureId] = context
        scanPath.append(ScanRoute.identification(captureId))
    }

    func startHealthAssessment(for captureId: UUID, context: CaptureContext) {
        scanCaptures[captureId] = context
        scanPath.append(ScanRoute.health(captureId))
    }

    func capture(for routeId: UUID) -> CaptureContext? {
        scanCaptures[routeId]
    }

    func updateCapture(for routeId: UUID, _ context: CaptureContext) {
        scanCaptures[routeId] = context
    }

    func clearCapture(for routeId: UUID) {
        scanCaptures[routeId] = nil
    }

    func goToPlantDetail(_ id: UUID, from tab: AppTab? = nil) {
        let target = tab ?? .garden
        selectedTab = target
        if target == .garden {
            scanPath = NavigationPath()
            scanCaptures.removeAll()
            gardenPath = NavigationPath()
            gardenPath.append(AppRoute.plantDetail(id))
        } else if target == .reminders {
            remindersPath = NavigationPath()
            remindersPath.append(AppRoute.plantDetail(id))
        } else if target == .catalog {
            catalogPath = NavigationPath()
            catalogPath.append(AppRoute.plantDetail(id))
        }
    }

    func clearPlantDetailStack(for tab: AppTab) {
        switch tab {
        case .garden: gardenPath = NavigationPath()
        case .reminders: remindersPath = NavigationPath()
        case .catalog: catalogPath = NavigationPath()
        case .scan, .settings: break
        }
    }

    func presentSpeciesFromScan(_ id: Int) {
        scanSpeciesSheetId = id
    }

    func goToSpeciesDetail(_ id: Int) {
        selectedTab = .catalog
        catalogPath.append(AppRoute.speciesDetail(id))
    }

    func goToScan(mode: ScanMode, plantId: UUID? = nil) {
        scanPresetIntent = ScanIntent(mode: mode, plantId: plantId)
        scanPath = NavigationPath()
        scanCaptures.removeAll()
        selectedTab = .scan
    }
}
