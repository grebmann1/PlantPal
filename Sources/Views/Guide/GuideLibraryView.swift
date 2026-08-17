import SwiftUI

struct PlantGuide: Identifiable, Hashable {
    struct Section: Hashable {
        let title: String
        let body: String
        let tip: String?
    }

    enum Category: String, CaseIterable, Hashable {
        case all = "For you"
        case watering = "Watering"
        case light = "Light"
        case soil = "Soil"
        case pests = "Pests"
        case seasonal = "Seasonal"
        case saved = "Saved"
    }

    let id: String
    let title: String
    let summary: String
    let category: Category
    let readMinutes: Int
    let systemImage: String
    let sections: [Section]

    static let library: [PlantGuide] = [
        PlantGuide(
            id: "finger-test",
            title: "The finger test: when to water",
            summary: "A simple, reliable way to know when your plant actually needs a drink.",
            category: .watering,
            readMinutes: 4,
            systemImage: "hand.point.up.left.fill",
            sections: [
                Section(
                    title: "Check below the surface",
                    body: "Push a clean finger about 2–3 cm into the potting mix. The surface can look dry while the roots still have plenty of moisture.",
                    tip: "For small pots, check 1–2 cm deep. For large pots, check closer to 5 cm."
                ),
                Section(
                    title: "Read what you feel",
                    body: "Wait if the soil feels cool and clings to your finger. Water when it feels dry and loose at the depth your plant prefers.",
                    tip: nil
                ),
                Section(
                    title: "Water thoroughly",
                    body: "Pour slowly until water drains from the bottom, then empty the saucer. This encourages deeper roots and prevents salt buildup.",
                    tip: "Do not use a fixed calendar as your only signal—light, temperature, and pot size all change how quickly soil dries."
                )
            ]
        ),
        PlantGuide(
            id: "yellow-leaves",
            title: "Yellow leaves?",
            summary: "Spot the most likely cause and help your plant recover.",
            category: .watering,
            readMinutes: 5,
            systemImage: "leaf.fill",
            sections: [
                Section(
                    title: "Start with the pattern",
                    body: "One older lower leaf turning yellow is often normal. Several yellow leaves at once point to a change in water, light, temperature, or roots.",
                    tip: nil
                ),
                Section(
                    title: "Check the roots",
                    body: "Wet soil, a sour smell, or soft dark roots suggest overwatering. Dry soil that pulls from the pot edge suggests the root ball stayed dry too long.",
                    tip: "Change one care habit at a time so you can see what helps."
                )
            ]
        ),
        PlantGuide(
            id: "morning-light",
            title: "Morning light, explained",
            summary: "What it is and why many houseplants love it.",
            category: .light,
            readMinutes: 3,
            systemImage: "sun.horizon.fill",
            sections: [
                Section(
                    title: "Gentle direct sun",
                    body: "Morning rays are typically cooler and less intense than afternoon sun. They give plants useful energy with a lower risk of scorched leaves.",
                    tip: nil
                ),
                Section(
                    title: "Find the right window",
                    body: "An east-facing window usually provides morning light. Move sensitive leaves a little farther from the glass and watch for pale or crispy patches.",
                    tip: "Rotate the pot a quarter turn each week for even growth."
                )
            ]
        ),
        PlantGuide(
            id: "soil-basics",
            title: "Build a better potting mix",
            summary: "Balance moisture, airflow, and structure for healthier roots.",
            category: .soil,
            readMinutes: 6,
            systemImage: "square.3.layers.3d",
            sections: [
                Section(
                    title: "Think in three parts",
                    body: "A useful indoor mix combines a moisture-holding base, chunky material for airflow, and mineral particles that improve drainage.",
                    tip: "A common starting point is two parts potting mix, one part bark, and one part perlite."
                ),
                Section(
                    title: "Adjust for the plant",
                    body: "Add more mineral material for succulents and more moisture-retentive material for ferns. The correct mix should suit both the plant and your watering habits.",
                    tip: nil
                )
            ]
        ),
        PlantGuide(
            id: "pest-check",
            title: "A five-minute pest check",
            summary: "Catch common houseplant pests before they spread.",
            category: .pests,
            readMinutes: 5,
            systemImage: "ladybug.fill",
            sections: [
                Section(
                    title: "Know where to look",
                    body: "Inspect new growth, leaf joints, and the undersides of leaves. Look for webbing, sticky residue, pale stippling, or small moving dots.",
                    tip: "Quarantine every new plant for two weeks before placing it near your collection."
                ),
                Section(
                    title: "Respond early",
                    body: "Move the plant away from others, rinse the foliage, and identify the pest before choosing a treatment. Repeat inspections weekly.",
                    tip: nil
                )
            ]
        ),
        PlantGuide(
            id: "summer-heat",
            title: "Keep houseplants cool during heat waves",
            summary: "Protect roots and leaves when indoor temperatures climb.",
            category: .seasonal,
            readMinutes: 4,
            systemImage: "thermometer.sun.fill",
            sections: [
                Section(
                    title: "Reduce heat stress",
                    body: "Move plants back from hot glass, close sheer curtains at midday, and keep them away from air-conditioning vents.",
                    tip: nil
                ),
                Section(
                    title: "Check moisture more often",
                    body: "Warm rooms dry pots faster, but do not water automatically. Check the soil and water deeply only when the root zone needs it.",
                    tip: "Delay repotting and fertilizing until extreme heat has passed."
                )
            ]
        )
    ]

