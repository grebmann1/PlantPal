import SwiftUI
import UIKit

struct ScanPlantView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @EnvironmentObject private var garden: GardenStore
    @Environment(\.appTheme) private var theme

    @State private var mode: ScanMode = .identify
    @State private var contextPlantId: UUID?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var flashMode: FlashMode = .auto
    @State private var libraryPreview: UIImage?
    @State private var now = Date()

    private enum FlashMode: String, CaseIterable {
        case auto = "Auto"
        case on = "On"
        case off = "Off"

        var icon: String {
            switch self {
            case .auto: return "bolt.fill"
            case .on: return "bolt.fill"
            case .off: return "bolt.slash.fill"
            }
        }

        var pickerFlash: UIImagePickerController.CameraFlashMode {
            switch self {
            case .auto: return .auto
            case .on: return .on
            case .off: return .off
            }
        }
    }

    private var captureNumber: String {
        String(format: "%03d", max(1, garden.plants.count * 6 + 42))
    }

    private var clockLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }

    var body: some View {
        ZStack {
            // Viewfinder preview (placeholder botanical scene behind leaf mask)
            viewfinderBackground
                .ignoresSafeArea()

            LeafScanMaskOverlay(paper: theme.background, edge: theme.primary)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                hintChip
                bottomStrip
            }
        }
        .onAppear(perform: startScanSession)
        .onChange(of: coordinator.scanSessionID) { _, _ in startScanSession() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
        .accessibilityIdentifier("scan-screen")
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(
                sourceType: .camera,
                flashMode: flashMode.pickerFlash,
                onImage: handleCaptured,
                onDismiss: { showCamera = false }
            )
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            ImagePicker(
                sourceType: .photoLibrary,
                onImage: handleCaptured,
                onDismiss: { showLibrary = false }
            )
        }
        // Hide system nav only on the capture root — pushed ID/Health need their bars.
        .toolbar(coordinator.scanPath.isEmpty ? .hidden : .automatic, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(coordinator.scanPath.isEmpty ? .hidden : .automatic, for: .navigationBar)
    }

    private var viewfinderBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "3A6B4A"), Color(hex: "1A3324"), Color(hex: "0F1C14")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let libraryPreview {
                Image(uiImage: libraryPreview)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.85)
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 180, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.18))
                    .rotationEffect(.degrees(-18))
                    .offset(x: 40, y: -20)
            }
        }
        .clipped()
    }

    private var topBar: some View {
        HStack {
            Button {
                coordinator.selectedTab = .garden
            } label: {
                Text("\u{00D7}")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text("Field capture \u{00B7} No. \(captureNumber)")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.textSecondary)

            Spacer()

            Text(clockLabel)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var hintChip: some View {
        Text(hint)
            .font(theme.footnoteFont)
            .foregroundStyle(theme.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(theme.surface.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 40)
            .padding(.bottom, 18)
    }

    private var bottomStrip: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                LeafWatermark(opacity: 0.08, rotation: 16, color: theme.primary)
                    .frame(width: 180, height: 220)
                    .offset(x: 50, y: 40)

                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        libraryButton
                        Spacer()
                        shutterButton
                        Spacer()
                        flashButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                    modeSelector
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(theme.background)
    }

    private var libraryButton: some View {
        Button { showLibrary = true } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.surfaceSunken)
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(-3))
                        .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
                    if let libraryPreview {
                        Image(uiImage: libraryPreview)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 46, height: 46)
                            .clipped()
                            .rotationEffect(.degrees(-3))
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(theme.primary)
                            .rotationEffect(.degrees(-3))
                    }
                }
                .frame(width: 54, height: 54)
                Text("LIBRARY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 64)
        .accessibilityLabel("Choose from photo library")
    }

    private var shutterButton: some View {
        Button { showCamera = true } label: {
            Circle()
                .strokeBorder(theme.primary, lineWidth: 2)
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 62, height: 62)
                        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 3)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture photo")
    }

    private var flashButton: some View {
        Button {
            let all = FlashMode.allCases
            if let idx = all.firstIndex(of: flashMode) {
                flashMode = all[(idx + 1) % all.count]
            }
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.22))
                        .overlay(Circle().stroke(theme.primary.opacity(0.4), lineWidth: 1))
                        .frame(width: 54, height: 54)
                    Image(systemName: flashMode.icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(theme.primary)
                }
                Text(flashMode.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 64)
        .accessibilityLabel("Flash \(flashMode.rawValue)")
    }

    private var modeSelector: some View {
        HStack(spacing: 22) {
            ForEach(ScanMode.allCases, id: \.self) { m in
                Button {
                    mode = m
                    if m != .identify { contextPlantId = coordinator.scanPresetIntent?.plantId }
                    if m != .identify && contextPlantId == nil && !garden.plants.isEmpty {
                        // keep picker available via hint
                    }
                } label: {
                    VStack(spacing: 7) {
                        Text(m.title.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(mode == m ? theme.primary : theme.textTertiary)
                        Capsule()
                            .fill(mode == m ? theme.accent : Color.clear)
                            .frame(width: 5, height: 7)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(theme.textTertiary.opacity(0.55))
                .frame(height: 1)
                .padding(.horizontal, 28)
        }
    }

    private var hint: String {
        switch mode {
        case .identify:
            return "Take the first photo — you can add more angles before analysis"
        case .health:
            return "Take the first photo — you can add symptom views before analysis"
        case .log:
            return "Take the first photo — you can add more before saving"
        }
    }

    private func startScanSession() {
        if let intent = coordinator.consumeScanPresetIntent() {
            mode = intent.mode
            contextPlantId = intent.plantId
            libraryPreview = nil
        } else if coordinator.scanPath.isEmpty {
            resetForNewScan()
        }
    }

    private func resetForNewScan() {
        mode = .identify
        contextPlantId = nil
        libraryPreview = nil
    }

    private func handleCaptured(_ image: UIImage) {
        let aiData = ImageCompressor.prepareForAI(image)
        guard !aiData.isEmpty else { return }
        libraryPreview = image
        coordinator.pushPreparation(
            CaptureContext(imageData: aiData, plantId: contextPlantId),
            mode: mode
        )
    }
}
