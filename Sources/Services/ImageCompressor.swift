import UIKit

enum ImageCompressor {
    /// Downscales and compresses a UIImage for AI plant analysis (max 1024px on longest side).
    /// Typically produces high-quality JPEG Data around 80 KB - 180 KB instead of 8 MB.
    static func prepareForAI(_ image: UIImage, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data {
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality) ?? image.jpegData(compressionQuality: quality) ?? Data()
    }

    /// Downscales raw image Data if necessary, ensuring max dimension <= 1024px and optimal size.
    static func prepareForAI(_ data: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data {
        guard let image = UIImage(data: data) else { return data }
        return prepareForAI(image, maxDimension: maxDimension, quality: quality)
    }

    /// Downscales and compresses a UIImage for plant photo storage (max 1600px).
    static func prepareForStorage(_ image: UIImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data {
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality) ?? image.jpegData(compressionQuality: quality) ?? Data()
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
