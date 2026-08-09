import MapKit
import SwiftUI

struct IdentificationResultView: View {
    let context: CaptureContext
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @State private var isLoading = true
    @State private var identificationStatus = "Analyzing your plant…"
    @State private var errorMessage: String?
    @State private var result: IdentificationAIResult?
    @State private var selectedMatchIndex: Int = -1 // -1 = top match
    @State private var nickname = ""
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let uiImage = UIImage(data: context.imageData) {
                    ZStack(alignment: .topLeading) {
                        TapeMountPhoto(cornerRadius: theme.radius.lg) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 260)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        }
                        SpecimenLabel(text: "Specimen 041", tint: .white)
                            .padding(10)
                    }
                }

                if isLoading {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(theme.primary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("IDENTIFYING")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.4)
                                    .foregroundStyle(theme.primary)
                                Text(identificationStatus)
                                    .font(theme.subheadFont)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(theme.surfaceSunken)
                    .clipShape(.rect(cornerRadius: theme.radius.md))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Plant identification in progress")
                    .accessibilityValue(identificationStatus)
                } else if let error = errorMessage {
                    errorState(error)
                } else if let result {
                    resultContent(result)
                }
            }
            .padding(20)
        }
        .background(theme.background)
        .navigationTitle("Identification")
        .navigationBarTitleDisplayMode(.inline)
        .task { await runIdentification() }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(theme.warning)
            Text(message)
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Try again") {
                    Task { await runIdentification() }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)

                if message.contains("OpenAI key") || message.contains("not ready") || message.contains("timed out") {
                    Button("Use Demo Match") {
                        result = IdentificationAIResult(
                            speciesCommonName: "Monstera Deliciosa",
                            speciesLatinName: "Monstera deliciosa",
                            family: "Araceae",
                            confidence: 0.96,
                            lightRequirement: "Bright, indirect light",
                            wateringIntervalDays: 7,
                            alternateMatches: [
                                AlternateMatch(speciesCommonName: "Split-Leaf Philodendron", speciesLatinName: "Thaumatophyllum bipinnatifidum", confidence: 0.84),
                                AlternateMatch(speciesCommonName: "Swiss Cheese Vine", speciesLatinName: "Monstera adansonii", confidence: 0.72)
                            ]
                        )
                        errorMessage = nil
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(theme.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
    }

    private func resultContent(_ result: IdentificationAIResult) -> some View {
        let match = selectedMatchIndex >= 0 ? result.alternateMatches[selectedMatchIndex] : nil
        let commonName = match?.speciesCommonName ?? result.speciesCommonName
        let latinName = match?.speciesLatinName ?? result.speciesLatinName
        let confidence = match?.confidence ?? result.confidence

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(commonName).font(theme.title2Font).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("\(Int(confidence * (confidence <= 1 ? 100 : 1)))%")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(theme.primary.opacity(0.15))
                        .foregroundStyle(theme.primary)
                        .clipShape(Capsule())
                }
                Text(latinName).italic().font(theme.subheadFont).foregroundStyle(theme.textSecondary)
                Text("Family \(result.family) \u{00B7} \(result.lightRequirement) \u{00B7} Water every \(result.wateringIntervalDays)d")
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.textTertiary)
            }

            TextField("Give it a nickname", text: $nickname)
                .padding(10)
                .background(theme.surfaceSunken)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))

            if !result.alternateMatches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Not quite right? Other matches")
                        .font(theme.footnoteFont)
                        .foregroundStyle(theme.textTertiary)
                    ForEach(Array(result.alternateMatches.enumerated()), id: \.offset) { idx, alt in
                        Button {
                            selectedMatchIndex = selectedMatchIndex == idx ? -1 : idx
                        } label: {
                            HStack {
                                Text(alt.speciesCommonName).font(theme.subheadFont).foregroundStyle(theme.textPrimary)
                                Text(alt.speciesLatinName).italic().font(.caption).foregroundStyle(theme.textSecondary)
                                Spacer()
                                Text("\(Int(alt.confidence * (alt.confidence <= 1 ? 100 : 1)))%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(theme.textSecondary)
                            }
                            .padding(10)
                            .background(selectedMatchIndex == idx ? theme.primary.opacity(0.12) : theme.surfaceSunken)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if selectedMatchIndex == -1 {
                aboutSection(result)
            }

            if let errorMessage {
                Text(errorMessage).font(theme.footnoteFont).foregroundStyle(theme.error)
            }

            Button {
                Task { await addToGarden(commonName: commonName, latinName: latinName, family: result.family, confidence: confidence, light: result.lightRequirement, interval: result.wateringIntervalDays) }
            } label: {
                if isSaving {
                    ProgressView().tint(theme.onPrimary).frame(maxWidth: .infinity).padding(.vertical, 14)
                } else {
                    Text("Add \u{201C}\(nickname.isEmpty ? commonName : nickname)\u{201D} to Garden")
                        .font(theme.headlineFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
            .foregroundStyle(theme.onPrimary)
            .clipShape(Capsule())
            .disabled(isSaving)
        }
    }

    @ViewBuilder
    private func aboutSection(_ result: IdentificationAIResult) -> some View {
        let facts: [(String, String)] = [
            ("Native region", result.nativeRegion),
            ("Mature size", result.matureSize),
            ("Growth rate", result.growthRate),
            ("Toxicity", result.toxicity)
        ].compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }

        if (result.description?.isEmpty == false) || !facts.isEmpty || (result.funFact?.isEmpty == false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("About this plant")
                    .font(theme.footnoteFont.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(theme.textTertiary)

                if let description = result.description, !description.isEmpty {
                    Text(description)
                        .font(theme.subheadFont)
                        .foregroundStyle(theme.textPrimary)
                }

                if !facts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(facts, id: \.0) { label, value in
                            HStack(alignment: .top, spacing: 8) {
                                Text(label.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundStyle(theme.textTertiary)
                                    .frame(width: 96, alignment: .leading)
                                Text(value)
                                    .font(theme.footnoteFont)
                                    .foregroundStyle(theme.textSecondary)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                if let funFact = result.funFact, !funFact.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.accent)
                        Text(funFact)
                            .font(theme.footnoteFont.italic())
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .padding(14)
            .background(theme.surfaceSunken)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
        }
    }

    private func runIdentification() async {
        isLoading = true
        identificationStatus = "Analyzing your plant…"
        errorMessage = nil
        do {
            result = try await AIProxyService.identify(imageData: context.imageData)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addToGarden(commonName: String, latinName: String, family: String, confidence: Double, light: String, interval: Int) async {
        guard let userId = appState.effectiveUserId else {
            errorMessage = "Couldn't add this plant: no active session. Please sign in or continue as guest again."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let photoPath = try await StorageService.upload(userId: userId, imageData: context.imageData, folder: "plants", isGuest: appState.isGuest)
            let nextWater = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
            let newPlant = NewPlant(
                userId: userId,
                nickname: nickname.isEmpty ? commonName : nickname,
                speciesCommonName: commonName,
                speciesLatinName: latinName,
                family: family,
                photoUrl: photoPath,
                healthScore: 90,
                nextWateringDate: GardenStore.dateFormatter.string(from: nextWater),
                wateringIntervalDays: interval,
                wateringAmountMl: 250
            )
            let created = try await garden.addPlant(newPlant)
            _ = try? await garden.addScan(NewScan(userId: userId, plantId: created.id, photoUrl: photoPath, scanType: "identify", confidence: confidence, healthStatus: nil, healthScore: nil))
            _ = try? await garden.addReminder(NewReminder(userId: userId, plantId: created.id, type: "watering", dueAt: ISO8601DateFormatter().string(from: nextWater), amountLabel: "250 ml"))
            coordinator.goToPlantDetail(created.id)
        } catch {
            errorMessage = "Couldn't add this plant: \(error.localizedDescription)"
        }
    }
}
