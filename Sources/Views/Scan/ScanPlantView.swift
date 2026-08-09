import SwiftUI

struct ScanPlantView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.appTheme) private var theme

    @State private var mode: ScanMode = .identify
    @State private var contextPlantId: UUID?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showPlantPicker = false
    @State private var isSavingLog = false
    @State private var logMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.textPrimary.opacity(0.9), theme.textPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Field capture")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 10) {
                    ZStack {
                        Image(systemName: "leaf")
                            .font(.system(size: 130, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.9))
                            .overlay(
                                Rectangle()
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(width: 1.4, height: 80)
                            )
                    }
                    .frame(height: 140)
                    SpecimenLabel(text: "Field capture \u{00B7} No. 042", tint: .white.opacity(0.85))
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.25))
                        .clipShape(Capsule())
                }

                Spacer()

                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(spacing: 6) {
                            Button {
                                showLibrary = true
                            } label: {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 20))
                                    .frame(width: 54, height: 54)
                                    .background(theme.surfaceSunken)
                                    .foregroundStyle(theme.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
                            }
                            Text("LIBRARY").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(width: 64)

                        Spacer()

                        Button {
                            showCamera = true
                        } label: {
                            Circle()
                                .strokeBorder(theme.primary, lineWidth: 2)
                                .frame(width: 80, height: 80)
                                .overlay(Circle().fill(theme.primary).frame(width: 62, height: 62))
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            Image(systemName: "bolt.slash.fill")
                                .font(.system(size: 20))
                                .frame(width: 54, height: 54)
                                .background(theme.accent.opacity(0.25))
                                .foregroundStyle(theme.primary)
                                .clipShape(Circle())
                            Text("AUTO").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(width: 64)
                    }
                    .padding(.horizontal, 24)

                    HStack(spacing: 22) {
                        ForEach(ScanMode.allCases, id: \.self) { m in
                            Button {
                                mode = m
                                if m != .identify { contextPlantId = coordinator.scanPresetIntent?.plantId }
                            } label: {
                                Text(m.rawValue.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.2)
                                    .foregroundStyle(mode == m ? theme.primary : .white.opacity(0.55))
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.vertical, 18)
                .background(theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 0)
            }
        }
        .onAppear(perform: applyPresetIntent)
        .onChange(of: coordinator.scanPresetIntent) { _, _ in applyPresetIntent() }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in handleCaptured(image) }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            ImagePicker(sourceType: .photoLibrary) { image in handleCaptured(image) }
        }
        .sheet(isPresented: $showPlantPicker) {
            PlantPickerSheet(plants: garden.plants, title: "Choose a plant") { plant in
                contextPlantId = plant.id
            }
        }
        .alert("Scan logged", isPresented: .constant(logMessage != nil), actions: {
            Button("OK") { logMessage = nil }
        }, message: {
            Text(logMessage ?? "")
        })
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hint: String {
        switch mode {
        case .identify: return "Fit one whole leaf in frame \u{2014} hold steady"
        case .health: return contextPlantId == nil ? "Choose a plant first, then capture a photo" : "Capture a clear photo for a health check"
        case .log: return contextPlantId == nil ? "Choose a plant first, then log a new photo" : "Capture a fresh photo to log"
        }
    }

    private func applyPresetIntent() {
        guard let intent = coordinator.scanPresetIntent else { return }
        mode = intent.mode
        contextPlantId = intent.plantId
    }

    private func handleCaptured(_ image: UIImage) {
        let aiData = ImageCompressor.prepareForAI(image)
        guard !aiData.isEmpty else { return }
        switch mode {
        case .identify:
            coordinator.scanPath.append(ScanRoute.identification(CaptureContext(imageData: aiData, plantId: nil)))
        case .health:
            if contextPlantId == nil {
                showPlantPicker = true
                return
            }
            coordinator.scanPath.append(ScanRoute.health(CaptureContext(imageData: aiData, plantId: contextPlantId)))
        case .log:
            if contextPlantId == nil {
                showPlantPicker = true
                return
            }
            Task { await logScan(imageData: aiData) }
        }
    }

    private func logScan(imageData: Data) async {
        guard let userId = appState.effectiveUserId, let plantId = contextPlantId else { return }
        isSavingLog = true
        defer { isSavingLog = false }
        do {
            let path = try await StorageService.upload(userId: userId, imageData: imageData, folder: "logs", isGuest: appState.isGuest)
            _ = try await garden.addScan(NewScan(userId: userId, plantId: plantId, photoUrl: path, scanType: "log", confidence: nil, healthStatus: nil, healthScore: nil))
            await garden.updatePlant(id: plantId, photoUrl: path)
            logMessage = "Saved a new photo to this plant's journal."
            coordinator.goToPlantDetail(plantId)
        } catch {
            logMessage = "Couldn't save the scan: \(error.localizedDescription)"
        }
    }
}
