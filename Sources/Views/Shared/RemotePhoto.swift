import SwiftUI

/// Loads a plant photo from a private Supabase Storage object path by resolving a
/// short-lived signed URL, then displays it like AsyncImage. Falls back to a leaf glyph.
struct RemotePhoto: View {
    let path: String?
    var contentMode: ContentMode = .fill

    @State private var url: URL?
    @State private var localImage: UIImage?
    @State private var failed = false
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            if let localImage {
                Image(uiImage: localImage).resizable().aspectRatio(contentMode: contentMode)
            } else if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder.overlay(ProgressView())
                    @unknown default:
                        placeholder
                    }
                }
            } else if failed || path == nil {
                placeholder
            } else {
                placeholder.overlay(ProgressView())
            }
        }
        .task(id: path) { await resolve() }
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

    private func resolve() async {
        guard let path else { return }
        localImage = nil
        url = nil
        failed = false
        if path.hasPrefix(LocalPhotoStore.prefix) {
            if let data = LocalPhotoStore.load(path: path), let image = UIImage(data: data) {
                localImage = image
            } else {
                failed = true
            }
            return
        }
        do {
            url = try await StorageService.signedURL(path: path)
        } catch {
            failed = true
        }
    }
}
