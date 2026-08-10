import SwiftUI

struct SpeciesCatalogView: View {
    @EnvironmentObject private var catalog: SpeciesCatalogStore
    @EnvironmentObject private var speciesCollections: SpeciesCollectionStore
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @State private var query = ""
    @State private var indoorOnly = true
    @State private var searchTask: Task<Void, Never>?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            ZStack(alignment: .bottomTrailing) {
                LeafWatermark(opacity: 0.07, rotation: 18, color: theme.primary)
                    .frame(width: 200, height: 260)
                    .offset(x: 40, y: 20)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 18) {
                    header
                    collectionSections

                    if catalog.isLoading && catalog.results.isEmpty {
                        ProgressView()
                            .tint(theme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let error = catalog.errorMessage, catalog.results.isEmpty {
                        errorState(error)
                    } else if catalog.results.isEmpty {
                        emptyState
                    } else {
                        resultsGrid
                        if catalog.canLoadMore || catalog.isLoadingMore {
                            loadMoreRow
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .journalPaperBackground(
            showMarginRail: true,
            marginNote: "Species index"
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            searchControls
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(theme.background)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.separator)
                        .frame(height: 1)
                }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { EmptyView() }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            if catalog.results.isEmpty {
                await catalog.search(query: "", indoorOnly: indoorOnly)
            }
        }
        .onChange(of: query) { _, newValue in
            scheduleSearch(newValue)
        }
    }

    private var collectionSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            if speciesCollections.isLoading {
                ProgressView("Loading your plant lists…")
                    .font(theme.footnoteFont)
                    .tint(theme.primary)
            } else {
                collectionSection(
                    title: "FAVORITES",
                    items: speciesCollections.favorites,
                    emptyMessage: "Tap a heart to keep a species here."
                )
                collectionSection(
                    title: "RECENTLY VIEWED",
                    items: speciesCollections.recentlyViewed,
                    emptyMessage: "Species you open will appear here."
                )
            }

            if let error = speciesCollections.errorMessage {
                Text(error)
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.error)
            }
        }
    }

    @ViewBuilder
    private func collectionSection(
        title: String,
        items: [SpeciesCatalog],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(theme.textTertiary)

            if items.isEmpty {
                Text(emptyMessage)
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(items) { species in
                            collectionCard(species)
                        }
                    }
                }
            }
        }
    }

    private func collectionCard(_ species: SpeciesCatalog) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                coordinator.goToSpeciesDetail(species.id)
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    CatalogPhoto(urlString: species.imageUrl)
                        .frame(width: 144, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
                    Text(species.displayName)
                        .font(theme.subheadFont.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                }
                .frame(width: 144, alignment: .leading)
            }
            .buttonStyle(.plain)

            favoriteButton(for: species)
                .padding(7)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SPECIES INDEX \u{2014} PERENUAL")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.secondary)
            Text("Discover")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(theme.primary)
            Text("Browse houseplants with photos. Results are cached so each species is fetched once.")
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                TextField("Search species…", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.textPrimary)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))

            Toggle(isOn: $indoorOnly) {
                Text("Indoor plants")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textSecondary)
            }
            .tint(theme.primary)
            .onChange(of: indoorOnly) { _, newValue in
                Task { await catalog.search(query: query, indoorOnly: newValue) }
            }
        }
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(catalog.results.enumerated()), id: \.element.id) { index, species in
                ZStack(alignment: .topTrailing) {
                    Button {
                        coordinator.goToSpeciesDetail(species.id)
                    } label: {
                        SpeciesCatalogTile(species: species, tall: index.isMultiple(of: 2))
                    }
                    .buttonStyle(.plain)

                    favoriteButton(for: species)
                        .padding(7)
                }
                .padding(.top, index.isMultiple(of: 2) ? 0 : 26)
            }
        }
    }

    private func favoriteButton(for species: SpeciesCatalog) -> some View {
        Button {
            Task { await speciesCollections.toggleFavorite(species) }
        } label: {
            Image(systemName: speciesCollections.isFavorite(species.id) ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 32, height: 32)
                .background(theme.surface.opacity(0.94))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            speciesCollections.isFavorite(species.id)
                ? "Remove \(species.displayName) from favorites"
                : "Add \(species.displayName) to favorites"
        )
    }

    private var loadMoreRow: some View {
        Button {
            Task { await catalog.loadMore() }
        } label: {
            if catalog.isLoadingMore {
                ProgressView().tint(theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                Text("Load more")
                    .font(theme.headlineFont)
                    .foregroundStyle(theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
        .disabled(catalog.isLoadingMore)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 36))
                .foregroundStyle(theme.primary.opacity(0.55))
            Text("No species matched")
                .font(theme.headlineFont)
                .foregroundStyle(theme.textPrimary)
            Text("Try another name, or turn off the indoor filter.")
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
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
            Button("Try again") {
                Task { await catalog.search(query: query, indoorOnly: indoorOnly) }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
    }

    private func scheduleSearch(_ value: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await catalog.search(query: value, indoorOnly: indoorOnly)
        }
    }
}

private struct SpeciesCatalogTile: View {
    let species: SpeciesCatalog
    var tall: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CatalogPhoto(urlString: species.imageUrl)
                .frame(height: tall ? 168 : 132)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.md)
                        .stroke(theme.separator, lineWidth: 1)
                )

            Text(species.displayName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)

            if let latin = species.scientificName, !latin.isEmpty {
                Text(latin)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Text(species.wateringLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
