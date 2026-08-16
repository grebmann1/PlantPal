import SwiftUI

struct CareGuideView: View {
    let plantId: UUID
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var guide: CareGuide?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var actionError: String?
    @State private var expandedProblem: String?
    @State private var savedOffline = false
    @State private var scheduleAdded = false
    @State private var isAddingSchedule = false
    @State private var isSavingOffline = false

    private var plant: Plant? { garden.plants.first(where: { $0.id == plantId }) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(theme.subheadFont)
                        .foregroundStyle(theme.error)
                        .padding(20)
                } else if let guide {
                    sunlightPanel(guide)
                    waterPanel(guide)
                    soilPanel(guide)
                    climatePanel(guide)
                    if let problems = guide.commonProblems, !problems.isEmpty {
                        problemsAccordion(problems)
                            .padding(.horizontal, 20)
                            .padding(.top, 22)
                    }
                    actions
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                    if let actionError {
                        actionErrorBanner(actionError)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Plant")
                    }
                    .foregroundStyle(theme.primary)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await loadOrGenerate() }
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            LeafWatermark(opacity: 0.10, rotation: -18, color: theme.primary)
                .frame(width: 140, height: 180)
                .offset(x: 30, y: -20)

            VStack(alignment: .leading, spacing: 8) {
                Text("CARE GUIDE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(theme.textTertiary)

                if let plant {
                    Text(plant.speciesCommonName ?? plant.nickname)
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(theme.primary)

                    HStack(spacing: 6) {
                        if let latin = plant.speciesLatinName {
                            Text(latin).italic()
                        }
                        if let family = plant.family, !family.isEmpty {
                            Text(family)
                        }
                    }
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textSecondary)
                }

                if let level = guide?.difficultyLevel {
                    HStack(spacing: 8) {
                        Text("DIFFICULTY")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(theme.textTertiary)
                        PipsRow(filled: min(5, max(1, level)), total: 5, color: theme.primary, size: 10)
                        Text(difficultyLabel(level))
                            .font(theme.footnoteFont)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 8)
    }

    private func sunlightPanel(_ guide: CareGuide) -> some View {
        CarePanel(
            icon: "sun.max",
            title: "Sunlight",
            value: guide.lightRequirement ?? "—",
            subtitle: lightSubtitle(guide.lightRequirement),
            note: "Rotate a quarter turn weekly so leaves fill evenly. Keep back from unshaded southern glass — direct midday light scorches broad blades.",
            tint: theme.primary,
            background: theme.accent.opacity(0.20)
        ) {
            lightScale(for: guide.lightRequirement)
        }
    }

    private func waterPanel(_ guide: CareGuide) -> some View {
        CarePanel(
            icon: "drop",
            title: "Water",
            value: guide.wateringFrequency ?? "—",
            subtitle: guide.wateringAmount.map { "≈ \(UnitsFormatting.waterAmount(label: $0)) · until drainage runs" },
            note: "Never let the pot sit in standing water.",
            tint: theme.primary,
            background: theme.primary.opacity(0.10)
        ) {
            VStack(spacing: 0) {
                CareLedgerRow(label: "Spring — Summer", value: guide.wateringFrequency ?? "—", dotColor: theme.success)
                CareLedgerRow(label: "Autumn — Winter", value: "Less frequent · check soil", dotColor: theme.warning)
                if let amount = guide.wateringAmount {
                    CareLedgerRow(label: "Target volume", value: UnitsFormatting.waterAmount(label: amount), dotColor: nil)
                }
            }
        }
    }

    private func soilPanel(_ guide: CareGuide) -> some View {
        CarePanel(
            icon: "leaf",
            title: "Soil & Feed",
            value: shortSoil(guide.soilMix),
            subtitle: guide.soilMix,
            note: "Refresh the top few centimetres yearly; repot when roots circle the pot.",
            tint: theme.secondary,
            background: theme.secondary.opacity(0.14)
        ) {
            VStack(spacing: 0) {
                CareLedgerRow(label: "Mix", value: shortSoil(guide.soilMix))
                CareLedgerRow(label: "Fertilizer", value: "Balanced liquid · half strength")
                CareLedgerRow(label: "Feeding window", value: "Spring — early autumn")
            }
        }
    }

    private func climatePanel(_ guide: CareGuide) -> some View {
        CarePanel(
            icon: "thermometer.medium",
            title: "Climate",
            value: guide.temperatureRange ?? "—",
            subtitle: guide.humidityRange.map { "Humidity · \($0)" },
            note: "Avoid cold drafts and sudden temperature swings.",
            tint: theme.warning,
            background: theme.warning.opacity(0.12)
        ) {
            VStack(spacing: 0) {
                CareLedgerRow(label: "Ideal range", value: guide.temperatureRange ?? "—")
                CareLedgerRow(label: "Humidity", value: guide.humidityRange ?? "—")
                CareLedgerRow(label: "Home region", value: UnitsFormatting.homeRegion)
            }
        }
    }

    private func lightScale(for requirement: String?) -> some View {
        let filledRange = lightFillRange(for: requirement)
        return VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(filledRange.contains(i) ? theme.primary : theme.separator.opacity(0.45))
                        .frame(height: 8)
                }
            }
            HStack {
                Text("DEEP SHADE")
                Spacer()
                Text("FULL SUN")
            }
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(theme.textTertiary)
        }
    }

    private func lightSubtitle(_ requirement: String?) -> String? {
        let text = (requirement ?? "").lowercased()
        if text.contains("bright") { return "6–8 hrs filtered · E or S window" }
        if text.contains("low") || text.contains("shade") { return "North window or deep room" }
        if text.contains("full") || text.contains("direct") { return "4+ hrs direct · south exposure" }
        return nil
    }

    private func lightFillRange(for requirement: String?) -> ClosedRange<Int> {
        let text = (requirement ?? "").lowercased()
        if text.contains("full sun") || text.contains("direct") { return 4...5 }
        if text.contains("bright") { return 2...3 }
        if text.contains("low") || text.contains("shade") { return 0...1 }
        return 2...3
    }

    private func shortSoil(_ mix: String?) -> String {
        guard let mix, !mix.isEmpty else { return "—" }
        let first = mix.split(separator: ".").first.map(String.init) ?? mix
        return first.count > 42 ? String(first.prefix(40)) + "…" : first
    }

    private func difficultyLabel(_ level: Int) -> String {
        switch level {
        case ...1: return "Easy"
        case 2: return "Easy–Moderate"
        case 3: return "Moderate"
        case 4: return "Challenging"
        default: return "Expert"
        }
    }

    private func problemsAccordion(_ problems: [CommonProblem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("COMMON PROBLEMS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.primary)
                .padding(.bottom, 10)

            ForEach(problems) { problem in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation { expandedProblem = expandedProblem == problem.id ? nil : problem.id }
                    } label: {
                        HStack {
                            Text(problem.problem)
                                .font(theme.subheadFont.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                                .rotationEffect(.degrees(expandedProblem == problem.id ? 90 : 0))
                        }
                    }
                    .buttonStyle(.plain)

                    if expandedProblem == problem.id {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cause: \(problem.cause)").font(theme.footnoteFont).foregroundStyle(theme.textSecondary)
                            Text("Fix: \(problem.fix)").font(theme.footnoteFont).foregroundStyle(theme.textSecondary)
                            Text(problem.recoveryTime)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.separator).frame(height: 1)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 14) {
            Button {
                Task { await addToSchedule() }
            } label: {
                Group {
                    if isAddingSchedule {
                        ProgressView().tint(theme.onPrimary)
                    } else {
                        Text(scheduleAdded ? "Watering schedule active" : "Add to Watering Schedule")
                            .font(theme.headlineFont)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
            .foregroundStyle(theme.onPrimary)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
            .disabled(scheduleAdded || isAddingSchedule)

            Button {
                Task { await saveGuideOffline() }
            } label: {
                if isSavingOffline {
                    ProgressView().tint(theme.primary)
                } else {
                    Text(savedOffline ? "Saved for offline use" : "Save guide offline")
                        .font(theme.subheadFont)
                        .underline()
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .disabled(guide == nil || savedOffline || isSavingOffline)
        }
    }

    private func loadOrGenerate() async {
        guard let userId = appState.effectiveUserId, let plant, let species = plant.speciesLatinName else {
            isLoading = false
            errorMessage = String(localized: "Missing species information for this plant.")
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            // 1) Per-user / on-device cache
            if let cached = try await garden.fetchCareGuide(userId: userId, speciesLatinName: species) {
                guide = await SpeciesI18nService.localizeCareGuide(cached, speciesLatinName: species)
                savedOffline = LocalGardenStore.loadCareGuides(userId: userId).contains { $0.speciesLatinName == species }
                scheduleAdded = garden.reminders.contains {
                    $0.plantId == plant.id && $0.type == "watering" && !$0.isCompleted
                }
                isLoading = false
                return
            }

            // 2) Shared species cache (any previous user/guest already paid for this AI call)
            if let shared = try? await AISpeciesCacheService.fetchCareGuide(speciesLatinName: species) {
                let newGuide = NewCareGuide(
                    userId: userId,
                    plantId: plant.id,
                    speciesLatinName: species,
                    lightRequirement: shared.lightRequirement,
                    wateringFrequency: shared.wateringFrequency,
                    wateringAmount: shared.wateringAmount,
                    soilMix: shared.soilMix,
                    temperatureRange: shared.temperatureRange,
                    humidityRange: shared.humidityRange,
                    difficultyLevel: shared.difficultyLevel,
                    commonProblems: shared.commonProblems
                )
                let saved = try await garden.saveCareGuide(newGuide)
                guide = await SpeciesI18nService.localizeCareGuide(saved, speciesLatinName: species)
                scheduleAdded = garden.reminders.contains {
                    $0.plantId == plant.id && $0.type == "watering" && !$0.isCompleted
                }
                isLoading = false
                return
            }

            // 3) Generate once, then store globally + for this user
            let ai = try await AIProxyService.careGuide(
                speciesLatinName: species,
                speciesCommonName: plant.speciesCommonName
            )
            do {
                _ = try await AISpeciesCacheService.upsertCareGuide(
                    speciesLatinName: species,
                    speciesCommonName: plant.speciesCommonName,
                    result: ai
                )
            } catch {
                // Shared cache write is best-effort; still persist the user guide below.
            }
            let newGuide = NewCareGuide(
                userId: userId,
                plantId: plant.id,
                speciesLatinName: species,
                lightRequirement: ai.lightRequirement,
                wateringFrequency: ai.wateringFrequency,
                wateringAmount: ai.wateringAmount,
                soilMix: ai.soilMix,
                temperatureRange: ai.temperatureRange,
                humidityRange: ai.humidityRange,
                difficultyLevel: ai.difficultyLevel,
                commonProblems: ai.commonProblems
            )
            let saved = try await garden.saveCareGuide(newGuide)
            guide = await SpeciesI18nService.localizeCareGuide(saved, speciesLatinName: species)
            scheduleAdded = garden.reminders.contains {
                $0.plantId == plant.id && $0.type == "watering" && !$0.isCompleted
            }
        } catch {
            errorMessage = AIProxyError.from(error).localizedDescription
        }
        isLoading = false
    }

    private func saveGuideOffline() async {
        guard let userId = appState.effectiveUserId, let plant, let guide else {
            actionError = String(localized: "Nothing to save yet.")
            return
        }
        isSavingOffline = true
        defer { isSavingOffline = false }
        LocalGardenStore.saveCareGuide(guide, userId: userId)
        savedOffline = true
        actionError = nil
    }

    private func addToSchedule() async {
        guard let userId = appState.effectiveUserId, let plant else { return }
        guard !isAddingSchedule else { return }
        isAddingSchedule = true
        defer { isAddingSchedule = false }
        let interval = plant.wateringIntervalDays ?? 7
        let due = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
        do {
            _ = try await garden.ensureWateringReminder(userId: userId, plant: plant, due: due)
            scheduleAdded = true
            actionError = nil
        } catch {
            actionError = String(localized: "Couldn't add watering schedule: \(error.localizedDescription)")
        }
    }

    private func actionErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(theme.footnoteFont)
            Spacer()
            Button("Dismiss") { actionError = nil }
                .font(theme.footnoteFont.weight(.semibold))
        }
        .foregroundStyle(theme.error)
        .padding(12)
        .background(theme.error.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
    }
}