    static func guide(id: String) -> PlantGuide? {
        library.first { $0.id == id }
    }
}

struct GuideLibraryView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @State private var query = ""
    @State private var selectedCategory: PlantGuide.Category = .all
    @AppStorage("pp.bookmarkedGuideIDs") private var bookmarkedGuideIDs = ""

    private var filteredGuides: [PlantGuide] {
        PlantGuide.library.filter { guide in
            let matchesCategory: Bool
            if selectedCategory == .all {
                matchesCategory = true
            } else if selectedCategory == .saved {
                matchesCategory = isBookmarked(guide.id)
            } else {
                matchesCategory = guide.category == selectedCategory
            }
            let searchText = "\(guide.title) \(guide.summary) \(guide.category.rawValue)"
            return matchesCategory && (query.isEmpty || searchText.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.s5) {
                header
                searchField
                categoryPicker

                if query.isEmpty && selectedCategory == .all, let featured = PlantGuide.library.first {
                    featuredCard(featured)
                    quickNotes(excluding: featured)
                    seasonalGuide
                } else {
                    guideResults
                }
            }
            .padding(.horizontal, theme.spacing.s5)
            .padding(.top, theme.spacing.s2)
            .padding(.bottom, theme.spacing.s10)
        }
        .journalPaperBackground(showMarginRail: true, marginNote: "Plant knowledge")
        .accessibilityIdentifier("guide-library-screen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { EmptyView() }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        ZStack(alignment: .trailing) {
            LeafWatermark(opacity: 0.07, rotation: 20, color: theme.primary)
                .frame(width: 120, height: 130)
                .offset(x: 24)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: theme.spacing.s1) {
                Text("PLANT KNOWLEDGE · FIELD NOTES")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(theme.secondary)
                Text("Guide")
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(theme.primary)
                Text("Practical advice for happier plants.")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var searchField: some View {
        HStack(spacing: theme.spacing.s3) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
            TextField("Search guides and tips", text: $query)
                .font(theme.bodyFont)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .accessibilityLabel("Clear guide search")
            }
        }
        .padding(.horizontal, theme.spacing.s4)
        .padding(.vertical, theme.spacing.s3)
        .background(theme.surfaceSecondary.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.pill))
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.s2) {
                ForEach(PlantGuide.Category.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(selectedCategory == category ? theme.onPrimary : theme.textSecondary)
                            .padding(.horizontal, 15)
                            .frame(minHeight: 44)
                            .background(selectedCategory == category ? theme.primary : theme.surface.opacity(0.8))
                            .clipShape(Capsule())
                            .overlay {
                                if selectedCategory != category {
                                    Capsule().stroke(theme.secondary.opacity(0.45), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                }
            }
        }
    }

    private func featuredCard(_ guide: PlantGuide) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                open(guide)
            } label: {
                VStack(alignment: .leading, spacing: theme.spacing.s4) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: theme.spacing.s2) {
                            Text("\(guide.category.rawValue.uppercased()) 101")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(theme.primary)
                            Text(guide.title)
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundStyle(theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: theme.spacing.s3)
                        Image(systemName: guide.systemImage)
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(theme.accent)
                            .frame(width: 78, height: 78)
                            .background(theme.surfaceSecondary)
                            .clipShape(Circle())
                    }

                    Text(guide.summary)
                        .font(theme.subheadFont)
                        .foregroundStyle(theme.textSecondary)

                    Text("\(guide.readMinutes) MIN READ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(theme.primary)
                }
                .padding(theme.spacing.s5)
                .background(theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius.md)
                        .stroke(theme.separator, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("guide-\(guide.id)")
            .accessibilityHint("Opens the featured guide")

            bookmarkButton(for: guide)
                .padding(theme.spacing.s3)
        }
        .appElevation(theme.elevation.e2)
    }

    private func quickNotes(excluding featured: PlantGuide) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.s3) {
            sectionLabel("QUICK FIELD NOTES")
            HStack(alignment: .top, spacing: theme.spacing.s3) {
                ForEach(Array(PlantGuide.library.filter { $0.id != featured.id }.prefix(2))) { guide in
                    compactCard(guide)
                }
            }
        }
    }

    private func compactCard(_ guide: PlantGuide) -> some View {
        Button {
            open(guide)
        } label: {
            VStack(alignment: .leading, spacing: theme.spacing.s2) {
                Image(systemName: guide.systemImage)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(guide.category == .light ? theme.warning : theme.secondary)
                Text(guide.title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                Text(guide.summary)
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding(theme.spacing.s3)
            .background(theme.surface.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.md)
                    .stroke(theme.separator, lineWidth: 1)
            }
            .appElevation(theme.elevation.e1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("guide-\(guide.id)")
    }

    private var guideResults: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s3) {
            sectionLabel(filteredGuides.isEmpty ? "NO FIELD NOTES FOUND" : resultCountLabel)
            if filteredGuides.isEmpty {
                Text(selectedCategory == .saved
                    ? "Bookmarks you add while reading a guide will appear here."
                    : "Try another search or choose a different category.")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.vertical, theme.spacing.s6)
                if selectedCategory == .saved {
                    Button("Browse all guides") { selectedCategory = .all }
                        .buttonStyle(.bordered)
                        .tint(theme.primary)
                }
            } else {
                ForEach(filteredGuides) { guide in
                    guideRow(guide)
                }
            }
        }
    }

    private var seasonalGuide: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s3) {
            sectionLabel("SEASONAL · SUMMER")
            if let guide = PlantGuide.library.first(where: { $0.category == .seasonal }) {
                guideRow(guide)
            }
        }
    }

    private func guideRow(_ guide: PlantGuide) -> some View {
        Button {
            open(guide)
        } label: {
            HStack(spacing: theme.spacing.s3) {
                Image(systemName: guide.systemImage)
                    .font(.system(size: 23, weight: .light))
                    .foregroundStyle(theme.primary)
                    .frame(width: 42, height: 42)
                    .background(theme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))
                VStack(alignment: .leading, spacing: 3) {
                    Text(guide.title)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(theme.textPrimary)
                    Text("\(guide.category.rawValue) · \(guide.readMinutes) min read")
                        .font(theme.footnoteFont)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.primary)
            }
            .padding(theme.spacing.s3)
            .background(theme.surface.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.md)
                    .stroke(theme.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(theme.primary)
    }

    private func bookmarkButton(for guide: PlantGuide) -> some View {
        Button {
            toggleBookmark(guide.id)
        } label: {
            Image(systemName: isBookmarked(guide.id) ? "bookmark.fill" : "bookmark")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isBookmarked(guide.id) ? "Remove bookmark" : "Bookmark guide")
    }

    private func open(_ guide: PlantGuide) {
        coordinator.goToGuideArticle(guide.id)
    }

    private var resultCountLabel: String {
        "\(filteredGuides.count) FIELD \(filteredGuides.count == 1 ? "NOTE" : "NOTES")"
    }

    private func isBookmarked(_ id: String) -> Bool {
        Set(bookmarkedGuideIDs.split(separator: ",").map(String.init)).contains(id)
    }

    private func toggleBookmark(_ id: String) {
        var ids = Set(bookmarkedGuideIDs.split(separator: ",").map(String.init))
        if !ids.insert(id).inserted {
            ids.remove(id)
        }
        bookmarkedGuideIDs = ids.sorted().joined(separator: ",")
    }
}

