import SwiftUI

struct PlantAnalysisLoadingView: View {
    let eyebrow: String
    let status: String

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var rotation = PlantQuoteRotation(
        generalIndex: Int.random(in: PlantQuoteLibrary.all.indices),
        specificIndex: Int.random(in: PlantQuoteLibrary.specificPlants.indices)
    )

    private var quote: PlantQuote {
        rotation.current(
            general: PlantQuoteLibrary.all,
            specific: PlantQuoteLibrary.specificPlants
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(theme.primary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(eyebrow)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(theme.primary)
                    Text(status)
                        .font(theme.subheadFont)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(eyebrow)
            .accessibilityValue(status)

            Rectangle()
                .fill(theme.separator)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.accent)

                Text(quote.quote)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(quote.author)")
                    .font(theme.footnoteFont.weight(.semibold))
                    .foregroundStyle(theme.primary)
            }
            .frame(minHeight: 200, alignment: .topLeading)
            .id(quote.id)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(quote.quote), \(quote.author)")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg))
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
        .task(id: voiceOverEnabled) {
            guard !voiceOverEnabled else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) {
                    advanceQuote()
                }
            }
        }
    }

    private func advanceQuote() {
        rotation.advance(
            general: PlantQuoteLibrary.all,
            specific: PlantQuoteLibrary.specificPlants
        )
    }
}
