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

    private static func key(_ base: String, userId: UUID?) -> String {
        guard let userId else { return base }
        return "\(base).\(userId.uuidString)"
    }

    static func loadPlants(userId: UUID? = nil) -> [Plant] {
        load(key(plantsKey, userId: userId))
    }

    static func savePlants(_ plants: [Plant], userId: UUID? = nil) {
        save(plants, key: key(plantsKey, userId: userId))
    }

    static func loadReminders(userId: UUID? = nil) -> [Reminder] {
        load(key(remindersKey, userId: userId))
    }

    static func saveReminders(_ reminders: [Reminder], userId: UUID? = nil) {
        save(reminders, key: key(remindersKey, userId: userId))
    }

    static func loadScans(userId: UUID? = nil) -> [PlantScan] {
        load(key(scansKey, userId: userId))
    }

    static func saveScans(_ scans: [PlantScan], userId: UUID? = nil) {
        save(scans, key: key(scansKey, userId: userId))
    }

    static func loadCareGuides(userId: UUID? = nil) -> [CareGuide] {
        load(key(careGuidesKey, userId: userId))
    }

    static func saveCareGuides(_ guides: [CareGuide], userId: UUID? = nil) {
        save(guides, key: key(careGuidesKey, userId: userId))
    }

    static func saveCareGuide(_ guide: CareGuide, userId: UUID) {
        var guides = loadCareGuides(userId: userId)
        guides.removeAll { $0.speciesLatinName == guide.speciesLatinName }
        guides.append(guide)
        saveCareGuides(guides, userId: userId)
    }

    static func clearAll(userId: UUID) {
        [plantsKey, remindersKey, scansKey, careGuidesKey].forEach {
            defaults.removeObject(forKey: key($0, userId: userId))
        }
    }

    static func migrateLegacyDataIfNeeded(to userId: UUID) {
        let migrationKey = "pp.local.scopedMigration.\(userId.uuidString)"
        guard !defaults.bool(forKey: migrationKey) else { return }

        if defaults.data(forKey: key(plantsKey, userId: userId)) == nil,
           let legacy = defaults.data(forKey: plantsKey) {
            defaults.set(legacy, forKey: key(plantsKey, userId: userId))
        }
        if defaults.data(forKey: key(remindersKey, userId: userId)) == nil,
           let legacy = defaults.data(forKey: remindersKey) {
            defaults.set(legacy, forKey: key(remindersKey, userId: userId))
        }
        if defaults.data(forKey: key(scansKey, userId: userId)) == nil,
           let legacy = defaults.data(forKey: scansKey) {
            defaults.set(legacy, forKey: key(scansKey, userId: userId))
        }
        if defaults.data(forKey: key(careGuidesKey, userId: userId)) == nil,
           let legacy = defaults.data(forKey: careGuidesKey) {
            defaults.set(legacy, forKey: key(careGuidesKey, userId: userId))
        }

        [plantsKey, remindersKey, scansKey, careGuidesKey].forEach(defaults.removeObject(forKey:))
        defaults.set(true, forKey: migrationKey)
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

    static func save(imageData: Data, folder: String, userId: UUID) throws -> String {
        let dir = try folderURL("\(userId.uuidString)/\(folder)")
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = dir.appendingPathComponent(fileName)
        try imageData.write(to: fileURL, options: .atomic)
        return "\(prefix)\(userId.uuidString)/\(folder)/\(fileName)"
    }

    static func load(path: String) -> Data? {
        guard path.hasPrefix(prefix) else { return nil }
        let relative = String(path.dropFirst(prefix.count))
        guard let base = try? baseDirectory() else { return nil }
        return try? Data(contentsOf: base.appendingPathComponent(relative))
    }

    static func remove(path: String) throws {
        guard path.hasPrefix(prefix) else { return }
        let relative = String(path.dropFirst(prefix.count))
        let fileURL = try baseDirectory().appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    static func removeAll(userId: UUID) throws {
        let userDirectory = try baseDirectory().appendingPathComponent(userId.uuidString)
        guard FileManager.default.fileExists(atPath: userDirectory.path) else { return }
        try FileManager.default.removeItem(at: userDirectory)
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