struct GuideArticleView: View {
    let guide: PlantGuide

    @Environment(\.appTheme) private var theme
    @AppStorage("pp.bookmarkedGuideIDs") private var bookmarkedGuideIDs = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.s6) {
                articleHeader

                ForEach(Array(guide.sections.enumerated()), id: \.offset) { index, section in
                    articleSection(section, number: index + 1)
                }
            }
            .padding(.horizontal, theme.spacing.s5)
            .padding(.top, theme.spacing.s3)
            .padding(.bottom, theme.spacing.s12)
        }
        .journalPaperBackground(showMarginRail: true)
        .accessibilityIdentifier("guide-article-screen")
        .navigationTitle("Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    toggleBookmark()
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark guide")
            }
        }
    }

    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s3) {
            HStack {
                SpecimenLabel(text: guide.category.rawValue, tint: theme.primary)
                Spacer()
                Text("\(guide.readMinutes) MIN READ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.textTertiary)
            }

            Image(systemName: guide.systemImage)
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(theme.surfaceSecondary.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))

            Text(guide.title)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(theme.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(guide.summary)
                .font(theme.bodyFont)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func articleSection(_ section: PlantGuide.Section, number: Int) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.s3) {
            Text("NOTE \(String(format: "%02d", number))")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.secondary)
            Text(section.title)
                .font(.system(size: 23, weight: .bold, design: .serif))
                .foregroundStyle(theme.textPrimary)
            Text(section.body)
                .font(theme.bodyFont)
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(5)

            if let tip = section.tip {
                HStack(alignment: .top, spacing: theme.spacing.s3) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(theme.accent)
                    Text(tip)
                        .font(theme.subheadFont)
                        .foregroundStyle(theme.textPrimary)
                }
                .padding(theme.spacing.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surfaceSecondary.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
            }
        }
        .padding(.top, theme.spacing.s2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.separator)
                .frame(height: 1)
        }
    }

    private var isBookmarked: Bool {
        Set(bookmarkedGuideIDs.split(separator: ",").map(String.init)).contains(guide.id)
    }

    private func toggleBookmark() {
        var ids = Set(bookmarkedGuideIDs.split(separator: ",").map(String.init))
        if !ids.insert(guide.id).inserted {
            ids.remove(guide.id)
        }
        bookmarkedGuideIDs = ids.sorted().joined(separator: ",")
    }
}
