import SwiftUI

struct SpeciesDetailView: View {
    let speciesId: Int

    @EnvironmentObject private var catalog: SpeciesCatalogStore
    @EnvironmentObject private var speciesCollections: SpeciesCollectionStore
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @State private var species: SpeciesCatalog?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isAdding = false
    @State private var heroPage = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    PlantAnalysisLoadingView(
                        eyebrow: String(localized: "LOADING SPECIES"),
                        status: String(localized: "Gathering botanical details…")
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                } else {
                    if species != nil {
                        hero
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        if let errorMessage {
                            Text(errorMessage)
                                .font(theme.subheadFont)
                                .foregroundStyle(theme.error)
                                .padding(.top, 20)
                        } else if let species {
                            titleBlock(species)
                            careStats(species)
                            if let description = species.description, !description.isEmpty {
                                aboutBlock(description)
                            }
                            addToGardenButton(species)
                            if let license = species.imageLicense, !license.isEmpty {
                                attribution(license, url: species.imageLicenseUrl)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .offset(y: species == nil ? 0 : -28)
                }
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Species")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let species {
                    Button {
                        Task { await speciesCollections.toggleFavorite(species) }
                    } label: {
                        Image(systemName: speciesCollections.isFavorite(species.id) ? "heart.fill" : "heart")
                            .foregroundStyle(theme.primary)
                    }
                    .accessibilityLabel(
                        speciesCollections.isFavorite(species.id)
                            ? "Remove \(species.displayName) from favorites"
                            : "Add \(species.displayName) to favorites"
                    )
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private var hero: some View {
        let urls = species?.displayImageUrls ?? []
        return ZStack(alignment: .bottom) {
            TabView(selection: $heroPage) {
                if urls.isEmpty {
                    CatalogPhoto(urlString: nil)
                        .tag(0)
                } else {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        CatalogPhoto(urlString: url)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 280)
            .frame(maxWidth: .infinity)
            .clipped()

            if urls.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<urls.count, id: \.self) { index in
                        Circle()
                            .fill(index == heroPage ? Color.white : Color.white.opacity(0.45))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.bottom, 36)
                .allowsHitTesting(false)
            }
        }
        .onChange(of: species?.id) { _, _ in
            heroPage = 0
        }
    }

    private func titleBlock(_ species: SpeciesCatalog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SPECIES CARD")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.primary)

            Text(species.displayName)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(theme.primary)

            if let latin = species.scientificName, !latin.isEmpty {
                Text(latin)
                    .font(.system(size: 17, design: .serif))
                    .italic()
                    .foregroundStyle(theme.textSecondary)
            }

            if let family = species.family, !family.isEmpty {
                Text(family.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    }

    private func careStats(_ species: SpeciesCatalog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CARE SNAPSHOT")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.textTertiary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                statCard(label: "Watering", value: species.wateringLabel)
                statCard(label: "Sunlight", value: species.sunlightLabel)
                statCard(label: "Care level", value: species.careLevel ?? "—")
                statCard(label: "Growth", value: species.growthRate ?? "—")
                statCard(label: "Cycle", value: species.cycle ?? "—")
                statCard(
                    label: "Placement",
                    value: species.indoor == true ? "Indoor" : (species.indoor == false ? "Outdoor" : "—")
                )
            }
        }
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(theme.textTertiary)
            Text(value)
                .font(theme.subheadFont)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
    }

    private func aboutBlock(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ABOUT")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.textTertiary)
            Text(description)
                .font(theme.subheadFont)
                .foregroundStyle(theme.textPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
    }

    private func addToGardenButton(_ species: SpeciesCatalog) -> some View {
        Button {
            Task { await addToGarden(species) }
        } label: {
            if isAdding {
                ProgressView()
                    .tint(theme.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Text("Add to garden")
                    .font(theme.headlineFont)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.primary)
        .foregroundStyle(theme.onPrimary)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
        .disabled(isAdding || appState.effectiveUserId == nil)
    }

    private func attribution(_ license: String, url: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("IMAGE LICENSE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(theme.textTertiary)
            if let url, let link = URL(string: url) {
                Link(license, destination: link)
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.primary)
            } else {
                Text(license)
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loaded = try await catalog.details(for: speciesId)
            let localized = await SpeciesI18nService.localizeCatalog(loaded)
            species = localized
            await speciesCollections.recordViewed(localized)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addToGarden(_ species: SpeciesCatalog) async {
        guard let userId = appState.effectiveUserId else {
            errorMessage = String(localized: "Sign in or continue as guest to add plants.")
            return
        }
        isAdding = true
        defer { isAdding = false }
        do {
            let interval = 7
            let nextWater = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
            let placement: PlantPlacement = species.indoor == false ? .balcony : .indoor
            let newPlant = NewPlant(
                userId: userId,
                nickname: species.displayName,
                speciesCommonName: species.commonName ?? species.displayName,
                speciesLatinName: species.scientificName,
                family: species.family,
                photoUrl: nil,
                healthScore: 90,
                nextWateringDate: GardenStore.dateFormatter.string(from: nextWater),
                wateringIntervalDays: interval,
                wateringAmountMl: 250,
                placement: placement
            )
            let created = try await garden.addPlant(newPlant)
            coordinator.scanSpeciesSheetId = nil
            coordinator.goToPlantDetail(created.id, from: .catalog)
        } catch {
            errorMessage = String(localized: "Couldn't add this plant: \(error.localizedDescription)")
        }
    }
}
