import SwiftUI

struct MyGardenView: View {
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @State private var query = ""
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable {
        case all = "All"
        case thirsty = "Thirsty"
        case attention = "Attention"
        case indoor = "Indoor"
        case balcony = "Balcony"
    }

    private var filteredPlants: [Plant] {
        var list = garden.plants
        switch filter {
        case .all: break
        case .thirsty:
            list = list.filter { isThirsty($0) }
        case .attention:
            list = list.filter { $0.healthStatus != .healthy }
        case .indoor:
            list = list.filter { $0.placement == .indoor }
        case .balcony:
            list = list.filter { $0.placement == .balcony }
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
            ZStack(alignment: .bottomTrailing) {
                LeafWatermark(opacity: 0.07, rotation: 18, color: theme.primary)
                    .frame(width: 200, height: 260)
                    .offset(x: 40, y: 20)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 18) {
                    header
                    searchAndFilters

                if garden.isLoading && garden.plants.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if filteredPlants.isEmpty {
                    if garden.plants.isEmpty {
                        emptyState
                    } else {
                        filteredEmptyState
                    }
                } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(filteredPlants.enumerated()), id: \.element.id) { index, plant in
                                Button {
                                    coordinator.goToPlantDetail(plant.id)
                                } label: {
                                    PlantTileView(plant: plant, tall: index.isMultiple(of: 2))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("plant-detail-\(plant.nickname)")
                                .padding(.top, index.isMultiple(of: 2) ? 0 : 26)
                            }
                        }
                    }

                    if !attentionPlants.isEmpty {
                        attentionLedger
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
        }
        .journalPaperBackground(showMarginRail: true)
        .accessibilityIdentifier("garden-screen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { EmptyView() }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .overlay(alignment: .bottomTrailing) {
            Button {
                coordinator.goToScan(mode: .identify)
            } label: {
                Image(systemName: "camera.viewfinder")
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
        VStack(alignment: .leading, spacing: 6) {
            Text("FIELD JOURNAL \u{2014} LIVING SPECIMENS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.secondary)
            Text("My Garden")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(theme.primary)
            HStack(spacing: 8) {
                Text("\(garden.plants.count) plants tracked")
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.textSecondary)
                if !attentionPlants.isEmpty {
                    Text("\u{00B7}")
                        .foregroundStyle(theme.textTertiary)
                    Text("\(attentionPlants.count) need attention")
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
                        Button { filter = f } label: {
                            Text(chipLabel(f).uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.8)
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
        case .thirsty: return "Thirsty \(garden.plants.filter(isThirsty).count)"
        case .attention: return "Attention \(attentionPlants.count)"
        case .indoor: return "Indoor"
        case .balcony: return "Balcony"
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

    private var filteredEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(theme.textTertiary)
            Text("Nothing in this filter")
                .font(theme.headlineFont)
                .foregroundStyle(theme.textPrimary)
            Text(filteredEmptyCopy)
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                filter = .all
            } label: {
                Text("Show all plants")
                    .font(theme.subheadFont.weight(.semibold))
                    .foregroundStyle(theme.primary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var filteredEmptyCopy: String {
        switch filter {
        case .all: return "No plants match your search."
        case .thirsty: return "No plants are due for water right now."
        case .attention: return "Every specimen looks healthy."
        case .indoor: return "No indoor plants in this collection yet."
        case .balcony: return "No balcony plants in this collection yet."
        }
    }

    private var attentionLedger: some View {
        VStack(alignment: .leading, spacing: 0) {
            TornEdge(fill: theme.primary.opacity(0.10))
                .frame(height: 12)

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
                        Button {
                            coordinator.goToPlantDetail(plant.id)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(plant.healthStatus == .atRisk ? theme.error : theme.warning)
                                    .frame(width: 9, height: 9)
                                Text(plant.nickname).font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                                Spacer()
                                Text(plant.healthStatus.shortLabel.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(theme.error)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(theme.separator).frame(height: 1)
                    }
                }

                Button {
                    coordinator.selectedTab = .reminders
                } label: {
                    Text("Open watering ledger")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(theme.primary)
                        .overlay(
                            Capsule().stroke(theme.primary.opacity(0.45), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(16)
            .background(theme.primary.opacity(0.10))
        }
        .padding(.top, 12)
    }

    private func isThirsty(_ plant: Plant) -> Bool {
        guard let dateString = plant.nextWateringDate,
              let date = GardenStore.dateFormatter.date(from: dateString) else { return false }
        return date <= Date()
    }
}

private struct PlantTileView: View {
    let plant: Plant
    var tall: Bool = true
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TapeMountPhoto(cornerRadius: 2) {
                Color.clear
                    .aspectRatio(tall ? 3.0 / 4.0 : 1.0, contentMode: .fit)
                    .overlay {
                        RemotePhoto(path: plant.photoUrl)
                    }
                    .clipped()
            }

            Text(plant.nickname)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Text(plant.speciesLatinName ?? "")
                .font(.system(size: 11))
                .italic()
                .foregroundStyle(theme.textSecondary)

            Rectangle().fill(theme.separator).frame(height: 1).padding(.top, 2)

            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(waterLabel)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(isOverdue ? theme.error : theme.textPrimary)
            }
            .padding(.top, 2)
        }
        .padding(8)
        .background(theme.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .appElevation(theme.elevation.e1)
    }

    private var isOverdue: Bool {
        guard let dateString = plant.nextWateringDate,
              let date = GardenStore.dateFormatter.date(from: dateString) else { return false }
        return date < Calendar.current.startOfDay(for: Date())
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
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        if days < 0 { return "Overdue \(-days)d" }
        if days == 0 { return "Water today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "Water \(formatter.string(from: date))"
    }
}
