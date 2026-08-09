import Foundation

struct Reminder: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID
    var plantId: UUID
    var type: String
    var dueAt: String
    var amountLabel: String?
    var isCompleted: Bool
    var snoozedUntil: String?

    enum CodingKeys: String, CodingKey {
        case id, type
        case userId = "user_id"
        case plantId = "plant_id"
        case dueAt = "due_at"
        case amountLabel = "amount_label"
        case isCompleted = "is_completed"
        case snoozedUntil = "snoozed_until"
    }
}