import SwiftUI

/// Displays a catalog species image from an absolute HTTP(S) URL
/// (mirrored Supabase public URL or original Perenual URL).
struct CatalogPhoto: View {
    let urlString: String?
    var contentMode: ContentMode = .fill

    @Environment(\.appTheme) private var theme

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder.overlay(ProgressView().tint(theme.primary))
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(theme.surfaceSunken)
            .overlay(
                Image(systemName: "leaf.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(theme.primary.opacity(0.5))
            )
    }
}
