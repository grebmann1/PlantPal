import SwiftUI

struct HealthAssessmentView: View {
    let captureId: UUID
    let context: CaptureContext
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showDemoFallback = false
    @State private var result: HealthAIResult?
    @State private var isSaving = false
    @State private var attachedPlantId: UUID?
    @State private var showPlantPicker = false
    @State private var saveNotice: String?
    @State private var assessmentTask: Task<Void, Never>?

    private var plant: Plant? {
        guard let id = attachedPlantId else { return nil }
        return garden.plants.first(where: { $0.id == id })
    }

    private var assessmentNo: String {
        String(format: "%02d", abs((attachedPlantId ?? UUID()).hashValue) % 99)
    }

    private var captureStamp: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd · HH:mm"
        return f.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    PlantAnalysisLoadingView(
                        eyebrow: String(localized: "HEALTH CHECK"),
                        status: String(localized: "Assessing plant health…")
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                } else if let errorMessage {
                    errorBlock(errorMessage)
                        .padding(20)
                } else if let result {
                    verdictBand(result)
                    issuesSection(result)
                    if !result.recommendations.isEmpty {
                        rxCard(result.recommendations)
                            .padding(.horizontal, 20)
                            .padding(.top, 22)
                    }
                    footActions
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                }
            }
            .padding(.bottom, 16)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    guard !isSaving else { return }
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                    }
                    .foregroundStyle(theme.primary)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Health Assessment")
                    .font(theme.subheadFont.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            if attachedPlantId == nil {
                attachedPlantId = context.plantId
            }
            startAssessment()
        }
        .onDisappear { assessmentTask?.cancel() }
        .sheet(isPresented: $showPlantPicker) {
            PlantPickerSheet(plants: garden.plants, title: "Attach to a plant") { plant in
                attachedPlantId = plant.id
                Task {
                    if let result { await save(result) }
                }
            }
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { saveNotice != nil },
            set: { if !$0 { saveNotice = nil } }
        ), actions: {
            Button("OK", role: .cancel) { saveNotice = nil }
        }, message: {
            Text(saveNotice ?? "")
        })
    }

    private func errorBlock(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(theme.warning)
            Text(message)
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Try again") { startAssessment() }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary)
                    .disabled(isLoading)

                if showDemoFallback {
                    Button("Use Sample Assessment") {
                        result = HealthAIResult(
                            status: "Needs Attention",
                            healthScore: 64,
                            issues: [
                                HealthIssue(label: "Yellowing lower leaves", severity: "Moderate", detail: "4 leaves affected · likely overwatering"),
                                HealthIssue(label: "Brown leaf-edge crisping", severity: "Mild", detail: "Tips on 2 mature leaves · low humidity"),
                                HealthIssue(label: "Fungus gnats in topsoil", severity: "Watch", detail: "Adults visible near stem base")
                            ],
                            recommendations: [
                                "Skip the next watering; let the top 5 cm dry fully.",
                                "Trim the yellowed leaves at the petiole base.",
                                "Set a sticky trap and top-dress with 1 cm of sand."
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

    private func verdictBand(_ result: HealthAIResult) -> some View {
        ZStack(alignment: .bottomLeading) {
            LeafWatermark(opacity: 0.13, rotation: 128, color: theme.primary)
                .frame(width: 280, height: 320)
                .offset(x: -80, y: 100)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ASSESSMENT · NO. \(assessmentNo)")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(theme.textTertiary)

                        Text(verdictWord(result.status))
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .tracking(-0.9)
                            .foregroundStyle(theme.primary)
                            .lineSpacing(-2)

                        Text(verdictSummary(result))
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let uiImage = UIImage(data: context.imageData) {
                        TapeMountPhoto(cornerRadius: 4) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 128)
                                .clipped()
                        }
                        .rotationEffect(.degrees(2.2))
                    }
                }

                HStack(spacing: 10) {
                    metaChip {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor(result.status))
                                .frame(width: 8, height: 8)
                            Text("\(result.healthScore) / 100")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                    }
                    metaChip {
                        Text(captureStamp)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusColor(result.status).opacity(0.22))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(statusColor(result.status).opacity(0.45))
                .frame(height: 1)
        }
    }

    private func metaChip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.background.opacity(0.55))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.separator.opacity(0.6), lineWidth: 1))
    }

    private func issuesSection(_ result: HealthAIResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DETECTED ISSUES")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(theme.primary)
                Spacer()
                Text("SEVERITY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 10)

            if result.issues.isEmpty {
                Text("No discrete issues flagged.")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            } else {
                ForEach(result.issues) { issue in
                    issueRow(issue)
                }
            }
        }
    }

    private func issueRow(_ issue: HealthIssue) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: 100, bottomLeading: 8, bottomTrailing: 100, topTrailing: 8))
                    .fill(issueMarkBackground(issue.severity))
                    .frame(width: 34, height: 34)
                Image(systemName: issueMarkIcon(issue.severity))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(severityColor(issue.severity))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(issue.detail ?? severitySubline(issue.severity))
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                PipsRow(
                    filled: severityPips(issue.severity),
                    total: 4,
                    color: severityColor(issue.severity),
                    size: 6
                )
                Text(severityLabel(issue.severity).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(severityColor(issue.severity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1)
        }
    }

    private func rxCard(_ recommendations: [String]) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("RECOMMENDED ACTION")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(theme.primary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { index, rec in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.primary)
                            Text(rec)
                                .font(.system(size: 15))
                                .foregroundStyle(theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.accent.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(theme.primary.opacity(0.32), lineWidth: 1)
            )

            VStack(spacing: 0) {
                Text("Rx")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                Text("Care")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
            }
            .foregroundStyle(theme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.background)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.primary.opacity(0.55), lineWidth: 1.5)
            )
            .rotationEffect(.degrees(-8))
            .offset(x: -8, y: -14)
        }
    }

    private var footActions: some View {
        VStack(spacing: 14) {
            Button {
                Task {
                    guard let result else { return }
                    if attachedPlantId != nil {
                        await save(result)
                    } else if garden.plants.isEmpty {
                        saveNotice = String(localized: "Add a plant to your garden first if you want to save this assessment.")
                    } else {
                        showPlantPicker = true
                    }
                }
            } label: {
                if isSaving {
                    ProgressView().tint(theme.onPrimary).frame(maxWidth: .infinity).padding(.vertical, 16)
                } else {
                    Text(attachedPlantId == nil ? "Attach to a plant" : "Save to Plant Record")
                        .font(theme.headlineFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
            .foregroundStyle(theme.onPrimary)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
            .disabled(isSaving)

            Button {
                coordinator.goToScan(mode: .health, plantId: attachedPlantId)
            } label: {
                Text(attachedPlantId == nil ? "Scan again" : "Rescan this plant")
                    .font(theme.subheadFont)
                    .underline()
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func verdictWord(_ status: String) -> String {
        if status.localizedCaseInsensitiveContains("healthy") { return "Healthy" }
        if status.localizedCaseInsensitiveContains("risk") { return "At Risk" }
        let parts = status.split(separator: " ")
        if parts.count >= 2 {
            return parts.map(String.init).joined(separator: "\n")
        }
        return status
    }

    private func verdictSummary(_ result: HealthAIResult) -> AttributedString {
        var base = AttributedString()
        let count = result.issues.count
        let severityWord: String = {
            if result.issues.contains(where: { $0.severity.localizedCaseInsensitiveContains("severe") }) {
                return "severe"
            }
            if result.issues.contains(where: { $0.severity.localizedCaseInsensitiveContains("moderate") }) {
                return "moderate"
            }
            return "mild"
        }()

        if count == 0 {
            base = AttributedString("No discrete issues detected")
        } else {
            let countWord: String = {
                switch count {
                case 1: return "One"
                case 2: return "Two"
                case 3: return "Three"
                default: return "\(count)"
                }
            }()
            let noun = count == 1 ? "issue" : "issues"
            base = AttributedString("\(countWord) \(severityWord) \(noun) detected")
        }

        if let latin = plant?.speciesLatinName, !latin.isEmpty {
            base += AttributedString(" on ")
            var italic = AttributedString(latin)
            italic.font = .system(size: 14).italic()
            base += italic
            base += AttributedString(".")
        } else {
            base += AttributedString(".")
        }

        if result.healthScore >= 70 {
            base += AttributedString(" Recoverable with adjusted care.")
        } else if result.healthScore >= 50 {
            base += AttributedString(" Recoverable with adjusted watering.")
        } else {
            base += AttributedString(" Needs prompt intervention.")
        }
        return base
    }

    private func statusColor(_ status: String) -> Color {
        let s = status.lowercased()
        if s.contains("healthy") { return theme.success }
        if s.contains("risk") { return theme.error }
        return theme.warning
    }

    private func severityPips(_ severity: String) -> Int {
        switch severity.lowercased() {
        case "severe": return 4
        case "moderate": return 3
        case "mild": return 2
        default: return 1
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "severe": return theme.error
        case "moderate": return theme.warning
        case "mild": return theme.warning
        default: return theme.textTertiary
        }
    }

    private func severityLabel(_ severity: String) -> String {
        let s = severity.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "Watch" : s
    }

    private func severitySubline(_ severity: String) -> String {
        "Severity · \(severityLabel(severity))"
    }

    private func issueMarkIcon(_ severity: String) -> String {
        switch severity.lowercased() {
        case "severe": return "exclamationmark.triangle"
        case "moderate": return "leaf"
        case "mild": return "sun.max"
        default: return "ant"
        }
    }

    private func issueMarkBackground(_ severity: String) -> Color {
        severity.lowercased() == "severe" || severity.lowercased() == "watch"
            ? theme.error.opacity(0.18)
            : theme.secondary.opacity(0.26)
    }

    private func runAssessment() async {
        isLoading = true
        errorMessage = nil
        showDemoFallback = false
        do {
            result = try await AIProxyService.health(
                imageData: context.images,
                speciesLatinName: plant?.speciesLatinName
            )
        } catch is CancellationError {
            return
        } catch {
            let friendly = AIProxyError.from(error)
            errorMessage = friendly.localizedDescription
            showDemoFallback = friendly.offersDemoFallback
        }
        isLoading = false
    }

    private func startAssessment() {
        guard !isLoading || assessmentTask == nil else { return }
        assessmentTask?.cancel()
        assessmentTask = Task { await runAssessment() }
    }

    private func save(_ result: HealthAIResult) async {
        guard let userId = appState.effectiveUserId, let plantId = attachedPlantId else { return }
        isSaving = true
        defer { isSaving = false }
        var savedScans: [PlantScan] = []
        var lastError: Error?
        for imageData in context.images {
            var uploadedPath: String?
            do {
                let path = try await StorageService.upload(
                    userId: userId,
                    imageData: imageData,
                    folder: "health",
                    isGuest: appState.isGuest
                )
                uploadedPath = path
                let isPrimary = savedScans.isEmpty
                let scan = try await garden.addScan(
                    NewScan(
                        userId: userId,
                        plantId: plantId,
                        photoUrl: path,
                        scanType: isPrimary ? "health" : "log",
                        confidence: nil,
                        healthStatus: isPrimary ? result.status : nil,
                        healthScore: isPrimary ? result.healthScore : nil,
                        aiResultJson: isPrimary ? .health(result) : nil
                    )
                )
                savedScans.append(scan)
            } catch {
                if let uploadedPath {
                    try? await StorageService.remove(path: uploadedPath, isGuest: appState.isGuest)
                }
                lastError = error
            }
        }

        guard savedScans.count == context.images.count, let coverPath = savedScans.first?.photoUrl else {
            for scan in savedScans {
                try? await garden.deleteScan(scan)
            }
            saveNotice = String(
                localized: "Couldn't save this assessment: \(lastError?.localizedDescription ?? "Unknown error")"
            )
            return
        }

        do {
            try await garden.updatePlant(
                id: plantId,
                healthScore: result.healthScore,
                photoUrl: coverPath
            )
        } catch {
            for scan in savedScans {
                try? await garden.deleteScan(scan)
            }
            saveNotice = String(localized: "Couldn't save this assessment: \(error.localizedDescription)")
            return
        }
        coordinator.goToPlantDetail(plantId)
    }
}
