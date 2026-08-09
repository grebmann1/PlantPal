import SwiftUI

struct MyGardenView: View {
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @State private var query = ""
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable { case all = "All", thirsty = "Thirsty", attention = "Attention" }

    private var filteredPlants: [Plant] {
        var list = garden.plants
        switch filter {
        case .all: break
        case .thirsty:
            list = list.filter { plant in
                guard let dateString = plant.nextWateringDate,
                      let date = GardenStore.dateFormatter.date(from: dateString) else { return false }
                return date <= Date()
            }
        case .attention:
            list = list.filter { $0.healthStatus != .healthy }
        }
        if !query.isEmpty {
            list = list.filter {
                $0.nickname.localizedCaseInsensitiveContains(query) ||
                ($0.speciesCommonName ?? "").localizedCaseInsensitiveContains(query) ||
                ($0.speciesLatinName ?? "").localizedCaseInsensitiveContains(query)
            }
        }
        return list
    }

    private var attentionPlants: [Plant] {
        garden.plants.filter { $0.healthStatus != .healthy }
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchAndFilters

                if garden.isLoading && garden.plants.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if filteredPlants.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredPlants) { plant in
                            Button {
                                coordinator.goToPlantDetail(plant.id)
                            } label: {
                                PlantTileView(plant: plant)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !attentionPlants.isEmpty {
                    attentionLedger
                }
            }
            .padding(20)
            .padding(.bottom, 90)
        }
        .background(theme.background)
        .navigationTitle("My Garden")
        .overlay(alignment: .bottomTrailing) {
            Button {
                coordinator.goToScan(mode: .identify)
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.onPrimary)
                    .frame(width: 60, height: 60)
                    .background(theme.primary)
                    .clipShape(Circle())
                    .appElevation(theme.elevation.e3)
            }
            .padding(.trailing, 18)
            .padding(.bottom, 18)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FIELD JOURNAL \u{2014} LIVING SPECIMENS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.textTertiary)
            HStack(spacing: 8) {
                Text("\(garden.plants.count) plants tracked")
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.textSecondary)
                if !attentionPlants.isEmpty {
                    Text("\u{00B7} \(attentionPlants.count) need attention")
                        .font(theme.footnoteFont.weight(.semibold))
                        .foregroundStyle(theme.error)
                }
            }
        }
    }

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.textSecondary)
                TextField("Search species or nickname", text: $query)
            }
            .padding(10)
            .background(theme.surfaceSunken)
            .clipShape(Capsule())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Filter.allCases, id: \.self) { f in
                        Button {
                            filter = f
                        } label: {
                            Text(chipLabel(f))
                                .font(.system(size: 12, weight: .bold))
                                .tracking(0.5)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(filter == f ? theme.primary : Color.clear)
                                .foregroundStyle(filter == f ? theme.onPrimary : theme.textSecondary)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(theme.primary.opacity(filter == f ? 0 : 0.35), lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    private func chipLabel(_ f: Filter) -> String {
        switch f {
        case .all: return "All \(garden.plants.count)"
        case .thirsty:
            let count = garden.plants.filter {
                guard let d = $0.nextWateringDate, let date = GardenStore.dateFormatter.date(from: d) else { return false }
                return date <= Date()
            }.count
            return "Thirsty \(count)"
        case .attention: return "Attention \(attentionPlants.count)"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            LeafWatermark(opacity: 0.6, rotation: 0, color: theme.textTertiary).frame(width: 32, height: 32)
            Text("No plants yet").font(theme.headlineFont).foregroundStyle(theme.textPrimary)
            Text("Scan your first plant to start your garden.")
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var attentionLedger: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LEDGER \u{00B7} NEEDS A LOOK")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.primary)
            Text("\(attentionPlants.count) entries flagged")
                .font(theme.headlineFont)
                .foregroundStyle(theme.textPrimary)
            VStack(spacing: 0) {
                ForEach(attentionPlants) { plant in
                    HStack {
                        Circle()
                            .fill(plant.healthStatus == .atRisk ? theme.error : theme.warning)
                            .frame(width: 9, height: 9)
                        Text(plant.nickname).font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text(plant.healthStatus.shortLabel.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.error)
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
            Button {
                coordinator.selectedTab = .reminders
            } label: {
                Text("Open watering ledger")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(theme.primary)
        }
        .padding(16)
        .background(theme.glassTint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
    }
}

private struct PlantTileView: View {
    let plant: Plant
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TapeMountPhoto(cornerRadius: theme.radius.sm) {
                RemotePhoto(path: plant.photoUrl)
                    .aspectRatio(3.0/4.0, contentMode: .fit)
            }

            Text(plant.nickname)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Text(plant.speciesLatinName ?? "")
                .font(.system(size: 11))
                .italic()
                .foregroundStyle(theme.textSecondary)
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(waterLabel)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.top, 2)
        }
        .padding(8)
        .background(theme.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
        .appElevation(theme.elevation.e1)
    }

    private var dotColor: Color {
        switch plant.healthStatus {
        case .healthy: return theme.success
        case .needsAttention: return theme.warning
        case .atRisk: return theme.error
        }
    }

    private var waterLabel: String {
        guard let dateString = plant.nextWateringDate, let date = GardenStore.dateFormatter.date(from: dateString) else {
            return "No schedule"
        }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days < 0 { return "Overdue \(-days)d" }
        if days == 0 { return "Water today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "Water \(formatter.string(from: date))"
    }
}
