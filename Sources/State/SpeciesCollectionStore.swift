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
            LocalSpeciesCollectionStore.migrateLegacyDataIfNeeded(to: userId)
            activities = Dictionary(
                uniqueKeysWithValues: LocalSpeciesCollectionStore.load(userId: userId).map { ($0.id, $0) }
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
        let previous = activities[species.id]
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
            let didPersist = await persistFavorite(activity)
            if !didPersist {
                activities[species.id] = previous
            }
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

    private func persistFavorite(_ activity: SpeciesActivity) async -> Bool {
        if isGuest {
            saveLocally()
            errorMessage = nil
            return true
        }
        guard let userId else { return false }
        do {
            try await SpeciesCollectionService.saveFavorite(
                speciesId: activity.id,
                isFavorite: activity.isFavorite,
                userId: userId
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func saveLocally() {
        LocalSpeciesCollectionStore.save(Array(activities.values), userId: userId)
    }

    func importGuestActivities(from guestUserId: UUID, to userId: UUID) async throws {
        let guestActivities = LocalSpeciesCollectionStore.load(userId: guestUserId)
        let cloudActivities = try await SpeciesCollectionService.fetchAll(userId: userId)
        let merged = Self.mergeGuestActivities(cloud: cloudActivities, guest: guestActivities)
        let cloudById = Dictionary(uniqueKeysWithValues: cloudActivities.map { ($0.id, $0) })

        for activity in merged where cloudById[activity.id] != activity {
            try await SpeciesCollectionService.save(activity, userId: userId)
        }
        activities = Dictionary(uniqueKeysWithValues: merged.map { ($0.id, $0) })
    }

    private func mergeGuestActivityIfNeeded(
        cloud: [SpeciesActivity],
        into userId: UUID
    ) async -> [SpeciesActivity] {
        let local = LocalSpeciesCollectionStore.load(userId: userId)
        guard !local.isEmpty else { return cloud }

        var merged = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })
        var allSaved = true
        for localActivity in local {
            let activity = Self.mergeActivity(
                cloud: merged[localActivity.id],
                guest: localActivity
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
            LocalSpeciesCollectionStore.clear(userId: userId)
        }
        return Array(merged.values)
    }

    static func mergeGuestActivities(cloud: [SpeciesActivity], guest: [SpeciesActivity]) -> [SpeciesActivity] {
        var merged = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })
        for guestActivity in guest {
            let activity = mergeActivity(cloud: merged[guestActivity.id], guest: guestActivity)
            merged[activity.id] = activity
        }
        return Array(merged.values)
    }

    private static func mergeActivity(cloud: SpeciesActivity?, guest: SpeciesActivity) -> SpeciesActivity {
        guard var cloud else { return guest }
        cloud.isFavorite = cloud.isFavorite || guest.isFavorite
        cloud.lastViewedAt = maxTimestamp(cloud.lastViewedAt, guest.lastViewedAt)
        return cloud
    }

    private static func maxTimestamp(_ lhs: String?, _ rhs: String?) -> String? {
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
