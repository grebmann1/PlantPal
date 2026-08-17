import Foundation

@MainActor
final class SpeciesCatalogStore: ObservableObject {
    @Published private(set) var results: [SpeciesCatalog] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var page = 1
    @Published private(set) var lastPage = 1
    @Published private(set) var total = 0
    @Published private(set) var lastQuery = ""
    @Published private(set) var indoorOnly = true

    private var detailsCache: [Int: SpeciesCatalog] = [:]
    private var lookupCache: [String: SpeciesCatalog] = [:]
    private var searchGeneration = 0

    var canLoadMore: Bool { page < lastPage && !isLoading && !isLoadingMore }

    func search(query: String, indoorOnly: Bool = true) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchGeneration += 1
        let generation = searchGeneration
        isLoading = true
        errorMessage = nil
        lastQuery = trimmed
        self.indoorOnly = indoorOnly
        page = 1
        defer { isLoading = false }

        do {
            let response = try await SpeciesCatalogService.search(
                query: trimmed,
                page: 1,
                indoor: indoorOnly
            )
            guard generation == searchGeneration else { return }
            results = response.data
            lastPage = response.lastPage ?? 1
            total = response.total ?? response.data.count
            cache(response.data)
        } catch {
            guard generation == searchGeneration else { return }
            results = []
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let next = page + 1
        let generation = searchGeneration
        do {
            let response = try await SpeciesCatalogService.search(
                query: lastQuery,
                page: next,
                indoor: indoorOnly
            )
            guard generation == searchGeneration else { return }
            page = next
            lastPage = response.lastPage ?? lastPage
            total = response.total ?? total
            let existing = Set(results.map(\.id))
            let appended = response.data.filter { !existing.contains($0.id) }
            results.append(contentsOf: appended)
            cache(appended)
        } catch {
            guard generation == searchGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    func details(for id: Int) async throws -> SpeciesCatalog {
        if let cached = detailsCache[id],
           cached.detailsFetched,
           cached.hasUsableDetails {
            return cached
        }
        let species = try await SpeciesCatalogService.details(id: id)
        detailsCache[id] = species
        if let latin = species.scientificName?.lowercased() {
            lookupCache[latin] = species
        }
        if let index = results.firstIndex(where: { $0.id == id }) {
            results[index] = species
        }
        return species
    }

    /// Used after AI identification to attach a catalog photo + care fields.
    func lookup(scientificName: String) async -> SpeciesCatalog? {
        let key = scientificName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        if let cached = lookupCache[key],
           cached.detailsFetched,
           cached.hasUsableDetails {
            return cached
        }
        do {
            guard let species = try await SpeciesCatalogService.lookup(scientificName: scientificName) else {
                return nil
            }
            detailsCache[species.id] = species
            lookupCache[key] = species
            return species
        } catch {
            return nil
        }
    }

    private func cache(_ items: [SpeciesCatalog]) {
        for item in items {
            detailsCache[item.id] = item
            if let latin = item.scientificName?.lowercased() {
                lookupCache[latin] = item
            }
        }
    }
}
