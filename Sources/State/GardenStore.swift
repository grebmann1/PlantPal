import Foundation
import Supabase

@MainActor
final class GardenStore: ObservableObject {
    @Published var plants: [Plant] = []
    @Published var reminders: [Reminder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// True when the current session is a guest session. All reads/writes are
    /// then routed to on-device storage instead of Supabase, since guests have
    /// no auth token and would otherwise fail every row-level-security check.
    @Published private(set) var isGuest = false

    private var seededUserIds: Set<UUID> = []

    // MARK: - Load

    func loadAll(userId: UUID, isGuest: Bool = false) async {
        self.isGuest = isGuest
        isLoading = true
        defer { isLoading = false }

        if isGuest {
            seedLocalDemoDataIfNeeded(userId: userId)
            plants = LocalGardenStore.loadPlants()
            reminders = LocalGardenStore.loadReminders()
            return
        }

        await seedDemoDataIfNeeded(userId: userId)
        async let plantsTask: [Plant] = fetchPlants(userId: userId)
        async let remindersTask: [Reminder] = fetchReminders(userId: userId)
        do {
            plants = try await plantsTask
            reminders = try await remindersTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchPlants(userId: UUID) async throws -> [Plant] {
        try await SupabaseManager.client
            .from("plants")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchReminders(userId: UUID) async throws -> [Reminder] {
        try await SupabaseManager.client
            .from("reminders")
            .select()
            .eq("user_id", value: userId)
            .order("due_at", ascending: true)
            .execute()
            .value
    }

    func fetchScans(plantId: UUID) async throws -> [PlantScan] {
        if isGuest {
            return LocalGardenStore.loadScans()
                .filter { $0.plantId == plantId }
                .sorted { $0.capturedAt > $1.capturedAt }
        }
        return try await SupabaseManager.client
            .from("scans")
            .select()
            .eq("plant_id", value: plantId)
            .order("captured_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Plants

    @discardableResult
    func addPlant(_ plant: NewPlant) async throws -> Plant {
        if isGuest {
            let created = Plant(
                id: UUID(),
                userId: plant.userId,
                nickname: plant.nickname,
                speciesCommonName: plant.speciesCommonName,
                speciesLatinName: plant.speciesLatinName,
                family: plant.family,
                photoUrl: plant.photoUrl,
                healthScore: plant.healthScore,
                nextWateringDate: plant.nextWateringDate,
                wateringIntervalDays: plant.wateringIntervalDays,
                wateringAmountMl: plant.wateringAmountMl,
                addedDate: Self.dateFormatter.string(from: Date()),
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            plants.insert(created, at: 0)
            LocalGardenStore.savePlants(plants)
            return created
        }
        let inserted: [Plant] = try await SupabaseManager.client
            .from("plants")
            .insert(plant)
            .select()
            .execute()
            .value
        if let created = inserted.first {
            plants.insert(created, at: 0)
            return created
        }
        throw NSError(domain: "GardenStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create plant."])
    }

    func updatePlant(id: UUID, healthScore: Int? = nil, nextWateringDate: String? = nil, wateringIntervalDays: Int? = nil, wateringAmountMl: Int? = nil, photoUrl: String? = nil) async {
        if isGuest {
            if let idx = plants.firstIndex(where: { $0.id == id }) {
                if let healthScore { plants[idx].healthScore = healthScore }
                if let nextWateringDate { plants[idx].nextWateringDate = nextWateringDate }
                if let wateringIntervalDays { plants[idx].wateringIntervalDays = wateringIntervalDays }
                if let wateringAmountMl { plants[idx].wateringAmountMl = wateringAmountMl }
                if let photoUrl { plants[idx].photoUrl = photoUrl }
                LocalGardenStore.savePlants(plants)
            }
            return
        }
        struct Patch: Encodable {
            var health_score: Int?
            var next_watering_date: String?
            var watering_interval_days: Int?
            var watering_amount_ml: Int?
            var photo_url: String?
        }
        let patch = Patch(health_score: healthScore, next_watering_date: nextWateringDate, watering_interval_days: wateringIntervalDays, watering_amount_ml: wateringAmountMl, photo_url: photoUrl)
        do {
            try await SupabaseManager.client.from("plants").update(patch).eq("id", value: id).execute()
            if let idx = plants.firstIndex(where: { $0.id == id }) {
                if let healthScore { plants[idx].healthScore = healthScore }
                if let nextWateringDate { plants[idx].nextWateringDate = nextWateringDate }
                if let wateringIntervalDays { plants[idx].wateringIntervalDays = wateringIntervalDays }
                if let wateringAmountMl { plants[idx].wateringAmountMl = wateringAmountMl }
                if let photoUrl { plants[idx].photoUrl = photoUrl }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePlant(id: UUID) async {
        if isGuest {
            plants.removeAll { $0.id == id }
            reminders.removeAll { $0.plantId == id }
            LocalGardenStore.savePlants(plants)
            LocalGardenStore.saveReminders(reminders)
            var scans = LocalGardenStore.loadScans()
            scans.removeAll { $0.plantId == id }
            LocalGardenStore.saveScans(scans)
            return
        }
        do {
            try await SupabaseManager.client.from("plants").delete().eq("id", value: id).execute()
            plants.removeAll { $0.id == id }
            reminders.removeAll { $0.plantId == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Scans

    @discardableResult
    func addScan(_ scan: NewScan) async throws -> PlantScan {
        if isGuest {
            let created = PlantScan(
                id: UUID(),
                userId: scan.userId,
                plantId: scan.plantId,
                photoUrl: scan.photoUrl,
                scanType: scan.scanType,
                capturedAt: ISO8601DateFormatter().string(from: Date()),
                confidence: scan.confidence,
                healthStatus: scan.healthStatus,
                healthScore: scan.healthScore
            )
            var scans = LocalGardenStore.loadScans()
            scans.insert(created, at: 0)
            LocalGardenStore.saveScans(scans)
            return created
        }
        let inserted: [PlantScan] = try await SupabaseManager.client
            .from("scans")
            .insert(scan)
            .select()
            .execute()
            .value
        guard let created = inserted.first else {
            throw NSError(domain: "GardenStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not save scan."])
        }
        return created
    }

    // MARK: - Care guides

    func fetchCareGuide(userId: UUID, speciesLatinName: String) async throws -> CareGuide? {
        if isGuest {
            return LocalGardenStore.loadCareGuides().first { $0.speciesLatinName == speciesLatinName }
        }
        let guides: [CareGuide] = try await SupabaseManager.client
            .from("care_guides")
            .select()
            .eq("user_id", value: userId)
            .eq("species_latin_name", value: speciesLatinName)
            .limit(1)
            .execute()
            .value
        return guides.first
    }

    @discardableResult
    func saveCareGuide(_ guide: NewCareGuide) async throws -> CareGuide {
        if isGuest {
            let created = CareGuide(
                id: UUID(),
                speciesLatinName: guide.speciesLatinName,
                lightRequirement: guide.lightRequirement,
                wateringFrequency: guide.wateringFrequency,
                wateringAmount: guide.wateringAmount,
                soilMix: guide.soilMix,
                temperatureRange: guide.temperatureRange,
                humidityRange: guide.humidityRange,
                difficultyLevel: guide.difficultyLevel,
                commonProblems: guide.commonProblems
            )
            var guides = LocalGardenStore.loadCareGuides()
            guides.removeAll { $0.speciesLatinName == guide.speciesLatinName }
            guides.append(created)
            LocalGardenStore.saveCareGuides(guides)
            return created
        }
        let inserted: [CareGuide] = try await SupabaseManager.client
            .from("care_guides")
            .insert(guide)
            .select()
            .execute()
            .value
        guard let created = inserted.first else {
            throw NSError(domain: "GardenStore", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not save care guide."])
        }
        return created
    }

    // MARK: - Reminders

    @discardableResult
    func addReminder(_ reminder: NewReminder) async throws -> Reminder {
        if isGuest {
            let created = Reminder(
                id: UUID(),
                userId: reminder.userId,
                plantId: reminder.plantId,
                type: reminder.type,
                dueAt: reminder.dueAt,
                amountLabel: reminder.amountLabel,
                isCompleted: false,
                snoozedUntil: nil
            )
            reminders.append(created)
            reminders.sort { $0.dueAt < $1.dueAt }
            LocalGardenStore.saveReminders(reminders)
            return created
        }
        let inserted: [Reminder] = try await SupabaseManager.client
            .from("reminders")
            .insert(reminder)
            .select()
            .execute()
            .value
        guard let created = inserted.first else {
            throw NSError(domain: "GardenStore", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create reminder."])
        }
        reminders.append(created)
        reminders.sort { $0.dueAt < $1.dueAt }
        return created
    }

    func markWatered(_ reminder: Reminder) async {
        if isGuest {
            if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[idx].isCompleted = true
                LocalGardenStore.saveReminders(reminders)
            }
            if let plant = plants.first(where: { $0.id == reminder.plantId }), reminder.type == "watering" {
                let interval = plant.wateringIntervalDays ?? 7
                let nextDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
                await updatePlant(id: plant.id, nextWateringDate: Self.dateFormatter.string(from: nextDate))
            }
            return
        }
        struct Patch: Encodable { var is_completed: Bool }
        do {
            try await SupabaseManager.client.from("reminders").update(Patch(is_completed: true)).eq("id", value: reminder.id).execute()
            if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[idx].isCompleted = true
            }
            if let plant = plants.first(where: { $0.id == reminder.plantId }), reminder.type == "watering" {
                let interval = plant.wateringIntervalDays ?? 7
                let nextDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
                await updatePlant(id: plant.id, nextWateringDate: Self.dateFormatter.string(from: nextDate))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func snooze(_ reminder: Reminder, days: Int = 1) async {
        guard let current = Self.dateTimeFormatter.date(from: reminder.dueAt) ?? ISO8601DateFormatter().date(from: reminder.dueAt) else { return }
        let newDate = Calendar.current.date(byAdding: .day, value: days, to: current) ?? current
        await reschedule(reminder, to: newDate)
    }

    func reschedule(_ reminder: Reminder, to date: Date) async {
        let iso = ISO8601DateFormatter().string(from: date)
        if isGuest {
            if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[idx].dueAt = iso
                reminders.sort { $0.dueAt < $1.dueAt }
                LocalGardenStore.saveReminders(reminders)
            }
            return
        }
        struct Patch: Encodable { var due_at: String }
        do {
            try await SupabaseManager.client.from("reminders").update(Patch(due_at: iso)).eq("id", value: reminder.id).execute()
            if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[idx].dueAt = iso
                reminders.sort { $0.dueAt < $1.dueAt }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Demo seed (signed-in / Supabase)

    private func seedDemoDataIfNeeded(userId: UUID) async {
        if seededUserIds.contains(userId) { return }
        seededUserIds.insert(userId)
        guard let existing = try? await fetchPlants(userId: userId), existing.isEmpty else { return }

        for seed in Self.demoSeeds {
            let newPlant = NewPlant(
                userId: userId,
                nickname: seed.nickname,
                speciesCommonName: seed.common,
                speciesLatinName: seed.latin,
                family: seed.family,
                photoUrl: nil,
                healthScore: seed.score,
                nextWateringDate: Self.daysFromNow(seed.waterOffset),
                wateringIntervalDays: seed.interval,
                wateringAmountMl: seed.amount
            )
            if let created = try? await addPlant(newPlant) {
                let due = Calendar.current.date(byAdding: .day, value: seed.waterOffset, to: Date()) ?? Date()
                let reminder = NewReminder(
                    userId: userId,
                    plantId: created.id,
                    type: "watering",
                    dueAt: ISO8601DateFormatter().string(from: due),
                    amountLabel: "\(seed.amount) ml"
                )
                _ = try? await addReminder(reminder)
            }
        }
        plants = (try? await fetchPlants(userId: userId)) ?? plants
    }

    // MARK: - Demo seed (guest / local)

    private func seedLocalDemoDataIfNeeded(userId: UUID) {
        guard LocalGardenStore.loadPlants().isEmpty else { return }
        var seededPlants: [Plant] = []
        var seededReminders: [Reminder] = []

        for seed in Self.demoSeeds {
            let plant = Plant(
                id: UUID(),
                userId: userId,
                nickname: seed.nickname,
                speciesCommonName: seed.common,
                speciesLatinName: seed.latin,
                family: seed.family,
                photoUrl: nil,
                healthScore: seed.score,
                nextWateringDate: Self.daysFromNow(seed.waterOffset),
                wateringIntervalDays: seed.interval,
                wateringAmountMl: seed.amount,
                addedDate: Self.dateFormatter.string(from: Date()),
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            let due = Calendar.current.date(byAdding: .day, value: seed.waterOffset, to: Date()) ?? Date()
            let reminder = Reminder(
                id: UUID(),
                userId: userId,
                plantId: plant.id,
                type: "watering",
                dueAt: ISO8601DateFormatter().string(from: due),
                amountLabel: "\(seed.amount) ml",
                isCompleted: false,
                snoozedUntil: nil
            )
            seededPlants.append(plant)
            seededReminders.append(reminder)
        }
        LocalGardenStore.savePlants(seededPlants)
        LocalGardenStore.saveReminders(seededReminders)
    }

    private static let demoSeeds: [(nickname: String, common: String, latin: String, family: String, score: Int, interval: Int, amount: Int, waterOffset: Int)] = [
        ("Kevin", "Swiss Cheese Plant", "Monstera deliciosa", "Araceae", 92, 7, 400, 3),
        ("Spike", "Snake Plant", "Dracaena trifasciata", "Asparagaceae", 95, 14, 150, 8),
        ("Big Fig", "Fiddle-Leaf Fig", "Ficus lyrata", "Moraceae", 68, 9, 350, -2),
        ("Ivy Curtain", "Pothos", "Epipremnum aureum", "Araceae", 88, 7, 200, 0),
        ("Zebra", "Calathea", "Calathea orbifolia", "Marantaceae", 46, 5, 250, -1),
        ("Aloe", "Aloe Vera", "Aloe barbadensis", "Asphodelaceae", 97, 18, 100, 6)
    ]

    private static func daysFromNow(_ n: Int) -> String {
        dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: n, to: Date()) ?? Date())
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return f
    }()
}
