import Foundation

@MainActor
final class SpeciesCollectionStore: ObservableObject {
    @Published private(set) var activities: [Int: SpeciesActivity] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var userId: UUID?
    private var isGuest = true

    var favorites: [SpeciesCatalog] {
        activities.values
            .filter(\.isFavorite)
            .map(\.species)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var recentlyViewed: [SpeciesCatalog] {
        activities.values
            .filter { $0.lastViewedAt != nil }
            .sorted {
                (Self.date(from: $0.lastViewedAt) ?? .distantPast) >
                    (Self.date(from: $1.lastViewedAt) ?? .distantPast)
            }
            .prefix(20)
            .map(\.species)
    }

    func isFavorite(_ speciesId: Int) -> Bool {
        activities[speciesId]?.isFavorite == true
    }

    func load(userId: UUID, isGuest: Bool) async {
        self.userId = userId
        self.isGuest = isGuest
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if isGuest {
            activities = Dictionary(
                uniqueKeysWithValues: LocalSpeciesCollectionStore.load().map { ($0.id, $0) }
            )
            return
        }

        do {
            let cloud = try await SpeciesCollectionService.fetch(userId: userId)
            let merged = await mergeGuestActivityIfNeeded(cloud: cloud, into: userId)
            activities = Dictionary(uniqueKeysWithValues: merged.map { ($0.id, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recordViewed(_ species: SpeciesCatalog) async {
        var activity = activities[species.id] ?? SpeciesActivity(
            species: species,
            isFavorite: false,
            lastViewedAt: nil
        )
        activity.species = species
        activity.lastViewedAt = ISO8601DateFormatter().string(from: Date())
        activities[species.id] = activity
        await persist(activity)
    }

    func toggleFavorite(_ species: SpeciesCatalog) async {
        var activity = activities[species.id] ?? SpeciesActivity(
            species: species,
            isFavorite: false,
            lastViewedAt: nil
        )
        activity.species = species
        activity.isFavorite.toggle()
        activities[species.id] = activity

        if isGuest && !activity.isFavorite && activity.lastViewedAt == nil {
            activities[species.id] = nil
            saveLocally()
        } else {
            await persistFavorite(activity)
        }
    }

    private func persist(_ activity: SpeciesActivity) async {
        if isGuest {
            saveLocally()
            errorMessage = nil
            return
        }
        guard let userId else { return }
        do {
            try await SpeciesCollectionService.save(activity, userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistFavorite(_ activity: SpeciesActivity) async {
        if isGuest {
            saveLocally()
            errorMessage = nil
            return
        }
        guard let userId else { return }
        do {
            try await SpeciesCollectionService.saveFavorite(
                speciesId: activity.id,
                isFavorite: activity.isFavorite,
                userId: userId
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveLocally() {
        LocalSpeciesCollectionStore.save(Array(activities.values))
    }

    private func mergeGuestActivityIfNeeded(
        cloud: [SpeciesActivity],
        into userId: UUID
    ) async -> [SpeciesActivity] {
        let local = LocalSpeciesCollectionStore.load()
        guard !local.isEmpty else { return cloud }

        var merged = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })
        var allSaved = true
        for localActivity in local {
            var activity = merged[localActivity.id] ?? localActivity
            activity.isFavorite = activity.isFavorite || localActivity.isFavorite
            activity.lastViewedAt = maxTimestamp(
                activity.lastViewedAt,
                localActivity.lastViewedAt
            )
            merged[activity.id] = activity
            do {
                try await SpeciesCollectionService.save(activity, userId: userId)
            } catch {
                allSaved = false
                errorMessage = error.localizedDescription
            }
        }
        if allSaved {
            LocalSpeciesCollectionStore.clear()
        }
        return Array(merged.values)
    }

    private func maxTimestamp(_ lhs: String?, _ rhs: String?) -> String? {
        switch (lhs, rhs) {
        case (nil, nil):
            return nil
        case (let value?, nil), (nil, let value?):
            return value
        case (let lhs?, let rhs?):
            guard let leftDate = Self.date(from: lhs),
                  let rightDate = Self.date(from: rhs) else {
                return lhs
            }
            return leftDate >= rightDate ? lhs : rhs
        }
    }

    private static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
