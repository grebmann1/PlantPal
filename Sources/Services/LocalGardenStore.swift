import Foundation

/// On-device persistence used for guest sessions, since guests have no Supabase
/// auth token and therefore cannot pass row-level-security checks on the
/// `plants` / `reminders` / `scans` / `care_guides` tables. Mirrors the shape of
/// the cloud tables closely enough that GardenStore can use the same models.
enum LocalGardenStore {
    private static var defaults: UserDefaults { .standard }
    private static let plantsKey = "pp.local.plants"
    private static let remindersKey = "pp.local.reminders"
    private static let scansKey = "pp.local.scans"
    private static let careGuidesKey = "pp.local.careguides"

    static func loadPlants() -> [Plant] {
        load(plantsKey)
    }

    static func savePlants(_ plants: [Plant]) {
        save(plants, key: plantsKey)
    }

    static func loadReminders() -> [Reminder] {
        load(remindersKey)
    }

    static func saveReminders(_ reminders: [Reminder]) {
        save(reminders, key: remindersKey)
    }

    static func loadScans() -> [PlantScan] {
        load(scansKey)
    }

    static func saveScans(_ scans: [PlantScan]) {
        save(scans, key: scansKey)
    }

    static func loadCareGuides() -> [CareGuide] {
        load(careGuidesKey)
    }

    static func saveCareGuides(_ guides: [CareGuide]) {
        save(guides, key: careGuidesKey)
    }

    private static func load<T: Decodable>(_ key: String) -> [T] {
        guard let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([T].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func save<T: Encodable>(_ values: [T], key: String) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Saves captured plant/scan photos to disk for guest sessions so photos still
/// render without a Supabase Storage upload. Paths are prefixed with "local:" so
/// `RemotePhoto` knows to read them from disk instead of resolving a signed URL.
enum LocalPhotoStore {
    static let prefix = "local:"

    static func save(imageData: Data, folder: String) throws -> String {
        let dir = try folderURL(folder)
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = dir.appendingPathComponent(fileName)
        try imageData.write(to: fileURL, options: .atomic)
        return "\(prefix)\(folder)/\(fileName)"
    }

    static func load(path: String) -> Data? {
        guard path.hasPrefix(prefix) else { return nil }
        let relative = String(path.dropFirst(prefix.count))
        guard let base = try? baseDirectory() else { return nil }
        return try? Data(contentsOf: base.appendingPathComponent(relative))
    }

    private static func folderURL(_ folder: String) throws -> URL {
        let base = try baseDirectory().appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func baseDirectory() throws -> URL {
        let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return docs.appendingPathComponent("local_photos", isDirectory: true)
    }
}
