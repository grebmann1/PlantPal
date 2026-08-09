import Foundation

struct PlantExpertAIResult: Codable, Hashable {
    var reply: String
}

struct PlantExpertChatMessage: Hashable, Identifiable {
    var id: UUID
    var role: Role
    var content: String
    /// Optional JPEG bytes for a photo attached to this turn (user messages only).
    var imageJPEGData: Data?

    enum Role: String, Codable, Hashable {
        case user
        case assistant
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        imageJPEGData: Data? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.imageJPEGData = imageJPEGData
    }

    /// Payload shape expected by `ai-proxy`.
    struct Wire: Encodable {
        var role: String
        var content: String
        var image_base64: String?
        var image_mime_type: String?
    }

    var wire: Wire {
        Wire(
            role: role.rawValue,
            content: content,
            image_base64: imageJPEGData.map { $0.base64EncodedString() },
            image_mime_type: imageJPEGData == nil ? nil : "image/jpeg"
        )
    }
}
