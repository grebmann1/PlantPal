import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @EnvironmentObject private var appState: AppState
    @StateObject private var garden = GardenStore()
    @StateObject private var catalog = SpeciesCatalogStore()
    @StateObject private var speciesCollections = SpeciesCollectionStore()
    @State private var showGuestImport = false
    @State private var isImportingGuestData = false
    @State private var guestImportError: String?
    @Environment(\.appTheme) private var theme

    @AppStorage("pp.wateringReminders") private var wateringReminders = true
    @AppStorage("pp.scanNudges") private var scanNudges = false
    @AppStorage("pp.reminderTime") private var reminderTimeRaw = 27000.0

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
            Tab("Discover", systemImage: "books.vertical.fill", value: AppTab.catalog) {
                NavigationStack(path: $coordinator.catalogPath) {
                    SpeciesCatalogView()
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
                            case .preparation(let captureId, let mode):
                                if let context = coordinator.capture(for: captureId) {
                                    ScanPhotoPreparationView(
                                        captureId: captureId,
                                        mode: mode,
                                        context: context
                                    )
                                } else {
                                    missingCaptureView
                                }
                            case .identification(let captureId):
                                if let context = coordinator.capture(for: captureId) {
                                    IdentificationResultView(captureId: captureId, context: context)
                                } else {
                                    missingCaptureView
                                }
                            case .health(let captureId):
                                if let context = coordinator.capture(for: captureId) {
                                    HealthAssessmentView(captureId: captureId, context: context)
                                } else {
                                    missingCaptureView
                                }
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
        .environmentObject(catalog)
        .environmentObject(speciesCollections)
        .safeAreaInset(edge: .top) {
            if let message = garden.errorMessage {
                errorBanner(message)
            }
        }
        .sheet(isPresented: Binding(
            get: { coordinator.scanSpeciesSheetId != nil },
            set: { if !$0 { coordinator.scanSpeciesSheetId = nil } }
        )) {
            if let speciesId = coordinator.scanSpeciesSheetId {
                NavigationStack {
                    SpeciesDetailView(speciesId: speciesId)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { coordinator.scanSpeciesSheetId = nil }
                            }
                        }
                }
                .environmentObject(garden)
                .environmentObject(catalog)
                .environmentObject(speciesCollections)
                .environmentObject(appState)
                .environmentObject(coordinator)
            }
        }
        .task(id: appState.effectiveUserId) {
            if let userId = appState.effectiveUserId {
                async let gardenLoad: Void = garden.loadAll(userId: userId, isGuest: appState.isGuest)
                async let collectionLoad: Void = speciesCollections.load(userId: userId, isGuest: appState.isGuest)
                _ = await (gardenLoad, collectionLoad)
                await rescheduleNotifications()
            }
        }
        .onChange(of: appState.pendingGuestImportUserId) { _, pending in
            showGuestImport = pending != nil
        }
        .task(id: appState.pendingGuestImportUserId) {
            showGuestImport = appState.pendingGuestImportUserId != nil
        }
        .sheet(isPresented: $showGuestImport) { guestImportSheet }
        .onChange(of: garden.plants) { _, _ in
            Task { await rescheduleNotifications() }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .plantDetail(let id):
            PlantDetailView(plantId: id)
        case .careGuide(let id):
            CareGuideView(plantId: id)
        case .speciesDetail(let id):
            SpeciesDetailView(speciesId: id)
        case .guideArticle(let id):
            if let guide = PlantGuide.guide(id: id) {
                GuideArticleView(guide: guide)
            } else {
                ContentUnavailableView(
                    "Guide unavailable",
                    systemImage: "book.closed",
                    description: Text("This field note could not be found.")
                )
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.onPrimary)
            Text(message)
                .font(theme.footnoteFont)
                .foregroundStyle(theme.onPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                garden.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.onPrimary)
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.error)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private var missingCaptureView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(theme.warning)
            Text("That photo didn’t make it through. Please capture again.")
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Back to Scan") {
                coordinator.scanPath = NavigationPath()
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private func rescheduleNotifications() async {
        await NotificationService.reschedule(
            wateringEnabled: wateringReminders,
            scanNudgesEnabled: scanNudges,
            reminderTimeSeconds: reminderTimeRaw,
            plants: garden.plants
        )
    }

    private var guestImportSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Bring over your guest garden?")
                    .font(theme.title2Font)
                    .foregroundStyle(theme.primary)
                Text("Your plants, scans, reminders, and care guides are still stored on this device. Move them into this account so they can sync across devices.")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textSecondary)
                if let guestImportError {
                    Text(guestImportError)
                        .font(theme.footnoteFont)
                        .foregroundStyle(theme.error)
                }
                Button {
                    Task { await importGuestGarden() }
                } label: {
                    if isImportingGuestData {
                        ProgressView().tint(theme.onPrimary)
                    } else {
                        Text("Move guest garden to my account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
                .disabled(isImportingGuestData)
                Button("Keep it on this device") {
                    appState.keepGuestDataOnDevice()
                    showGuestImport = false
                }
                .disabled(isImportingGuestData)
                Spacer()
            }
            .padding(20)
            .background(theme.background)
            .navigationTitle("Guest garden")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
    }

    private func importGuestGarden() async {
        guard let guestUserId = appState.pendingGuestImportUserId,
              let userId = appState.userId else { return }
        isImportingGuestData = true
        defer { isImportingGuestData = false }
        do {
            await garden.loadAll(userId: userId, isGuest: false)
            try await garden.importGuestData(from: guestUserId, to: userId)
            try await speciesCollections.importGuestActivities(from: guestUserId, to: userId)
            appState.completeGuestImport()
            await garden.loadAll(userId: userId)
            showGuestImport = false
        } catch {
            guestImportError = "Couldn't move your guest garden: \(error.localizedDescription)"
        }
    }
}
