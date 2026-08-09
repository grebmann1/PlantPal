import SwiftUI
import MapKit

/// Searchable city/home picker. Stores a human label like "Lyon, FR".
struct HomeLocationPicker: View {
    @Binding var selection: String
    var onDone: () -> Void

    @Environment(\.appTheme) private var theme
    @StateObject private var search = CitySearchModel()
    @State private var query = ""

    private let popular: [(city: String, country: String, code: String)] = [
        ("Paris", "France", "FR"),
        ("Lyon", "France", "FR"),
        ("Marseille", "France", "FR"),
        ("Bordeaux", "France", "FR"),
        ("Berlin", "Germany", "DE"),
        ("Munich", "Germany", "DE"),
        ("Hamburg", "Germany", "DE"),
        ("Cologne", "Germany", "DE"),
        ("Lisbon", "Portugal", "PT"),
        ("London", "United Kingdom", "UK"),
        ("Madrid", "Spain", "ES"),
        ("Rome", "Italy", "IT"),
        ("Amsterdam", "Netherlands", "NL"),
        ("Brussels", "Belgium", "BE"),
        ("Zurich", "Switzerland", "CH"),
        ("Vienna", "Austria", "AT"),
        ("New York", "United States", "US"),
        ("Tokyo", "Japan", "JP")
    ]

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        ForEach(popular, id: \.city) { item in
                            locationButton(label: "\(item.city), \(item.code)", detail: item.country)
                        }
                    } header: {
                        Text("Popular places")
                    }
                } else {
                    Section {
                        if search.isSearching && search.results.isEmpty {
                            HStack {
                                ProgressView()
                                Text("Searching…")
                                    .foregroundStyle(theme.textSecondary)
                            }
                        } else if search.results.isEmpty {
                            Text("No places found")
                                .foregroundStyle(theme.textSecondary)
                        } else {
                            ForEach(search.results) { result in
                                locationButton(label: result.label, detail: result.detail)
                            }
                        }
                    } header: {
                        Text("Search results")
                    }
                }
            }
            .searchable(text: $query, prompt: "City or town")
            .onChange(of: query) { _, newValue in
                search.update(query: newValue)
            }
            .navigationTitle("Home location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDone)
                }
            }
        }
    }

    private func locationButton(label: String, detail: String?) -> some View {
        Button {
            selection = label
            onDone()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .foregroundStyle(theme.textPrimary)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                Spacer()
                if selection == label {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.primary)
                }
            }
        }
    }
}

// MARK: - MapKit search

@MainActor
final class CitySearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    struct Result: Identifiable, Hashable {
        var id: String { label + "|" + (detail ?? "") }
        var label: String
        var detail: String?
    }

    @Published var results: [Result] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()
    private var debounceTask: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            completer.queryFragment = ""
            return
        }
        isSearching = true
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            completer.queryFragment = trimmed
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = completer.results.compactMap { completion -> Result? in
            let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            // Prefer locality-looking rows (city / town).
            let label = Self.compactLabel(title: title, subtitle: subtitle)
            return Result(label: label, detail: subtitle.isEmpty ? nil : subtitle)
        }
        // Deduplicate while keeping order.
        var seen = Set<String>()
        let unique = mapped.filter { seen.insert($0.label).inserted }
        Task { @MainActor in
            self.results = Array(unique.prefix(20))
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
            self.results = []
        }
    }

    /// Builds "City, CC" when a country code can be inferred from the subtitle.
    private nonisolated static func compactLabel(title: String, subtitle: String) -> String {
        let parts = subtitle.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        if let country = parts.last {
            let code = countryCode(for: country) ?? country
            // If title already looks like "City, Region", take the city token.
            let city = title.split(separator: ",").first.map(String.init) ?? title
            return "\(city), \(code)"
        }
        return title
    }

    private nonisolated static func countryCode(for name: String) -> String? {
        let lowered = name.lowercased()
        let map: [String: String] = [
            "france": "FR", "germany": "DE", "deutschland": "DE",
            "portugal": "PT", "united kingdom": "UK", "uk": "UK", "england": "UK",
            "spain": "ES", "italy": "IT", "netherlands": "NL", "belgium": "BE",
            "switzerland": "CH", "austria": "AT", "united states": "US", "usa": "US",
            "japan": "JP", "canada": "CA", "ireland": "IE", "luxembourg": "LU"
        ]
        if let direct = map[lowered] { return direct }
        // Already a 2-letter code
        if name.count == 2, name.uppercased() == name { return name }
        return Locale.Region.isoRegions
            .compactMap { region -> String? in
                let id = region.identifier
                guard let localized = Locale.current.localizedString(forRegionCode: id) else { return nil }
                return localized.caseInsensitiveCompare(name) == .orderedSame ? id : nil
            }
            .first
    }
}
