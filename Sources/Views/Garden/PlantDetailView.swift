import SwiftUI
import UIKit

struct PlantDetailView: View {
    let plantId: UUID
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var scans: [PlantScan] = []
    @State private var careGuide: CareGuide?
    @State private var showOptions = false
    @State private var showEdit = false
    @State private var isWatering = false
    @State private var showAddPhotoSource = false
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var isSavingPhoto = false
    @State private var photoError: String?
    @State private var showPlantExpert = false

    private var plant: Plant? { garden.plants.first(where: { $0.id == plantId }) }

    private var healthScores: [Int] {
        scans.compactMap(\.healthScore)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                if let plant {
                    VStack(alignment: .leading, spacing: 0) {
                        titleblock(plant)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 14)

                        scanRail

                        VStack(alignment: .leading, spacing: 0) {
                            Rectangle().fill(theme.separator).frame(height: 1)
                                .padding(.top, 6)

                            wateringLedger(plant)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)

                            Rectangle().fill(theme.separator).frame(height: 1)

                            if healthScores.count >= 2 {
                                healthTimeline
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                            } else {
                                healthCard(plant)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                            }

                            Rectangle().fill(theme.separator).frame(height: 1)

                            careblock(plant)

                            facts(plant)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .padding(.bottom, 20)

                            Button {
                                Task { await waterNow(plant) }
                            } label: {
                                HStack(spacing: 8) {
                                    if isWatering { ProgressView() }
                                    Text(isWatering ? "Logging water…" : "Water now")
                                        .font(theme.subheadFont)
                                        .underline()
                                }
                                .foregroundStyle(theme.primary)
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(isWatering)
                            .padding(.bottom, 12)
                        }
                    }
                    .padding(.bottom, 8)
                } else {
                    ProgressView().padding(.top, 60)
                }
            }

            footdock
        }
        .background(theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text(backLabel)
                        .font(theme.subheadFont.weight(.medium))
                        .foregroundStyle(theme.primary)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Plant Detail")
                    .font(theme.subheadFont.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showOptions = true } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(theme.primary)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("Plant options", isPresented: $showOptions, titleVisibility: .visible) {
            Button("Edit plant") { showEdit = true }
            Button("Delete plant", role: .destructive) {
                Task {
                    await garden.deletePlant(id: plantId)
                    coordinator.clearPlantDetailStack(for: coordinator.selectedTab)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Add a private photo", isPresented: $showAddPhotoSource, titleVisibility: .visible) {
            Button("Take photo") { showCameraPicker = true }
            Button("Choose from library") { showLibraryPicker = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only you can see photos added to this plant.")
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera) { image in
                Task { await savePrivatePhoto(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibraryPicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                Task { await savePrivatePhoto(image) }
            }
        }
        .alert("Couldn't add photo", isPresented: Binding(
            get: { photoError != nil },
            set: { if !$0 { photoError = nil } }
        )) {
            Button("OK", role: .cancel) { photoError = nil }
        } message: {
            Text(photoError ?? "")
        }
        .sheet(isPresented: $showEdit) {
            if let plant {
                EditPlantSheet(plant: plant) { nickname, interval, amount, placement in
                    Task {
                        await garden.updatePlant(
                            id: plant.id,
                            nickname: nickname,
                            wateringIntervalDays: interval,
                            wateringAmountMl: amount,
                            placement: placement
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showPlantExpert) {
            if let plant {
                PlantExpertChatView(plant: plant, careGuide: careGuide)
            }
        }
        .task {
            await loadScans()
            await loadCareGuide()
        }
    }

    private func titleblock(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SPECIMEN NO. \(String(format: "%02d", abs(plant.id.hashValue) % 99)) · \(plant.placement.label)")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(theme.textTertiary)

            Text(plant.speciesCommonName ?? plant.nickname)
                .font(theme.title1Font)
                .foregroundStyle(theme.primary)

            if let latin = plant.speciesLatinName, !latin.isEmpty {
                Text(latin)
                    .italic()
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textSecondary)
            }

            HStack(spacing: 10) {
                Circle().fill(dotColor(plant)).frame(width: 8, height: 8)
                Text("\(plant.healthStatus.shortLabel) · \(plant.healthScore ?? 0) vigour")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textPrimary)
                PipsRow(filled: max(1, (plant.healthScore ?? 0) / 20), total: 5, color: theme.primary, size: 8)
            }
        }
    }

    private var scanRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("YOUR PHOTOS · \(scans.count)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.primary)
                Spacer()
                Text("Private to you")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 10) {
                    addPhotoTile

                    if scans.isEmpty {
                        Text("Add snapshots of this plant — only you can see them.")
                            .font(theme.footnoteFont)
                            .foregroundStyle(theme.textTertiary)
                            .frame(width: 160, alignment: .leading)
                            .padding(.bottom, 28)
                    } else {
                        ForEach(Array(scans.enumerated()), id: \.element.id) { index, scan in
                            let isLatest = index == 0
                            VStack(spacing: 6) {
                                TapeMountPhoto(cornerRadius: theme.radius.sm) {
                                    RemotePhoto(path: scan.photoUrl)
                                        .frame(width: isLatest ? 132 : 72, height: isLatest ? 176 : 96)
                                        .clipped()
                                }
                                VStack(spacing: 2) {
                                    Text(shortDate(scan.capturedAt))
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(theme.textTertiary)
                                    HStack(spacing: 4) {
                                        Text(scanTypeLabel(scan.scanType))
                                            .font(.system(size: 9, weight: .bold))
                                            .tracking(0.6)
                                            .foregroundStyle(theme.primary.opacity(0.85))
                                        if isLatest {
                                            Text("· LATEST")
                                                .font(.system(size: 9, weight: .bold))
                                                .tracking(0.6)
                                                .foregroundStyle(theme.textTertiary)
                                        }
                                        if let score = scan.healthScore {
                                            Text("· \(score)")
                                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(theme.textTertiary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 28)
                .padding(.vertical, 8)
            }
        }
    }

    private var addPhotoTile: some View {
        Button {
            showAddPhotoSource = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.radius.sm)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(theme.primary.opacity(0.45))
                        .frame(width: 72, height: 96)
                        .background(theme.surfaceSunken.opacity(0.5))
                    if isSavingPhoto {
                        ProgressView()
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                            Text("ADD")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.0)
                        }
                        .foregroundStyle(theme.primary)
                    }
                }
                Text("Photo")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSavingPhoto)
        .accessibilityLabel("Add a private photo")
    }

    private func wateringLedger(_ plant: Plant) -> some View {
        let interval = max(plant.wateringIntervalDays ?? 7, 1)
        let progress = wateringProgress(plant: plant, interval: interval)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WATERING LEDGER")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(theme.primary)
                    Text("Every \(interval) days · \(UnitsFormatting.waterAmount(ml: plant.wateringAmountMl ?? 0))")
                        .font(theme.subheadFont.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("NEXT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(theme.textTertiary)
                    Text(displayNextDate(plant.nextWateringDate))
                        .font(theme.headlineFont)
                        .foregroundStyle(theme.textPrimary)
                }
            }

            SegmentedProgressBar(
                filled: progress.filled,
                total: interval,
                fillColor: theme.primary,
                accentIndex: progress.accentIndex,
                accentColor: theme.warning,
                emptyColor: theme.separator.opacity(0.5)
            )

            HStack {
                Text(progress.caption)
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text("\(progress.filled) / \(interval) d")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    private var healthTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HEALTH TIMELINE · \(healthScores.count) SCANS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(theme.primary)

            HealthTimelineChart(
                scores: healthScores,
                lineColor: theme.primary,
                dipColor: theme.warning
            )
            .padding(.vertical, 4)
        }
    }

    private func healthCard(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HEALTH STATUS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(theme.primary)
            HStack {
                Circle().fill(dotColor(plant)).frame(width: 10, height: 10)
                Text(plant.healthStatus.shortLabel).font(theme.subheadFont).foregroundStyle(theme.textSecondary)
                Spacer()
                Text("\(plant.healthScore ?? 0)/100").font(theme.subheadFont.weight(.semibold)).foregroundStyle(theme.textPrimary)
            }
        }
    }

    private func careblock(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CARE SUMMARY")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(theme.primary)

            Text(careBlurb(for: plant))
                .font(.system(size: 16))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(4)

            Button {
                coordinator.selectedTab = .garden
                coordinator.gardenPath.append(AppRoute.careGuide(plant.id))
            } label: {
                Text("Open full care guide")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.primary)
            }
            .padding(.top, 4)

            Button {
                showPlantExpert = true
            } label: {
                Text("Ask the Plant Expert")
                    .font(theme.subheadFont.weight(.semibold))
                    .foregroundStyle(theme.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
            }
            .padding(.top, 10)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.secondary.opacity(0.15))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(theme.primary)
                .frame(width: 3)
        }
    }

    private func facts(_ plant: Plant) -> some View {
        VStack(spacing: 0) {
            factRow(label: "Light", value: careGuide?.lightRequirement ?? "—")
            factRow(label: "Soil", value: shortSoil(careGuide?.soilMix) ?? "—")
            factRow(label: "Humidity", value: careGuide?.humidityRange ?? "—")
            factRow(label: "Added to garden", value: plant.addedDate)
        }
    }

    private func factRow(label: String, value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(theme.textTertiary)
            Spacer()
            Text(value)
                .font(theme.subheadFont.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator.opacity(0.7)).frame(height: 1)
        }
    }

    private var footdock: some View {
        VStack(spacing: 0) {
            Rectangle().fill(theme.separator).frame(height: 1)
            Button {
                if let plant {
                    coordinator.goToScan(mode: .health, plantId: plant.id)
                }
            } label: {
                Text("Run health check")
                    .font(theme.headlineFont)
                    .foregroundStyle(theme.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }

    private func careBlurb(for plant: Plant) -> String {
        if let guide = careGuide {
            var parts: [String] = []
            if let light = guide.lightRequirement { parts.append("\(light) light") }
            if let water = guide.wateringFrequency {
                parts.append("Water \(water.lowercased())")
            }
            if let amount = guide.wateringAmount {
                parts.append("aim for \(amount)")
            }
            if let humidity = guide.humidityRange {
                parts.append("Keep humidity around \(humidity)")
            }
            if !parts.isEmpty {
                return parts.joined(separator: ". ") + "."
            }
        }
        let interval = plant.wateringIntervalDays ?? 7
        let amount = plant.wateringAmountMl ?? 250
        return "Bright indirect light preferred. Water every \(interval) days with about \(UnitsFormatting.waterAmount(ml: amount)), letting the top soil dry between drinks. Open the full care guide for species-specific notes."
    }

    private var backLabel: String {
        switch coordinator.selectedTab {
        case .garden: return "‹ Garden"
        case .reminders: return "‹ Water"
        case .catalog: return "‹ Discover"
        case .scan, .settings: return "‹ Back"
        }
    }

    private func shortSoil(_ mix: String?) -> String? {
        guard let mix, !mix.isEmpty else { return nil }
        let first = mix.split(separator: ".").first.map(String.init) ?? mix
        return first.count > 36 ? String(first.prefix(34)) + "…" : first
    }

    private func waterNow(_ plant: Plant) async {
        guard let userId = appState.effectiveUserId else { return }
        isWatering = true
        defer { isWatering = false }

        if let pending = garden.reminders.first(where: {
            $0.plantId == plant.id && !$0.isCompleted && $0.type == "watering"
        }) {
            await garden.markWatered(pending)
            return
        }

        let amountLabel = plant.wateringAmountMl.map { UnitsFormatting.waterAmount(ml: $0) }
        let due = ISO8601DateFormatter().string(from: Date())
        let reminder = NewReminder(
            userId: userId,
            plantId: plant.id,
            type: "watering",
            dueAt: due,
            amountLabel: amountLabel
        )
        do {
            let created = try await garden.addReminder(reminder)
            await garden.markWatered(created)
        } catch {
            garden.errorMessage = String(localized: "Couldn't log watering: \(error.localizedDescription)")
        }
    }

    private func wateringProgress(plant: Plant, interval: Int) -> (filled: Int, accentIndex: Int?, caption: String) {
        let next = parseDate(plant.nextWateringDate)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let next {
            let nextDay = calendar.startOfDay(for: next)
            let daysUntil = calendar.dateComponents([.day], from: today, to: nextDay).day ?? 0
            let elapsed = max(0, min(interval, interval - daysUntil))
            let lastDate = calendar.date(byAdding: .day, value: -elapsed, to: nextDay)
            let lastLabel = lastDate.map { formatDay($0) } ?? "—"
            let ago = elapsed == 0 ? "today" : "\(elapsed) day\(elapsed == 1 ? "" : "s") ago"
            let accent = elapsed >= interval - 1 ? interval - 1 : nil
            return (elapsed, accent, "Last watered \(lastLabel) · \(ago)")
        }

        return (0, nil, "No watering date set yet")
    }

    private func displayNextDate(_ raw: String?) -> String {
        guard let date = parseDate(raw) else { return "—" }
        return formatDay(date)
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let d = GardenStore.dateFormatter.date(from: raw) { return d }
        if let d = GardenStore.dateTimeFormatter.date(from: raw) { return d }
        return ISO8601DateFormatter().date(from: raw)
    }

    private func formatDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: date)
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
        f.dateFormat = "yyyy–MM–dd"
        return f.string(from: date)
    }

    private func scanTypeLabel(_ type: String) -> String {
        switch type {
        case "health": return "HEALTH"
        case "identify": return "ID"
        default: return "PHOTO"
        }
    }

    private func savePrivatePhoto(_ image: UIImage) async {
        guard let userId = appState.effectiveUserId else { return }
        let data = ImageCompressor.prepareForAI(image)
        guard !data.isEmpty else {
            photoError = "That image couldn't be processed."
            return
        }
        isSavingPhoto = true
        defer { isSavingPhoto = false }
        do {
            let path = try await StorageService.upload(
                userId: userId,
                imageData: data,
                folder: "logs",
                isGuest: appState.isGuest
            )
            _ = try await garden.addScan(
                NewScan(
                    userId: userId,
                    plantId: plantId,
                    photoUrl: path,
                    scanType: "log",
                    confidence: nil,
                    healthStatus: nil,
                    healthScore: nil
                )
            )
            await garden.updatePlant(id: plantId, photoUrl: path)
            await loadScans()
        } catch {
            photoError = error.localizedDescription
        }
    }

    private func loadScans() async {
        scans = (try? await garden.fetchScans(plantId: plantId)) ?? []
    }

    private func loadCareGuide() async {
        guard let userId = appState.effectiveUserId,
              let species = plant?.speciesLatinName else { return }
        careGuide = try? await garden.fetchCareGuide(userId: userId, speciesLatinName: species)
    }
}

private struct EditPlantSheet: View {
    let plant: Plant
    var onSave: (String, Int, Int, PlantPlacement) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var nickname: String
    @State private var interval: Int
    @State private var amount: Int
    @State private var placement: PlantPlacement

    init(plant: Plant, onSave: @escaping (String, Int, Int, PlantPlacement) -> Void) {
        self.plant = plant
        self.onSave = onSave
        _nickname = State(initialValue: plant.nickname)
        _interval = State(initialValue: plant.wateringIntervalDays ?? 7)
        _amount = State(initialValue: plant.wateringAmountMl ?? 250)
        _placement = State(initialValue: plant.placement == .unknown ? .indoor : plant.placement)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Nickname", text: $nickname)
                    Picker("Placement", selection: $placement) {
                        ForEach(PlantPlacement.allCases.filter { $0 != .unknown }, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }
                Section("Watering") {
                    Stepper("Every \(interval) days", value: $interval, in: 1...60)
                    Stepper(UnitsFormatting.waterAmount(ml: amount), value: $amount, in: 50...2000, step: 50)
                }
            }
            .navigationTitle("Edit plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(name.isEmpty ? plant.nickname : name, interval, amount, placement)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.primary)
                }
            }
        }
    }
}
