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
