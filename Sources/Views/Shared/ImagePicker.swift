import SwiftUI
import UIKit

/// Thin UIImagePickerController wrapper for camera capture (simulator falls back to photo library
/// automatically since .camera source isn't available there).
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var flashMode: UIImagePickerController.CameraFlashMode = .auto
    var onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        let resolved = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.sourceType = resolved
        picker.allowsEditing = false
        if resolved == .camera, UIImagePickerController.isFlashAvailable(for: .rear) {
            picker.cameraFlashMode = flashMode
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        if uiViewController.sourceType == .camera, UIImagePickerController.isFlashAvailable(for: .rear) {
            uiViewController.cameraFlashMode = flashMode
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, @preconcurrency UIImagePickerControllerDelegate, @preconcurrency UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
