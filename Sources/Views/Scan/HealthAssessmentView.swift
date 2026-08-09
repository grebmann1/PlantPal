import SwiftUI

struct HealthAssessmentView: View {
    let context: CaptureContext
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var result: HealthAIResult?
    @State private var isSaving = false

    private var plant: Plant? {
        guard let id = context.plantId else { return nil }
        return garden.plants.first(where: { $0.id == id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let uiImage = UIImage(data: context.imageData) {
                    TapeMountPhoto(cornerRadius: theme.radius.lg) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipped()
                    }
                }

                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Assessing plant health\u{2026}").font(theme.subheadFont).foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                } else if let errorMessage {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 32)).foregroundStyle(theme.warning)
                        Text(errorMessage).font(theme.subheadFont).foregroundStyle(theme.textSecondary).multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button("Try again") { Task { await runAssessment() } }
                                .buttonStyle(.borderedProminent).tint(theme.primary)

                            if errorMessage.contains("OpenAI key") || errorMessage.contains("not ready") || errorMessage.contains("timed out") {
                                Button("Use Sample Assessment") {
                                    result = HealthAIResult(
                                        status: "Needs Attention",
                                        healthScore: 74,
                                        issues: [
                                            HealthIssue(label: "Slight leaf margin yellowing", severity: "Mild"),
                                            HealthIssue(label: "Dry topsoil depth", severity: "Mild")
                                        ],
                                        recommendations: [
                                            "Water with 250ml filtered water when top 2 inches dry out",
                                            "Wipe leaf surfaces with a damp cloth to boost light absorption"
                                        ]
                                    )
                                    self.errorMessage = nil
                                }
                                .buttonStyle(.bordered).tint(theme.primary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(theme.surfaceSunken)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
                } else if let result {
                    content(result)
                }
            }
            .padding(20)
        }
        .background(theme.background)
        .navigationTitle("Health Assessment")
        .navigationBarTitleDisplayMode(.inline)
        .task { await runAssessment() }
    }

    private func content(_ result: HealthAIResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.status)
                        .font(theme.title2Font)
                        .foregroundStyle(statusColor(result.status))
                    Text("\(result.healthScore) / 100")
                        .font(theme.subheadFont)
                        .foregroundStyle(theme.textSecondary)
                    PipsRow(filled: max(1, result.healthScore / 20), total: 5, color: statusColor(result.status), size: 6)
                    if let plant {
                        Text(plant.speciesLatinName ?? "").italic().font(theme.footnoteFont).foregroundStyle(theme.textTertiary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(statusColor(result.status).opacity(0.12))
                .overlay(LeafWatermark(opacity: 0.08, rotation: 12, color: statusColor(result.status)).frame(width: 90).offset(x: 10, y: -10), alignment: .topTrailing)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
            }

            if !result.issues.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Detected issues").font(theme.headlineFont).foregroundStyle(theme.textPrimary)
                    ForEach(result.issues) { issue in
                        HStack {
                            PipsRow(filled: severityPips(issue.severity), total: 4, color: severityColor(issue.severity), size: 6)
                            Text(issue.label).font(theme.subheadFont).foregroundStyle(theme.textPrimary)
                            Spacer()
                            Text(issue.severity.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(severityColor(issue.severity))
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }

            if !result.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations").font(theme.headlineFont).foregroundStyle(theme.textPrimary)
                    ForEach(result.recommendations, id: \.self) { rec in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(theme.primary).font(.footnote)
                            Text(rec).font(theme.subheadFont).foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }

            Button {
                Task { await save(result) }
            } label: {
                if isSaving {
                    ProgressView().tint(theme.onPrimary).frame(maxWidth: .infinity).padding(.vertical, 14)
                } else {
                    Text("Save to Plant Record").font(theme.headlineFont).frame(maxWidth: .infinity).padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
            .foregroundStyle(theme.onPrimary)
            .clipShape(Capsule())
            .disabled(isSaving || context.plantId == nil)

            Button {
                if let id = context.plantId {
                    coordinator.goToScan(mode: .health, plantId: id)
                }
            } label: {
                Text("Rescan this plant").font(theme.subheadFont).foregroundStyle(theme.primary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Healthy": return theme.success
        case "At Risk": return theme.error
        default: return theme.warning
        }
    }

    private func severityPips(_ severity: String) -> Int {
        switch severity {
        case "Severe": return 4
        case "Moderate": return 3
        case "Mild": return 2
        default: return 1
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "Severe", "Moderate": return theme.error
        case "Mild": return theme.warning
        default: return theme.textTertiary
        }
    }

    private func runAssessment() async {
        isLoading = true
        errorMessage = nil
        do {
            result = try await AIProxyService.health(imageData: context.imageData, speciesLatinName: plant?.speciesLatinName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func save(_ result: HealthAIResult) async {
        guard let userId = appState.effectiveUserId, let plantId = context.plantId else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let path = try await StorageService.upload(userId: userId, imageData: context.imageData, folder: "health", isGuest: appState.isGuest)
            _ = try await garden.addScan(NewScan(userId: userId, plantId: plantId, photoUrl: path, scanType: "health", confidence: nil, healthStatus: result.status, healthScore: result.healthScore))
            await garden.updatePlant(id: plantId, healthScore: result.healthScore, photoUrl: path)
            coordinator.goToPlantDetail(plantId)
        } catch {
            errorMessage = "Couldn't save this assessment: \(error.localizedDescription)"
        }
    }
}
