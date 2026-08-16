import SwiftUI
import UIKit

struct ScanPhotoPreparationView: View {
    let captureId: UUID
    let mode: ScanMode
    let context: CaptureContext

    @EnvironmentObject private var coordinator: Coordinator
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var photos: [Data] = []
    @State private var selectedPhotoIndex = 0
    @State private var plantId: UUID?
    @State private var showPhotoSource = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showPlantPicker = false
    @State private var showDiscardConfirmation = false
    @State private var isSaving = false
    @State private var isNavigating = false
    @State private var hasAppeared = false
    @State private var saveNotice: String?

    private let maxPhotos = 5

    private var selectedPlant: Plant? {
        guard let plantId else { return nil }
        return garden.plants.first(where: { $0.id == plantId })
    }

    private var activePhotoData: Data? {
        guard photos.indices.contains(selectedPhotoIndex) else { return photos.first }
        return photos[selectedPhotoIndex]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                gallery
                guidanceCard
                if mode != .identify {
                    plantSelector
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(mode == .log ? "Journal photos" : "Photos to analyze")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if photos.isEmpty {
                        discardDraft()
                    } else {
                        showDiscardConfirmation = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Scan")
                    }
                    .foregroundStyle(theme.primary)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            submitButton
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
        }
        .confirmationDialog(
            "Add another photo",
            isPresented: $showPhotoSource,
            titleVisibility: .visible
        ) {
            Button("Take photo") { showCamera = true }
            Button("Choose from library") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add another view of the same plant.")
        }
        .confirmationDialog(
            "Discard these photos?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard photos", role: .destructive, action: discardDraft)
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("You will need to choose these photos again to continue this scan.")
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(
                sourceType: .camera,
                onImage: appendPhoto,
                onDismiss: { showCamera = false }
            )
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            ImagePicker(
                sourceType: .photoLibrary,
                onImage: appendPhoto,
                onDismiss: { showLibrary = false }
            )
        }
        .sheet(isPresented: $showPlantPicker) {
            PlantPickerSheet(plants: garden.plants, title: "Choose a plant") { plant in
                plantId = plant.id
                coordinator.updateCapture(
                    for: captureId,
                    CaptureContext(images: photos, plantId: plant.id)
                )
            }
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { saveNotice != nil },
            set: { if !$0 { saveNotice = nil } }
        )) {
            Button("OK", role: .cancel) { saveNotice = nil }
        } message: {
            Text(saveNotice ?? "")
        }
        .task {
            if photos.isEmpty {
                photos = context.images
                selectedPhotoIndex = 0
                plantId = context.plantId
            }
        }
        .onAppear {
            if hasAppeared {
                isNavigating = false
            } else {
                hasAppeared = true
            }
        }
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: theme.radius.md)
                    .fill(theme.surfaceSunken)
                    .overlay {
                        if let activePhotoData, let image = UIImage(data: activePhotoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 38))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.md)
                            .stroke(Color.white.opacity(0.95), lineWidth: 4)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 270)
                    .appElevation(
                        AppTheme.Shadow(
                            color: .black.opacity(0.12),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                    )

                Text("\(photos.count) / \(maxPhotos)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.onPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.accent)
                    .padding(12)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                        photoThumbnail(data, index: index)
                    }

                    if photos.count < maxPhotos {
                        Button {
                            showPhotoSource = true
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("ADD")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(0.8)
                            }
                            .foregroundStyle(theme.primary)
                            .frame(width: 64, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                    )
                                    .foregroundStyle(theme.primary.opacity(0.45))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add another photo")
                    }
                }
                .padding(.vertical, 4)
            }

            Text("\(photos.count) of \(maxPhotos) photos · private to you")
                .font(theme.footnoteFont)
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func photoThumbnail(_ data: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                selectedPhotoIndex = index
            } label: {
                Group {
                    if let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        theme.surfaceSunken
                    }
                }
                .frame(width: 64, height: 80)
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            selectedPhotoIndex == index ? theme.primary : theme.separator,
                            lineWidth: selectedPhotoIndex == index ? 2 : 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button {
                removePhoto(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.black.opacity(0.65))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .accessibilityLabel("Remove photo \(index + 1)")
        }
        .padding(.top, 6)
        .padding(.trailing, 4)
    }

    private var guidanceCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(mode == .log ? "READY TO SAVE" : "READY TO ANALYZE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(theme.primary)
            Text(guidanceText)
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
    }

    private var guidanceText: String {
        switch mode {
        case .identify:
            "Add different angles if they show useful leaf shape, texture, or growth."
        case .health:
            "Include both the affected area and a wider view of the whole plant."
        case .log:
            "These photos will be saved together in the plant journal."
        }
    }

    private var plantSelector: some View {
        Button {
            showPlantPicker = true
        } label: {
            HStack {
                Image(systemName: "leaf.circle")
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode == .log ? "PLANT" : "ATTACH TO PLANT · OPTIONAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                    Text(selectedPlant?.nickname ?? "Choose a plant")
                        .font(theme.subheadFont)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(theme.primary)
            .padding(14)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
        }
        .buttonStyle(.plain)
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            Group {
                if isSaving || isNavigating {
                    ProgressView().tint(theme.onPrimary)
                } else {
                    Text(submitTitle)
                        .font(theme.headlineFont)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.primary)
        .foregroundStyle(theme.onPrimary)
        .disabled(photos.isEmpty || isSaving || isNavigating)
    }

    private var submitTitle: String {
        switch mode {
        case .identify:
            photos.count == 1 ? "Analyze 1 photo" : "Analyze \(photos.count) photos"
        case .health:
            "Analyze plant health"
        case .log:
            plantId == nil
                ? "Choose a plant to save"
                : (photos.count == 1 ? "Save photo" : "Save \(photos.count) photos")
        }
    }

    private func appendPhoto(_ image: UIImage) {
        guard photos.count < maxPhotos else { return }
        let data = ImageCompressor.prepareForAI(image)
        guard !data.isEmpty else {
            saveNotice = "That image couldn't be processed. Please choose another photo."
            return
        }
        photos.append(data)
        selectedPhotoIndex = photos.count - 1
        updateContext()
    }

    private func removePhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
        if index < selectedPhotoIndex {
            selectedPhotoIndex -= 1
        } else if index == selectedPhotoIndex {
            selectedPhotoIndex = min(index, max(0, photos.count - 1))
        }
        updateContext()
    }

    private func updateContext() {
        coordinator.updateCapture(
            for: captureId,
            CaptureContext(images: photos, plantId: plantId)
        )
    }

    private func submit() {
        guard !photos.isEmpty, !isSaving, !isNavigating else { return }
        let prepared = CaptureContext(images: photos, plantId: plantId)
        coordinator.updateCapture(for: captureId, prepared)

        switch mode {
        case .identify:
            isNavigating = true
            coordinator.startIdentification(for: captureId, context: prepared)
        case .health:
            isNavigating = true
            coordinator.startHealthAssessment(for: captureId, context: prepared)
        case .log:
            guard let plantId else {
                showPlantPicker = true
                return
            }
            isSaving = true
            Task { await saveJournalPhotos(photos, plantId: plantId) }
        }
    }

    private func saveJournalPhotos(_ images: [Data], plantId: UUID) async {
        defer { isSaving = false }
        guard let userId = appState.effectiveUserId else {
            saveNotice = "No active session. Please sign in or continue as guest again."
            return
        }

        var savedScans: [PlantScan] = []
        var lastError: Error?
        for data in images {
            var uploadedPath: String?
            do {
                let path = try await StorageService.upload(
                    userId: userId,
                    imageData: data,
                    folder: "logs",
                    isGuest: appState.isGuest
                )
                uploadedPath = path
                let scan = try await garden.addScan(
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
                savedScans.append(scan)
            } catch {
                if let uploadedPath {
                    try? await StorageService.remove(path: uploadedPath, isGuest: appState.isGuest)
                }
                lastError = error
            }
        }

        guard savedScans.count == images.count, let coverPath = savedScans.first?.photoUrl else {
            for scan in savedScans {
                try? await garden.deleteScan(scan)
            }
            coordinator.updateCapture(for: captureId, CaptureContext(images: images, plantId: plantId))
            saveNotice = "Couldn't save the photos: \(lastError?.localizedDescription ?? "Unknown error")"
            return
        }

        do {
            try await garden.updatePlant(id: plantId, photoUrl: coverPath)
        } catch {
            for scan in savedScans {
                try? await garden.deleteScan(scan)
            }
            coordinator.updateCapture(for: captureId, CaptureContext(images: images, plantId: plantId))
            saveNotice = "Couldn't save the photos: \(error.localizedDescription)"
            return
        }
        coordinator.goToPlantDetail(plantId)
    }

    private func discardDraft() {
        coordinator.clearCapture(for: captureId)
        dismiss()
    }
}
