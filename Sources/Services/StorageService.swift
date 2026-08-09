import Foundation
import Supabase

enum StorageService {
    /// Uploads a JPEG photo to the private `plant-photos` bucket under the user's own folder.
    /// Returns the storage object path (not a public URL, since the bucket is private).
    static func uploadPhoto(userId: UUID, imageData: Data, folder: String) async throws -> String {
        let path = "\(userId.uuidString)/\(folder)/\(UUID().uuidString).jpg"
        try await SupabaseManager.client.storage
            .from(SupabaseManager.storageBucket)
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        return path
    }

    /// Resolves a storage object path to a short-lived signed URL for display.
    static func signedURL(path: String, expiresIn: Int = 3600) async throws -> URL {
        let signed = try await SupabaseManager.client.storage
            .from(SupabaseManager.storageBucket)
            .createSignedURL(path: path, expiresIn: expiresIn)
        return signed
    }

    /// Routes a photo upload either to Supabase Storage (signed-in users) or to
    /// on-device storage (guests, who have no auth token to satisfy Storage RLS).
    static func upload(userId: UUID, imageData: Data, folder: String, isGuest: Bool) async throws -> String {
        if isGuest {
            return try LocalPhotoStore.save(imageData: imageData, folder: folder)
        }
        return try await uploadPhoto(userId: userId, imageData: imageData, folder: folder)
    }
}
