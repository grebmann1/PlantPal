import SwiftUI
import UIKit

struct IdentificationResultView: View {
    let captureId: UUID
    let context: CaptureContext
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var catalog: SpeciesCatalogStore
    @EnvironmentObject private var speciesCollections: SpeciesCollectionStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var isLoading = true
    @State private var identificationStatus = String(localized: "Analyzing your plant…")
    @State private var errorMessage: String?
    @State private var showDemoFallback = false
    @State private var result: IdentificationAIResult?
    @State private var selectedMatchIndex: Int = -1 // -1 = top match
    @State private var nickname = ""
    @State private var isSaving = false
    @State private var showManualSearch = false
    @State private var manualCommon = ""
    @State private var manualLatin = ""
    @State private var catalogMatch: SpeciesCatalog?
    /// Perenual catalog rows for alternate matches (keyed by lowercased Latin name).
    @State private var alternateCatalog: [String: SpeciesCatalog] = [:]
    @State private var photos: [Data] = []
    @State private var selectedPhotoIndex = 0
    @State private var identificationTask: Task<Void, Never>?

    private var scannedAtLabel: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy–MM–dd · HH:mm"
        return String(localized: "Scanned \(f.string(from: Date()))")
    }

    private var activePhotoData: Data {
        guard photos.indices.contains(selectedPhotoIndex) else {
            return photos.first ?? context.imageData
        }
        return photos[selectedPhotoIndex]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    captureGallery
                    loadingCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                } else if let error = errorMessage, result == nil {
                    captureGallery
                    errorState(error)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                } else if let result {
                    captureGallery
                    resultContent(result, confidence: displayConfidence(result))
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }
            }
            .padding(.bottom, 40)
        }
        .background {
            ZStack(alignment: .bottomTrailing) {
                theme.background
                LeafWatermark(opacity: 0.10, rotation: 18, color: theme.primary)
                    .frame(width: 260, height: 320)
                    .offset(x: 60, y: 80)
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Identification Result")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    guard !isSaving else { return }
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Scan")
                    }
                    .foregroundStyle(theme.primary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let catalogMatch {
                    Button {
                        Task { await speciesCollections.toggleFavorite(catalogMatch) }
                    } label: {
                        Image(
                            systemName: speciesCollections.isFavorite(catalogMatch.id)
                                ? "heart.fill"
                                : "heart"
                        )
                        .foregroundStyle(theme.primary)
                    }
                    .accessibilityLabel(
                        speciesCollections.isFavorite(catalogMatch.id)
                            ? "Remove \(catalogMatch.displayName) from favorites"
                            : "Add \(catalogMatch.displayName) to favorites"
                    )
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showManualSearch) {
            manualSearchSheet
        }
        .task {
            if photos.isEmpty {
                photos = context.images.isEmpty ? [context.imageData] : context.images
            }
            startIdentification()
        }
        .onDisappear { identificationTask?.cancel() }
        .onChange(of: selectedMatchIndex) { _, newValue in
            guard let result else { return }
            let latin = newValue >= 0
                ? result.alternateMatches[newValue].speciesLatinName
                : result.speciesLatinName
            Task { await enrichFromCatalog(latinName: latin) }
        }
    }

    // MARK: - Capture gallery (mounted, show whole photo — no full-bleed crop)

    private var captureGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: theme.radius.md)
                    .fill(theme.surfaceSunken)
                    .overlay {
                        Group {
                            if let uiImage = UIImage(data: activePhotoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(theme.primary.opacity(0.35))
                            }
                        }
                        .padding(10)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.md)
                            .stroke(Color.white.opacity(0.95), lineWidth: 4)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .appElevation(AppTheme.Shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3))
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                Text("Specimen \(String(format: "%03d", abs(activePhotoData.hashValue) % 999))")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(theme.onPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.accent)
                    .rotationEffect(.degrees(2))
                    .padding(.top, 18)
                    .padding(.trailing, 32)
            }

            photoStrip
                .padding(.horizontal, 20)

            Text("\(photos.count) photo\(photos.count == 1 ? "" : "s") analyzed · private to you")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 24)
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                    Button {
                        selectedPhotoIndex = index
                    } label: {
                        Group {
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                theme.surfaceSunken
                            }
                        }
                        .frame(width: 56, height: 72)
                        .clipped()
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    selectedPhotoIndex == index ? theme.primary : Color.white.opacity(0.9),
                                    lineWidth: selectedPhotoIndex == index ? 2 : 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func matchBadge(_ confidence: Double) -> some View {
        let pct = Int((normalizedConfidence(confidence) * 100).rounded())
        return VStack(spacing: 1) {
            Text("\(pct)%")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.primary)
            Text("MATCH")
                .font(.system(size: 8, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(theme.primary)
        }
        .frame(width: 58, height: 58)
        .background(theme.surfaceElevated)
        .clipShape(Circle())
        .overlay(Circle().stroke(theme.primary, lineWidth: 1.5))
        .overlay(Circle().stroke(theme.primary.opacity(0.3), lineWidth: 1).padding(-4))
    }

    // MARK: - Loading / Error

    private var loadingCard: some View {
        PlantAnalysisLoadingView(
            eyebrow: String(localized: "IDENTIFYING"),
            status: identificationStatus
        )
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(theme.warning)
            Text(message)
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Try again") {
                    startIdentification()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
                .disabled(isLoading)

                if showDemoFallback {
                    Button("Use Demo Match") {
                        applyDemoResult()
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    }

    // MARK: - Result

    private func resultContent(_ result: IdentificationAIResult, confidence: Double) -> some View {
        let match = selectedMatchIndex >= 0 ? result.alternateMatches[selectedMatchIndex] : nil
        let commonName = match?.speciesCommonName ?? result.speciesCommonName
        let latinName = match?.speciesLatinName ?? result.speciesLatinName
        let matchConfidence = match?.confidence ?? result.confidence

        return VStack(alignment: .leading, spacing: 22) {
            bestMatchCard(
                commonName: commonName,
                latinName: latinName,
                family: result.family,
                light: result.lightRequirement,
                interval: result.wateringIntervalDays,
                isAlternate: selectedMatchIndex >= 0,
                confidence: matchConfidence
            )

            if !result.alternateMatches.isEmpty {
                alternateMatchesRow(result.alternateMatches)
            }

            if selectedMatchIndex == -1 {
                aboutSection(result)
            }

            if let catalogMatch {
                catalogMatchCard(catalogMatch)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.error)
            }

            VStack(spacing: 14) {
                Button {
                    Task {
                        await addToGarden(
                            commonName: commonName,
                            latinName: latinName,
                            family: result.family,
                            confidence: matchConfidence,
                            light: result.lightRequirement,
                            interval: result.wateringIntervalDays
                        )
                    }
                } label: {
                    if isSaving {
                        ProgressView().tint(theme.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Add '\(nickname.isEmpty ? commonName : nickname)' to Garden")
                            .font(theme.headlineFont)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
                .foregroundStyle(theme.onPrimary)
                .clipShape(Capsule())
                .disabled(isSaving)

                Button {
                    showManualSearch = true
                } label: {
                    Text("Not this plant? Search manually")
                        .font(theme.subheadFont)
                        .underline(true, color: theme.textSecondary)
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)
        }
    }

    private func bestMatchCard(
        commonName: String,
        latinName: String,
        family: String,
        light: String,
        interval: Int,
        isAlternate: Bool,
        confidence: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isAlternate ? "SELECTED MATCH" : "BEST MATCH")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(theme.primary)

                    Text(commonName)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(theme.primary)
                    Text(latinName)
                        .font(.system(size: 16, design: .serif))
                        .italic()
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 12)
                matchBadge(confidence)
            }

            Divider().overlay(theme.separator)

            HStack(spacing: 0) {
                careStat(label: "FAMILY", value: family.isEmpty ? "—" : family)
                Rectangle().fill(theme.separator).frame(width: 1, height: 36)
                careStat(label: "LIGHT", value: shortLight(light))
                Rectangle().fill(theme.separator).frame(width: 1, height: 36)
                careStat(label: "WATER", value: "Every \(interval) days")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("GIVE IT A NICKNAME")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.textTertiary)
                TextField("e.g. Window Monster", text: $nickname)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.bottom, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(theme.separator)
                            .frame(height: 1.5)
                    }
            }
            .padding(.top, 4)

            Text(scannedAtLabel)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(theme.error.opacity(0.35))
                .frame(width: 1.5)
                .padding(.vertical, 16)
                .padding(.leading, 10)
        }
        .appElevation(AppTheme.Shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4))
    }

    private func careStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(theme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private func alternateMatchesRow(_ matches: [AlternateMatch]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OTHER POSSIBLE MATCHES")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(matches.enumerated()), id: \.offset) { idx, alt in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMatchIndex = selectedMatchIndex == idx ? -1 : idx
                            }
                        } label: {
                            alternateTile(alt, selected: selectedMatchIndex == idx)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func alternateTile(_ alt: AlternateMatch, selected: Bool) -> some View {
        let pct = normalizedConfidence(alt.confidence) * 100
        let key = alt.speciesLatinName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let imageUrl = alternateCatalog[key]?.displayImageUrls.first ?? alternateCatalog[key]?.imageUrl

        return VStack(alignment: .leading, spacing: 6) {
            CatalogPhoto(urlString: imageUrl)
                .frame(width: 126, height: 126)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? theme.primary : Color.clear, lineWidth: 2)
                )

            Text(alt.speciesCommonName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .frame(width: 126, alignment: .leading)

            Text(String(format: "%.1f%%", pct))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textSecondary)

            Text(shortLatin(alt.speciesLatinName))
                .font(.system(size: 10, design: .monospaced))
                .italic()
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
                .frame(width: 126, alignment: .leading)
        }
        .frame(width: 126, alignment: .leading)
    }

    private func catalogMatchCard(_ species: SpeciesCatalog) -> some View {
        Button {
            coordinator.presentSpeciesFromScan(species.id)
        } label: {
            HStack(spacing: 14) {
                CatalogPhoto(urlString: species.imageUrl)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))

                VStack(alignment: .leading, spacing: 4) {
                    Text("FROM SPECIES CATALOG")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(theme.primary)
                    Text(species.displayName)
                        .font(theme.headlineFont)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(species.wateringLabel)
                        .font(theme.footnoteFont)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(12)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.md)
                    .stroke(theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                Text("ABOUT THIS PLANT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
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
            .background(theme.surface.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
        }
    }

    private var manualSearchSheet: some View {
        NavigationStack {
            Form {
                Section("Species") {
                    TextField("Common name", text: $manualCommon)
                    TextField("Latin name (optional)", text: $manualLatin)
                }
            }
            .navigationTitle("Search manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showManualSearch = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        applyManualMatch()
                        showManualSearch = false
                    }
                    .disabled(manualCommon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(theme.primary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func normalizedConfidence(_ value: Double) -> Double {
        value > 1 ? value / 100 : value
    }

    private func displayConfidence(_ result: IdentificationAIResult) -> Double {
        if selectedMatchIndex >= 0 {
            return normalizedConfidence(result.alternateMatches[selectedMatchIndex].confidence)
        }
        return normalizedConfidence(result.confidence)
    }

    private func shortLight(_ light: String) -> String {
        light
            .replacingOccurrences(of: "light", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",,", with: ",")
    }

    private func shortLatin(_ latin: String) -> String {
        let parts = latin.split(separator: " ")
        guard parts.count >= 2 else { return latin }
        let genus = parts[0].prefix(1)
        return "\(genus). \(parts.dropFirst().joined(separator: " "))"
    }

    private func applyDemoResult() {
        let demo = IdentificationAIResult(
            speciesCommonName: "Swiss Cheese Plant",
            speciesLatinName: "Monstera deliciosa",
            family: "Araceae",
            confidence: 0.96,
            lightRequirement: "Bright indirect",
            wateringIntervalDays: 7,
            alternateMatches: [
                AlternateMatch(speciesCommonName: "Split-leaf Philodendron", speciesLatinName: "Philodendron bipinnatifidum", confidence: 0.028),
                AlternateMatch(speciesCommonName: "Swiss Cheese Vine", speciesLatinName: "Monstera adansonii", confidence: 0.009),
                AlternateMatch(speciesCommonName: "Mini Monstera", speciesLatinName: "Rhaphidophora tetrasperma", confidence: 0.003)
            ]
        )
        if nickname.isEmpty { nickname = "Big Mo" }
        errorMessage = nil
        Task {
            await AISpeciesCacheService.upsertProfile(from: demo)
            result = await SpeciesI18nService.localizeIdentification(demo)
            await enrichFromCatalog(latinName: "Monstera deliciosa")
        }
    }

    private func applyManualMatch() {
        let common = manualCommon.trimmingCharacters(in: .whitespacesAndNewlines)
        let latin = manualLatin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !common.isEmpty else { return }
        let resolvedLatin = latin.isEmpty ? common : latin
        if var current = result {
            current.speciesCommonName = common
            current.speciesLatinName = resolvedLatin
            current.confidence = 1
            result = current
            selectedMatchIndex = -1
        } else {
            result = IdentificationAIResult(
                speciesCommonName: common,
                speciesLatinName: resolvedLatin,
                family: "",
                confidence: 1,
                lightRequirement: "Bright indirect",
                wateringIntervalDays: 7,
                alternateMatches: []
            )
        }
        if nickname.isEmpty { nickname = common }
        errorMessage = nil
        Task { await enrichFromCatalog(latinName: resolvedLatin) }
    }

    private func runIdentification() async {
        isLoading = true
        identificationStatus = String(localized: "Analyzing your plant…")
        errorMessage = nil
        showDemoFallback = false
        catalogMatch = nil
        alternateCatalog = [:]
        do {
            let album = photos.isEmpty ? context.images : photos
            let identified = try await AIProxyService.identify(imageData: album)
            // Persist English canonical profile before localizing for display.
            await AISpeciesCacheService.upsertProfile(from: identified)
            result = await SpeciesI18nService.localizeIdentification(identified)
            // Leave nickname empty so placeholder "e.g. Window Monster" shows
            await enrichFromCatalog(latinName: identified.speciesLatinName)
        } catch is CancellationError {
            return
        } catch {
            let friendly = AIProxyError.from(error)
            errorMessage = friendly.localizedDescription
            showDemoFallback = friendly.offersDemoFallback
        }
        isLoading = false
    }

    private func startIdentification() {
        guard !isLoading || identificationTask == nil else { return }
        identificationTask?.cancel()
        identificationTask = Task { await runIdentification() }
    }

    private func enrichFromCatalog(latinName: String) async {
        let match = await catalog.lookup(scientificName: latinName)
        catalogMatch = match
        if let match {
            await speciesCollections.recordViewed(match)
        }
        await enrichAlternateCatalogPhotos()
    }

    /// Fetch Perenual (via proxy → species_catalog cache) images for alternate matches.
    private func enrichAlternateCatalogPhotos() async {
        guard let result else { return }
        for alt in result.alternateMatches {
            let key = alt.speciesLatinName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !key.isEmpty, alternateCatalog[key] == nil else { continue }
            if let species = await catalog.lookup(scientificName: alt.speciesLatinName) {
                alternateCatalog[key] = species
            }
        }
    }

    private func addToGarden(commonName: String, latinName: String, family: String, confidence: Double, light: String, interval: Int) async {
        guard let userId = appState.effectiveUserId else {
            errorMessage = String(localized: "Couldn't add this plant: no active session. Please sign in or continue as guest again.")
            return
        }
        isSaving = true
        defer { isSaving = false }
        var uploadedPaths: [String] = []
        var createdPlant: Plant?
        var savedScans: [PlantScan] = []
        do {
            let album = photos.isEmpty ? [context.imageData] : photos
            var uploadError: Error?
            for data in album {
                do {
                    let path = try await StorageService.upload(
                        userId: userId,
                        imageData: data,
                        folder: "plants",
                        isGuest: appState.isGuest
                    )
                    uploadedPaths.append(path)
                } catch {
                    uploadError = error
                }
            }
            guard uploadedPaths.count == album.count, let photoPath = uploadedPaths.first else {
                for path in uploadedPaths {
                    try? await StorageService.remove(path: path, isGuest: appState.isGuest)
                }
                errorMessage = String(
                    localized: "Couldn't add this plant: \(uploadError?.localizedDescription ?? "no photo to save")"
                )
                return
            }

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
            createdPlant = created
            let payload: AIScanPayload? = result.map { .identify($0) }
            for (index, path) in uploadedPaths.enumerated() {
                let scan = try await garden.addScan(
                    NewScan(
                        userId: userId,
                        plantId: created.id,
                        photoUrl: path,
                        scanType: index == 0 ? "identify" : "log",
                        confidence: index == 0 ? normalizedConfidence(confidence) : nil,
                        healthStatus: nil,
                        healthScore: nil,
                        aiResultJson: index == 0 ? payload : nil
                    )
                )
                savedScans.append(scan)
            }
            _ = try await garden.ensureWateringReminder(userId: userId, plant: created, due: nextWater)
            coordinator.goToPlantDetail(created.id)
        } catch {
            if let createdPlant {
                await garden.deletePlant(id: createdPlant.id)
            } else {
                for path in uploadedPaths {
                    try? await StorageService.remove(path: path, isGuest: appState.isGuest)
                }
            }
            errorMessage = String(localized: "Couldn't add this plant: \(error.localizedDescription)")
        }
    }
}
