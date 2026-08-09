import SwiftUI

struct CareGuideView: View {
    let plantId: UUID
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.appTheme) private var theme

    @State private var guide: CareGuide?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var expandedProblem: String?
    @State private var savedOffline = false
    @State private var scheduleAdded = false

    private var plant: Plant? { garden.plants.first(where: { $0.id == plantId }) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let plant {
                    ZStack(alignment: .topLeading) {
                        LeafWatermark(opacity: 0.10, rotation: -14, color: theme.primary)
                            .frame(width: 90)
                            .offset(x: -20, y: -18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plant.speciesCommonName ?? plant.nickname).font(theme.title2Font).foregroundStyle(theme.textPrimary)
                            Text(plant.speciesLatinName ?? "").italic().font(theme.subheadFont).foregroundStyle(theme.textSecondary)
                        }
                    }
                }

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if let errorMessage {
                    Text(errorMessage).font(theme.subheadFont).foregroundStyle(theme.error)
                } else if let guide {
                    grid(guide)
                    if let problems = guide.commonProblems, !problems.isEmpty {
                        problemsAccordion(problems)
                    }
                    actions
                }
            }
            .padding(20)
        }
        .background(theme.background)
        .navigationTitle("Care Guide")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadOrGenerate() }
    }

    private func grid(_ guide: CareGuide) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            careTile(icon: "sun.max", title: "Light", value: guide.lightRequirement ?? "\u{2014}", tint: theme.accent)
            careTile(icon: "drop", title: "Water", value: guide.wateringFrequency ?? "\u{2014}", tint: theme.primary)
            careTile(icon: "leaf", title: "Soil", value: guide.soilMix ?? "\u{2014}", tint: theme.secondary)
            careTile(icon: "thermometer.medium", title: "Climate", value: "\(guide.temperatureRange ?? "\u{2014}") \u{00B7} \(guide.humidityRange ?? "\u{2014}")", tint: theme.warning)
        }
    }

    private func careTile(icon: String, title: String, value: String, tint: Color) -> some View {
        OutlinedGlyphTile(systemImage: icon, title: title, value: value, tint: tint)
            .background(theme.surfaceSunken)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
    }

    private func problemsAccordion(_ problems: [CommonProblem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Common problems").font(theme.headlineFont).foregroundStyle(theme.textPrimary)
            ForEach(problems) { problem in
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation { expandedProblem = expandedProblem == problem.id ? nil : problem.id }
                    } label: {
                        HStack {
                            Text(problem.problem).font(theme.subheadFont.weight(.semibold)).foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: expandedProblem == problem.id ? "chevron.up" : "chevron.down")
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    if expandedProblem == problem.id {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cause: \(problem.cause)").font(theme.footnoteFont).foregroundStyle(theme.textSecondary)
                            Text("Fix: \(problem.fix)").font(theme.footnoteFont).foregroundStyle(theme.textSecondary)
                            Text("Recovery: \(problem.recoveryTime)").font(theme.footnoteFont).foregroundStyle(theme.textTertiary)
                        }
                    }
                }
                .padding(12)
                .background(theme.surfaceSunken)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await addToSchedule() }
            } label: {
                Text(scheduleAdded ? "Added to schedule" : "Add to Watering Schedule")
                    .font(theme.headlineFont)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
            .foregroundStyle(theme.onPrimary)
            .clipShape(Capsule())
            .disabled(scheduleAdded)

            Button {
                savedOffline = true
            } label: {
                Text(savedOffline ? "Saved for offline use" : "Save guide offline")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.primary)
            }
        }
    }

    private func loadOrGenerate() async {
        guard let userId = appState.effectiveUserId, let plant, let species = plant.speciesLatinName else {
            isLoading = false
            errorMessage = "Missing species information for this plant."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            if let cached = try await garden.fetchCareGuide(userId: userId, speciesLatinName: species) {
                guide = cached
            } else {
                let ai = try await AIProxyService.careGuide(speciesLatinName: species, speciesCommonName: plant.speciesCommonName)
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
                guide = try await garden.saveCareGuide(newGuide)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addToSchedule() async {
        guard let userId = appState.effectiveUserId, let plant else { return }
        let interval = plant.wateringIntervalDays ?? 7
        let due = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
        let reminder = NewReminder(userId: userId, plantId: plant.id, type: "watering", dueAt: ISO8601DateFormatter().string(from: due), amountLabel: guide?.wateringAmount)
        if (try? await garden.addReminder(reminder)) != nil {
            scheduleAdded = true
        }
    }
}
