import Foundation

struct NewReminder: Codable {
    var userId: UUID
    var plantId: UUID
    var type: String
    var dueAt: String
    var amountLabel: String?

    enum CodingKeys: String, CodingKey {
        case type
        case userId = "user_id"
        case plantId = "plant_id"
        case dueAt = "due_at"
        case amountLabel = "amount_label"
    }
}