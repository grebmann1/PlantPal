import Foundation

struct PlantQuote: Codable, Identifiable, Hashable {
    var quote: String
    var author: String
    var source: String
    var sourceUrl: String

    var id: String { "\(author)|\(quote)" }

    enum CodingKeys: String, CodingKey {
        case quote, author, source
        case sourceUrl = "source_url"
    }
}

struct PlantQuoteRotation {
    private(set) var step: Int
    private(set) var generalIndex: Int
    private(set) var specificIndex: Int

    init(step: Int = 0, generalIndex: Int, specificIndex: Int) {
        self.step = step % 3
        self.generalIndex = generalIndex
        self.specificIndex = specificIndex
    }

    var showsSpecificPlant: Bool { step != 2 }

    func current(general: [PlantQuote], specific: [PlantQuote]) -> PlantQuote {
        showsSpecificPlant ? specific[specificIndex] : general[generalIndex]
    }

    mutating func advance(general: [PlantQuote], specific: [PlantQuote]) {
        step = (step + 1) % 3
        if showsSpecificPlant {
            specificIndex = nextDistinctAuthorIndex(in: specific, after: specificIndex)
        } else {
            generalIndex = (generalIndex + 1) % general.count
        }
    }

    private func nextDistinctAuthorIndex(in quotes: [PlantQuote], after index: Int) -> Int {
        var candidate = (index + 1) % quotes.count
        while candidate != index, quotes[candidate].author == quotes[index].author {
            candidate = (candidate + 1) % quotes.count
        }
        return candidate
    }
}

enum PlantQuoteLibrary {
    static let all = load(resource: "PlantQuotes", fallback: [
        PlantQuote(
            quote: "Leaves are so many workshops, full of machinery worked by sun-power.",
            author: "Asa Gray",
            source: "The Elements of Botany",
            sourceUrl: "https://www.gutenberg.org/files/33757/33757-h/33757-h.htm"
        )
    ])

    static let specificPlants = load(resource: "SpecificPlantQuotes", fallback: all)

    private static func load(resource: String, fallback: [PlantQuote]) -> [PlantQuote] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let quotes = try? JSONDecoder().decode([PlantQuote].self, from: data),
              !quotes.isEmpty else {
            return fallback
        }
        return quotes
    }
}
