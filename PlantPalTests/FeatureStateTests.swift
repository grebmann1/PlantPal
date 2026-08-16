import XCTest
@testable import PlantPal

final class FeatureStateTests: XCTestCase {
    private var localUserIds: Set<UUID> = []

    override func tearDown() {
        LocalSpeciesCollectionStore.clear()
        GuestImportStore.clear()
        for userId in localUserIds {
            LocalGardenStore.clearAll(userId: userId)
            LocalSpeciesCollectionStore.clear(userId: userId)
        }
        localUserIds.removeAll()
        super.tearDown()
    }

    func testCaptureContextPreservesEverySelectedPhoto() {
        let images = [Data([1]), Data([2]), Data([3])]
        let context = CaptureContext(images: images)

        XCTAssertEqual(context.images, images)
        XCTAssertEqual(context.imageData, images[0])
    }

    func testPlantQuoteLibraryContainsOneHundredSourcedQuotes() {
        let quotes = PlantQuoteLibrary.all

        XCTAssertEqual(quotes.count, 100)
        XCTAssertEqual(Set(quotes.map(\.id)).count, 100)
        XCTAssertTrue(quotes.allSatisfy {
            !$0.quote.isEmpty
                && !$0.author.isEmpty
                && !$0.source.isEmpty
                && URL(string: $0.sourceUrl)?.scheme == "https"
        })
    }

    func testSpecificPlantQuoteLibraryContainsTwentyUniqueQuotes() {
        let quotes = PlantQuoteLibrary.specificPlants

        XCTAssertEqual(quotes.count, 20)
        XCTAssertEqual(Set(quotes.map(\.id)).count, 20)
        XCTAssertTrue(Set(quotes.map(\.id)).isDisjoint(with: Set(PlantQuoteLibrary.all.map(\.id))))
        XCTAssertTrue(quotes.allSatisfy {
            !$0.quote.isEmpty
                && !$0.author.isEmpty
                && !$0.source.isEmpty
                && URL(string: $0.sourceUrl)?.scheme == "https"
        })
    }

    func testPlantGuideLibraryHasUniqueCompleteEntries() {
        let guides = PlantGuide.library

        XCTAssertFalse(guides.isEmpty)
        XCTAssertEqual(Set(guides.map(\.id)).count, guides.count)
        XCTAssertTrue(guides.allSatisfy {
            !$0.title.isEmpty
                && !$0.summary.isEmpty
                && $0.readMinutes > 0
                && !$0.sections.isEmpty
        })
        XCTAssertTrue(guides.allSatisfy { PlantGuide.guide(id: $0.id) == $0 })
    }

    func testQuoteRotationUsesTwoSpecificQuotesThenOneGeneralQuote() {
        let general = PlantQuoteLibrary.all
        let specific = PlantQuoteLibrary.specificPlants
        var rotation = PlantQuoteRotation(generalIndex: 0, specificIndex: 10)

        let first = rotation.current(general: general, specific: specific)
        rotation.advance(general: general, specific: specific)
        let second = rotation.current(general: general, specific: specific)
        rotation.advance(general: general, specific: specific)
        let third = rotation.current(general: general, specific: specific)
        rotation.advance(general: general, specific: specific)
        let fourth = rotation.current(general: general, specific: specific)

        XCTAssertTrue(specific.contains(first))
        XCTAssertTrue(specific.contains(second))
        XCTAssertNotEqual(first.author, second.author)
        XCTAssertTrue(general.contains(third))
        XCTAssertTrue(specific.contains(fourth))
    }

    @MainActor
    func testFirstCaptureCreatesPreparationBeforeResultRoute() throws {
        let coordinator = Coordinator()
        let context = CaptureContext(images: [Data([1]), Data([2])])

        coordinator.pushPreparation(context, mode: .identify)

        XCTAssertEqual(coordinator.scanPath.count, 1)
        XCTAssertEqual(coordinator.scanCaptures.count, 1)
        let captureId = try XCTUnwrap(coordinator.scanCaptures.keys.first)
        XCTAssertEqual(coordinator.capture(for: captureId), context)

        coordinator.startIdentification(for: captureId, context: context)
        XCTAssertEqual(coordinator.scanPath.count, 2)
    }

    @MainActor
    func testNewScanSessionConsumesPresetAndResetsToGenericState() {
        let coordinator = Coordinator()
        let plantId = UUID()

        coordinator.goToScan(mode: .health, plantId: plantId)
        XCTAssertEqual(coordinator.consumeScanPresetIntent(), ScanIntent(mode: .health, plantId: plantId))
        XCTAssertNil(coordinator.consumeScanPresetIntent())

        coordinator.pushPreparation(CaptureContext(imageData: Data([1]), plantId: plantId), mode: .health)
        let previousSession = coordinator.scanSessionID
        coordinator.completeScanSession()

        XCTAssertTrue(coordinator.scanPath.isEmpty)
        XCTAssertTrue(coordinator.scanCaptures.isEmpty)
        XCTAssertNil(coordinator.scanPresetIntent)
        XCTAssertNotEqual(coordinator.scanSessionID, previousSession)
    }

