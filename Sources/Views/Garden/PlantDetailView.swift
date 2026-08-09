import SwiftUI

struct PlantDetailView: View {
    let plantId: UUID
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @State private var scans: [PlantScan] = []
    @State private var showOptions = false

    private var plant: Plant? { garden.plants.first(where: { $0.id == plantId }) }

    var body: some View {
        ScrollView {
            if let plant {
                VStack(alignment: .leading, spacing: 20) {
                    header(plant)
                    scanHistory
                    healthCard(plant)
                    wateringCard(plant)

                    Button {
                        coordinator.selectedTab = .garden
                        coordinator.gardenPath.append(AppRoute.careGuide(plant.id))
                    } label: {
                        Text("Open full care guide")
                            .font(theme.headlineFont)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.primary)

                    Button {
                        coordinator.goToScan(mode: .log, plantId: plant.id)
                    } label: {
                        Text("Log new scan")
                            .font(theme.headlineFont)
                            .foregroundStyle(theme.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary)
                    .clipShape(Capsule())
                }
                .padding(20)
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .background(theme.background)
        .navigationTitle(plant?.nickname ?? "Plant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showOptions = true } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .confirmationDialog("Plant options", isPresented: $showOptions, titleVisibility: .visible) {
            Button("Delete plant", role: .destructive) {
                Task {
                    await garden.deletePlant(id: plantId)
                    coordinator.gardenPath = NavigationPath()
                }
            }
        }
        .task { await loadScans() }
    }

    private func header(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                TapeMountPhoto(cornerRadius: theme.radius.lg) {
                    RemotePhoto(path: plant.photoUrl)
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                }
                SpecimenLabel(text: "Specimen \(String(format: "%03d", abs(plant.id.hashValue) % 999))", tint: .white)
                    .padding(10)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text(plant.nickname).font(theme.title2Font).foregroundStyle(theme.textPrimary)
                    Text(plant.speciesLatinName ?? "").italic().font(theme.subheadFont).foregroundStyle(theme.textSecondary)
                }
                Spacer()
                VStack(spacing: 3) {
                    Text("\(plant.healthScore ?? 0)").font(theme.title2Font).foregroundStyle(theme.primary)
                    Text("VIGOUR").font(.system(size: 9, weight: .bold)).foregroundStyle(theme.textTertiary)
                    PipsRow(filled: max(1, (plant.healthScore ?? 0) / 20), total: 5, color: theme.primary, size: 5)
                }
            }
            Text("Added \(plant.addedDate)").font(theme.footnoteFont).foregroundStyle(theme.textTertiary)
        }
    }

    private var scanHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scan history").font(theme.headlineFont).foregroundStyle(theme.textPrimary)
            if scans.isEmpty {
                Text("No scans logged yet.").font(theme.footnoteFont).foregroundStyle(theme.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(scans) { scan in
                            VStack(spacing: 4) {
                                TapeMountPhoto(cornerRadius: theme.radius.sm) {
                                    RemotePhoto(path: scan.photoUrl)
                                        .frame(width: 84, height: 84)
                                }
                                Text(shortDate(scan.capturedAt)).font(.system(size: 10)).foregroundStyle(theme.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func healthCard(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Health status").font(theme.headlineFont).foregroundStyle(theme.textPrimary)
            HStack {
                Circle().fill(dotColor(plant)).frame(width: 10, height: 10)
                Text(plant.healthStatus.shortLabel).font(theme.subheadFont).foregroundStyle(theme.textSecondary)
                Spacer()
                Text("\(plant.healthScore ?? 0)/100").font(theme.subheadFont.weight(.semibold)).foregroundStyle(theme.textPrimary)
            }
        }
        .padding(14)
        .background(theme.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
    }

    private func wateringCard(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Watering schedule").font(theme.headlineFont).foregroundStyle(theme.textPrimary)
            HStack {
                Text("Next: \(plant.nextWateringDate ?? "\u{2014}")").font(theme.subheadFont).foregroundStyle(theme.textSecondary)
                Spacer()
                if let interval = plant.wateringIntervalDays {
                    Text("Every \(interval)d \u{00B7} \(plant.wateringAmountMl ?? 0) ml").font(theme.footnoteFont).foregroundStyle(theme.textTertiary)
                }
            }
        }
        .padding(14)
        .background(theme.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
    }

    private func dotColor(_ plant: Plant) -> Color {
        switch plant.healthStatus {
        case .healthy: return theme.success
        case .needsAttention: return theme.warning
        case .atRisk: return theme.error
        }
    }

    private func shortDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func loadScans() async {
        scans = (try? await garden.fetchScans(plantId: plantId)) ?? []
    }
}
