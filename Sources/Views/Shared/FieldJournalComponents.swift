import SwiftUI

// MARK: - Field Journal signature components
// Shared botanical/specimen-journal visual motifs used across screens.

/// Small "specimen label" chip — e.g. "No. 042", "Specimen 041".
struct SpecimenLabel: View {
    var text: String
    var tint: Color = .white
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(tint.opacity(0.6), lineWidth: 1)
            )
    }
}

/// Translucent leaf silhouette bleeding off an edge — decorative watermark.
struct LeafWatermark: View {
    var opacity: Double = 0.08
    var rotation: Double = -18
    var color: Color = .primary
    var body: some View {
        Image(systemName: "leaf.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(color.opacity(opacity))
            .rotationEffect(.degrees(rotation))
    }
}

/// Row of filled "pips" (dots) representing severity/vigor out of a max count.
struct PipsRow: View {
    var filled: Int
    var total: Int = 5
    var color: Color = .green
    var size: CGFloat = 7
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < filled ? color : color.opacity(0.18))
                    .frame(width: size, height: size)
            }
        }
    }
}

/// A torn-paper style horizontal divider, used to transition from a hero photo into content.
struct TornEdgeShape: Shape {
    var notches: Int = 18
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = rect.width / CGFloat(notches)
        path.move(to: CGPoint(x: 0, y: rect.height))
        for i in 0...notches {
            let x = CGFloat(i) * step
            let y: CGFloat = i.isMultiple(of: 2) ? 0 : rect.height * 0.55
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct TornEdge: View {
    var fill: Color
    var height: CGFloat = 14
    var body: some View {
        TornEdgeShape()
            .fill(fill)
            .frame(height: height)
    }
}

/// Wraps a photo with a "taped specimen" mount look — small tape strip + border.
struct TapeMountPhoto<Content: View>: View {
    var content: Content
    var cornerRadius: CGFloat = 6
    init(cornerRadius: CGFloat = 6, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    var body: some View {
        ZStack(alignment: .top) {
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.9), lineWidth: 4)
                )
                .rotationEffect(.degrees(-1.2))
                .appElevation(.init(color: .black.opacity(0.18), radius: 6, x: 0, y: 3))

            Rectangle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 46, height: 16)
                .rotationEffect(.degrees(-4))
                .offset(y: -8)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
        }
    }
}

/// Page-dot rail for onboarding-style step indicators.
struct PageDotRail: View {
    var count: Int
    var color: Color
    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(color.opacity(i == 0 ? 1 : 0.3))
                    .frame(width: i == 0 ? 8 : 6, height: i == 0 ? 8 : 6)
                if i < count - 1 {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(width: 1, height: 18)
                }
            }
        }
    }
}

/// Oversized outlined glyph tile used on Care Guide.
struct OutlinedGlyphTile: View {
    var systemImage: String
    var title: String
    var value: String
    var tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .thin))
                .foregroundStyle(tint)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(tint.opacity(0.8))
            Text(value)
                .font(.system(size: 14, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

/// Segmented day-cycle progress bar for watering ledger (e.g. 6 of 9 days).
struct SegmentedProgressBar: View {
    var filled: Int
    var total: Int
    var fillColor: Color
    var accentIndex: Int? = nil
    var accentColor: Color = .orange
    var emptyColor: Color = Color.primary.opacity(0.12)

    var body: some View {
        let safeTotal = max(total, 1)
        HStack(spacing: 3) {
            ForEach(0..<safeTotal, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(segmentColor(at: i))
                    .frame(height: 8)
            }
        }
    }

    private func segmentColor(at index: Int) -> Color {
        if let accentIndex, index == accentIndex {
            return accentColor
        }
        if index < filled {
            return fillColor
        }
        return emptyColor
    }
}

/// Stacked care-guide section with tinted background, icon, and caps label.
struct CareSectionCard<Content: View>: View {
    var icon: String
    var title: String
    var tint: Color
    var background: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(tint)
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(tint)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// Full-bleed care panel: glyph left, value right (matches care_guide HTML `.panel`).
struct CarePanel<Extra: View>: View {
    var icon: String
    var title: String
    var value: String
    var subtitle: String?
    var note: String?
    var tint: Color
    var background: Color
    @ViewBuilder var extra: () -> Extra

    init(
        icon: String,
        title: String,
        value: String,
        subtitle: String? = nil,
        note: String? = nil,
        tint: Color,
        background: Color,
        @ViewBuilder extra: @escaping () -> Extra
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.note = note
        self.tint = tint
        self.background = background
        self.extra = extra
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .ultraLight))
                    .foregroundStyle(tint)
                    .frame(width: 40, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(tint)
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(tint)
                        .multilineTextAlignment(.trailing)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.primary.opacity(0.55))
                            .multilineTextAlignment(.trailing)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            extra()

            if let note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .padding(.top, 4)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundStyle(Color.primary.opacity(0.18))
                            .frame(height: 1)
                    }
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
    }
}

