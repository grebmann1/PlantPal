import Foundation
import UserNotifications

/// Schedules local notifications for watering digests and health-scan nudges.
enum NotificationService {
    private static let wateringId = "pp.watering.daily"
    private static let scanPrefix = "pp.scan.nudge."

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Rebuilds watering + scan schedules from current prefs and garden state.
    static func reschedule(
        wateringEnabled: Bool,
        scanNudgesEnabled: Bool,
        reminderTimeSeconds: Double,
        plants: [Plant],
        requestAuthorization: Bool = false
    ) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(
            withIdentifiers: [wateringId] + plants.map { scanPrefix + $0.id.uuidString }
        )

        guard wateringEnabled || scanNudgesEnabled else { return }
        let allowed: Bool
        if requestAuthorization {
            allowed = await requestAuthorizationIfNeeded()
        } else {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            allowed = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral
        }
        guard allowed else { return }

        if wateringEnabled {
            await scheduleDailyWatering(at: reminderTimeSeconds)
        }
        if scanNudgesEnabled {
            for plant in plants {
                await scheduleScanNudge(for: plant)
            }
        }
    }

    private static func scheduleDailyWatering(at seconds: Double) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Watering ledger")
        content.body = String(localized: "Check which specimens need a drink today.")
        content.sound = .default

        var comps = DateComponents()
        let total = Int(seconds)
        comps.hour = total / 3600
        comps.minute = (total % 3600) / 60

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: wateringId, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func scheduleScanNudge(for plant: Plant) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Health check")
        content.body = String(localized: "Time for a 30-day health scan of \(plant.nickname).")
        content.sound = .default

        // Fire ~30 days from now (or from addedDate if parseable).
        var fireDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date().addingTimeInterval(30 * 86400)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let added = formatter.date(from: plant.addedDate),
           let next = Calendar.current.date(byAdding: .day, value: 30, to: added),
           next > Date() {
            fireDate = next
        }

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: scanPrefix + plant.id.uuidString,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