    @MainActor
    func testGuestFavoriteAndRecentPersistAcrossStoreReload() async throws {
        let species = try makeSpecies(id: 42, name: "Monstera")
        let userId = UUID()
        localUserIds.insert(userId)
        let store = SpeciesCollectionStore()
        await store.load(userId: userId, isGuest: true)

        await store.toggleFavorite(species)
        await store.recordViewed(species)

        let reloaded = SpeciesCollectionStore()
        await reloaded.load(userId: userId, isGuest: true)
        XCTAssertTrue(reloaded.isFavorite(species.id))
        XCTAssertEqual(reloaded.recentlyViewed.map(\.id), [species.id])
    }

    @MainActor
    func testGuestSpeciesActivityIsScopedToItsGuestIdentity() async throws {
        let species = try makeSpecies(id: 81, name: "Prayer Plant")
        let firstGuest = UUID()
        let secondGuest = UUID()
        localUserIds.formUnion([firstGuest, secondGuest])

        let firstStore = SpeciesCollectionStore()
        await firstStore.load(userId: firstGuest, isGuest: true)
        await firstStore.toggleFavorite(species)

        let secondStore = SpeciesCollectionStore()
        await secondStore.load(userId: secondGuest, isGuest: true)

        XCTAssertTrue(firstStore.isFavorite(species.id))
        XCTAssertFalse(secondStore.isFavorite(species.id))
        XCTAssertTrue(secondStore.favorites.isEmpty)
    }

    @MainActor
    func testRecentOrderingHandlesMixedISO8601Formats() async throws {
        let older = try makeSpecies(id: 1, name: "Older")
        let newer = try makeSpecies(id: 2, name: "Newer")
        let userId = UUID()
        localUserIds.insert(userId)
        LocalSpeciesCollectionStore.save([
            SpeciesActivity(
                species: older,
                isFavorite: false,
                lastViewedAt: "2026-08-10T10:00:00.123456+00:00"
            ),
            SpeciesActivity(
                species: newer,
                isFavorite: false,
                lastViewedAt: "2026-08-10T11:00:00Z"
            )
        ], userId: userId)

        let store = SpeciesCollectionStore()
        await store.load(userId: userId, isGuest: true)

        XCTAssertEqual(store.recentlyViewed.map(\.id), [newer.id, older.id])
    }

    @MainActor
    func testCompletingGuestWateringReminderSchedulesExactlyOneNextReminder() async throws {
        let userId = UUID()
        localUserIds.insert(userId)
        let store = GardenStore()
        await store.loadAll(userId: userId, isGuest: true)
        let plant = try await store.addPlant(
            NewPlant(
                userId: userId,
                nickname: "Test fern",
                speciesCommonName: "Boston fern",
                wateringIntervalDays: 5,
                wateringAmountMl: 250
            )
        )
        let due = Date().addingTimeInterval(-3600)
        let reminder = try await store.ensureWateringReminder(userId: userId, plant: plant, due: due)

        try await store.completeReminder(reminder)

        let activeWatering = store.reminders.filter {
            $0.plantId == plant.id && $0.type == "watering" && !$0.isCompleted
        }
        XCTAssertEqual(activeWatering.count, 1)
        XCTAssertTrue(store.reminders.contains { $0.id == reminder.id && $0.isCompleted })
        XCTAssertNotEqual(activeWatering[0].dueAt, reminder.dueAt)
        XCTAssertEqual(store.plants.first(where: { $0.id == plant.id })?.nextWateringDate,
                       GardenStore.dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()))
    }

    @MainActor
    func testGuestPlantKeepsItsIdentityWhenAddedToTheStore() async throws {
        let userId = UUID()
        let plantId = UUID()
        localUserIds.insert(userId)
        let store = GardenStore()
        await store.loadAll(userId: userId, isGuest: true)

        let created = try await store.addPlant(
            NewPlant(
                id: plantId,
                userId: userId,
                nickname: "Imported pothos",
                speciesCommonName: "Golden pothos"
            )
        )

        XCTAssertEqual(created.id, plantId)
        XCTAssertEqual(store.plants.filter { $0.id == plantId }.count, 1)
    }

    func testPendingGuestImportSurvivesReloadForTheSigningInAccount() {
        let pending = GuestImport(guestUserId: UUID(), userId: UUID())

        GuestImportStore.save(pending)

        XCTAssertEqual(GuestImportStore.load(), pending)
        XCTAssertEqual(GuestImportStore.load(for: pending.userId), pending)
        XCTAssertNil(GuestImportStore.load(for: UUID()))
    }

    @MainActor
    func testGuestActivityImportMergesInsteadOfOverwritingAccountActivity() throws {
        let species = try makeSpecies(id: 19, name: "Rubber Plant")
        let account = SpeciesActivity(
            species: species,
            isFavorite: true,
            lastViewedAt: "2026-08-16T11:00:00Z"
        )
        let guest = SpeciesActivity(
            species: species,
            isFavorite: false,
            lastViewedAt: "2026-08-15T11:00:00Z"
        )

        let merged = SpeciesCollectionStore.mergeGuestActivities(cloud: [account], guest: [guest])

        XCTAssertEqual(merged, [account])
    }

    private func makeSpecies(id: Int, name: String) throws -> SpeciesCatalog {
        let json = """
        {
          "id": \(id),
          "common_name": "\(name)",
          "other_names": [],
          "sunlight": [],
          "image_urls": [],
          "details_fetched": true
        }
        """
        return try JSONDecoder().decode(SpeciesCatalog.self, from: Data(json.utf8))
    }
}