extension CarePanel where Extra == EmptyView {
    init(
        icon: String,
        title: String,
        value: String,
        subtitle: String? = nil,
        note: String? = nil,
        tint: Color,
        background: Color
    ) {
        self.init(
            icon: icon,
            title: title,
            value: value,
            subtitle: subtitle,
            note: note,
            tint: tint,
            background: background,
            extra: { EmptyView() }
        )
    }
}

/// Ledger-style row used inside care panels and plant facts.
struct CareLedgerRow: View {
    var label: String
    var value: String
    var dotColor: Color?

    var body: some View {
        HStack(spacing: 8) {
            if let dotColor {
                Circle().fill(dotColor).frame(width: 6, height: 6)
            }
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Color.primary.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.75))
        }
        .padding(.vertical, 6)
    }
}

/// Ruled field-journal paper: cream sheet + hairline rules (matches design HTML body background).
struct JournalPaperBackground: View {
    @Environment(\.appTheme) private var theme
    /// Thin terracotta rule near the left edge — no gutter label or content inset.
    var showMarginRail: Bool = true
    var lineSpacing: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                theme.background

                // Horizontal notebook rules — transparent 0…27, hairline at 27…28
                Canvas { context, size in
                    let lineColor = theme.separator.opacity(0.45)
                    var y: CGFloat = lineSpacing - 1
                    while y < size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(lineColor), lineWidth: 1)
                        y += lineSpacing
                    }
                }

                if showMarginRail {
                    // Soft terracotta margin rule (HTML: error @ 45% × 0.5 opacity ≈ 22%)
                    Rectangle()
                        .fill(theme.error.opacity(0.22))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.leading, 12)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Cream ruled paper behind content. Optional thin left margin rule only — no vertical gutter label.
    func journalPaperBackground(
        showMarginRail: Bool = true,
        marginNote: String? = nil
    ) -> some View {
        // `marginNote` kept for call-site compatibility; vertical gutter copy was removed.
        _ = marginNote
        return background {
            JournalPaperBackground(showMarginRail: showMarginRail)
                .ignoresSafeArea()
        }
    }
}

/// Leaf-shaped cutout used as the scan viewfinder mask (design SVG path, even-odd paper plate).
struct LeafOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Uniform scale so the leaf isn't stretched on tall phones; center in the plate.
        let scale = min(rect.width / 375, rect.height / 720)
        let ox = rect.minX + (rect.width - 375 * scale) / 2
        let oy = rect.minY + (rect.height - 720 * scale) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * scale, y: oy + y * scale)
        }
        var path = Path()
        path.move(to: p(283, 128))
        path.addCurve(to: p(214, 316), control1: p(283, 128), control2: p(268, 232))
        path.addCurve(to: p(96, 438), control1: p(160, 400), control2: p(96, 438))
        path.addCurve(to: p(162, 246), control1: p(96, 438), control2: p(108, 330))
        path.addCurve(to: p(283, 128), control1: p(216, 162), control2: p(283, 128))
        path.closeSubpath()
        return path
    }
}

