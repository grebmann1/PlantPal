import XCTest
@testable import PlantPal

final class FeatureStateTests: XCTestCase {
    override func tearDown() {
        LocalSpeciesCollectionStore.clear()
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
    func testGuestFavoriteAndRecentPersistAcrossStoreReload() async throws {
        LocalSpeciesCollectionStore.clear()
        let species = try makeSpecies(id: 42, name: "Monstera")
        let userId = UUID()
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
    func testRecentOrderingHandlesMixedISO8601Formats() async throws {
        let older = try makeSpecies(id: 1, name: "Older")
        let newer = try makeSpecies(id: 2, name: "Newer")
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
        ])

        let store = SpeciesCollectionStore()
        await store.load(userId: UUID(), isGuest: true)

        XCTAssertEqual(store.recentlyViewed.map(\.id), [newer.id, older.id])
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