struct LeafScanMaskOverlay: View {
    var paper: Color
    var edge: Color

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            ZStack {
                // Opaque paper with leaf hole
                Path { path in
                    path.addRect(rect)
                    path.addPath(LeafOutlineShape().path(in: rect))
                }
                .fill(paper, style: FillStyle(eoFill: true))

                LeafOutlineShape()
                    .stroke(edge.opacity(0.5), lineWidth: 1.4)

                // Midrib
                LeafMidribShape()
                    .stroke(edge.opacity(0.42), style: StrokeStyle(lineWidth: 1.2, dash: [5, 6]))

                LeafVeinShape()
                    .stroke(edge.opacity(0.28), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct LeafMidribShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / 375, rect.height / 720)
        let ox = rect.minX + (rect.width - 375 * scale) / 2
        let oy = rect.minY + (rect.height - 720 * scale) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * scale, y: oy + y * scale)
        }
        var path = Path()
        path.move(to: p(279, 133))
        path.addCurve(to: p(100, 433), control1: p(230, 210), control2: p(176, 300))
        return path
    }
}

private struct LeafVeinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / 375, rect.height / 720)
        let ox = rect.minX + (rect.width - 375 * scale) / 2
        let oy = rect.minY + (rect.height - 720 * scale) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * scale, y: oy + y * scale)
        }
        var path = Path()
        let segments: [(CGPoint, CGPoint)] = [
            (p(243, 196), p(266, 176)), (p(215, 244), p(242, 228)),
            (p(186, 292), p(214, 278)), (p(156, 340), p(184, 328)),
            (p(243, 196), p(212, 198)), (p(215, 244), p(184, 248)),
            (p(186, 292), p(156, 298)), (p(156, 340), p(128, 348))
        ]
        for (a, b) in segments {
            path.move(to: a)
            path.addLine(to: b)
        }
        return path
    }
}

/// Simple multi-point health score polyline for plant detail.
struct HealthTimelineChart: View {
    var scores: [Int]
    var lineColor: Color
    var dipColor: Color
    var height: CGFloat = 88

    var body: some View {
        GeometryReader { geo in
            let points = chartPoints(in: geo.size)
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineJoin: .round))

                ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                    let point = points[index]
                    let isDip = isLocalDip(at: index)
                    let isLatest = index == scores.count - 1
                    Circle()
                        .fill(isDip ? dipColor : (isLatest ? Color.clear : lineColor))
                        .overlay(
                            Circle()
                                .stroke(lineColor, lineWidth: isLatest ? 2 : 0)
                        )
                        .frame(width: isLatest ? 10 : 7, height: isLatest ? 10 : 7)
                        .position(point)
                    Text("\(score)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isDip ? dipColor : lineColor)
                        .position(x: point.x, y: isDip ? point.y + 14 : point.y - 14)
                }
            }
        }
        .frame(height: height)
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard scores.count > 1 else {
            let y = size.height / 2
            return [CGPoint(x: size.width / 2, y: y)]
        }
        let minScore = CGFloat(scores.min() ?? 0)
        let maxScore = CGFloat(scores.max() ?? 100)
        let range = max(maxScore - minScore, 10)
        let padY: CGFloat = 16
        return scores.enumerated().map { index, score in
            let x = size.width * CGFloat(index) / CGFloat(scores.count - 1)
            let normalized = (CGFloat(score) - minScore) / range
            let y = size.height - padY - normalized * (size.height - padY * 2)
            return CGPoint(x: x, y: y)
        }
    }

    private func isLocalDip(at index: Int) -> Bool {
        guard scores.count >= 3, index > 0, index < scores.count - 1 else { return false }
        return scores[index] < scores[index - 1] && scores[index] < scores[index + 1]
    }
}
