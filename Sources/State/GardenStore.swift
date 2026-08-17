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
    private var localUserId: UUID?

    // MARK: - Load

    func loadAll(userId: UUID, isGuest: Bool = false) async {
        self.isGuest = isGuest
        localUserId = isGuest ? userId : nil
        isLoading = true
        defer { isLoading = false }

        if isGuest {
            LocalGardenStore.migrateLegacyDataIfNeeded(to: userId)
            if DemoContent.isEnabled {
                seedLocalDemoDataIfNeeded(userId: userId)
            }
            plants = LocalGardenStore.loadPlants(userId: userId)
            reminders = LocalGardenStore.loadReminders(userId: userId)
            return
        }

        if DemoContent.isEnabled {
            await seedDemoDataIfNeeded(userId: userId)
        }
        async let plantsTask: [Plant] = fetchPlants(userId: userId)
        async let remindersTask: [Reminder] = fetchReminders(userId: userId)
        do {
            plants = try await plantsTask
            reminders = try await remindersTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importGuestData(from guestUserId: UUID, to userId: UUID) async throws {
        guard !isGuest else {
            throw NSError(
                domain: "GardenStore",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Your account data is still loading. Please try again.")]
            )
        }
        let guestPlants = LocalGardenStore.loadPlants(userId: guestUserId)
        let guestReminders = LocalGardenStore.loadReminders(userId: guestUserId)
        let guestScans = LocalGardenStore.loadScans(userId: guestUserId)
        let guestGuides = LocalGardenStore.loadCareGuides(userId: guestUserId)
        var plantIds: [UUID: UUID] = [:]

        for guestPlant in guestPlants {
            let photoUrl = try await migratePhoto(
                path: guestPlant.photoUrl,
                userId: userId,
                folder: "plants"
            )
            let created = try await addPlant(
                NewPlant(
                    id: guestPlant.id,
                    userId: userId,
                    nickname: guestPlant.nickname,
                    speciesCommonName: guestPlant.speciesCommonName,
                    speciesLatinName: guestPlant.speciesLatinName,
                    family: guestPlant.family,
                    photoUrl: photoUrl,
                    healthScore: guestPlant.healthScore,
                    nextWateringDate: guestPlant.nextWateringDate,
                    wateringIntervalDays: guestPlant.wateringIntervalDays,
                    wateringAmountMl: guestPlant.wateringAmountMl,
                    placement: guestPlant.placement
                )
            )
            plantIds[guestPlant.id] = created.id
        }

        for guestScan in guestScans {
            let photoUrl = try await migratePhoto(path: guestScan.photoUrl, userId: userId, folder: "logs")
            _ = try await addScan(
                NewScan(
                    id: guestScan.id,
                    userId: userId,
                    plantId: guestScan.plantId.flatMap { plantIds[$0] },
                    photoUrl: photoUrl,
                    scanType: guestScan.scanType,
                    confidence: guestScan.confidence,
                    healthStatus: guestScan.healthStatus,
                    healthScore: guestScan.healthScore,
                    aiResultJson: guestScan.aiResultJson
                )
            )
        }

        for guestReminder in guestReminders where !guestReminder.isCompleted {
            guard let plantId = plantIds[guestReminder.plantId] else { continue }
            if guestReminder.type == "watering", let plant = plants.first(where: { $0.id == plantId }) {
                let due = Self.dateTimeFormatter.date(from: guestReminder.dueAt)
                    ?? ISO8601DateFormatter().date(from: guestReminder.dueAt)
                    ?? Date()
                _ = try await ensureWateringReminder(userId: userId, plant: plant, due: due)
            } else {
                _ = try await addReminder(
                    NewReminder(
                        id: guestReminder.id,
                        userId: userId,
                        plantId: plantId,
                        type: guestReminder.type,
                        dueAt: guestReminder.dueAt,
                        amountLabel: guestReminder.amountLabel
                    )
                )
            }
        }

        for guide in guestGuides {
            _ = try await saveCareGuide(
                NewCareGuide(
                    userId: userId,
                    plantId: nil,
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
            )
        }
    }

    private func migratePhoto(path: String?, userId: UUID, folder: String) async throws -> String? {
        guard let path else { return nil }
        guard path.hasPrefix(LocalPhotoStore.prefix) else { return path }
        guard let imageData = LocalPhotoStore.load(path: path) else { return nil }
        let sourcePath = String(path.dropFirst(LocalPhotoStore.prefix.count))
        let fileName = URL(fileURLWithPath: sourcePath).lastPathComponent
        return try await StorageService.upload(
            userId: userId,
            imageData: imageData,
            folder: "\(folder)/guest-import",
            isGuest: false,
            fileName: fileName,
            upsert: true
        )
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
            return LocalGardenStore.loadScans(userId: localUserId)
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
                id: plant.id ?? UUID(),
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
                placement: plant.placement,
                addedDate: Self.dateFormatter.string(from: Date()),
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            if let existingIndex = plants.firstIndex(where: { $0.id == created.id }) {
                plants[existingIndex] = created
            } else {
                plants.insert(created, at: 0)
            }
            LocalGardenStore.savePlants(plants, userId: plant.userId)
            return created
        }
        let inserted: [Plant]
        if plant.id != nil {
            inserted = try await SupabaseManager.client
                .from("plants")
                .upsert(plant, onConflict: "id")
                .select()
                .execute()
                .value
        } else {
            inserted = try await SupabaseManager.client
                .from("plants")
                .insert(plant)
                .select()
                .execute()
                .value
        }
        if let created = inserted.first {
            if let existingIndex = plants.firstIndex(where: { $0.id == created.id }) {
                plants[existingIndex] = created
            } else {
                plants.insert(created, at: 0)
            }
            return created
        }
        throw NSError(domain: "GardenStore", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "Could not create plant.")])
    }

    func updatePlant(
        id: UUID,
        nickname: String? = nil,
        healthScore: Int? = nil,
        nextWateringDate: String? = nil,
        wateringIntervalDays: Int? = nil,
        wateringAmountMl: Int? = nil,
        photoUrl: String? = nil,
        placement: PlantPlacement? = nil
    ) async throws {
        if isGuest {
            if let idx = plants.firstIndex(where: { $0.id == id }) {
                if let nickname { plants[idx].nickname = nickname }
                if let healthScore { plants[idx].healthScore = healthScore }
                if let nextWateringDate { plants[idx].nextWateringDate = nextWateringDate }
                if let wateringIntervalDays { plants[idx].wateringIntervalDays = wateringIntervalDays }
                if let wateringAmountMl { plants[idx].wateringAmountMl = wateringAmountMl }
                if let photoUrl { plants[idx].photoUrl = photoUrl }
                if let placement { plants[idx].placement = placement }
                LocalGardenStore.savePlants(plants, userId: localUserId)
            }
            return
        }
        struct Patch: Encodable {
            var nickname: String?
            var health_score: Int?
            var next_watering_date: String?
            var watering_interval_days: Int?
            var watering_amount_ml: Int?
            var photo_url: String?
            var placement: String?
        }
        let patch = Patch(
            nickname: nickname,
            health_score: healthScore,
            next_watering_date: nextWateringDate,
            watering_interval_days: wateringIntervalDays,
            watering_amount_ml: wateringAmountMl,
            photo_url: photoUrl,
            placement: placement?.rawValue
        )
        try await SupabaseManager.client.from("plants").update(patch).eq("id", value: id).execute()
        if let idx = plants.firstIndex(where: { $0.id == id }) {
            if let nickname { plants[idx].nickname = nickname }
            if let healthScore { plants[idx].healthScore = healthScore }
            if let nextWateringDate { plants[idx].nextWateringDate = nextWateringDate }
            if let wateringIntervalDays { plants[idx].wateringIntervalDays = wateringIntervalDays }
            if let wateringAmountMl { plants[idx].wateringAmountMl = wateringAmountMl }
            if let photoUrl { plants[idx].photoUrl = photoUrl }
            if let placement { plants[idx].placement = placement }
        }
    }

    func deletePlant(id: UUID) async {
        let plantPhoto = plants.first(where: { $0.id == id })?.photoUrl
        let scanPhotos = (try? await fetchScans(plantId: id)).flatMap { scans in
            scans.compactMap(\.photoUrl)
        } ?? []
        if isGuest {
            plants.removeAll { $0.id == id }
            reminders.removeAll { $0.plantId == id }
            LocalGardenStore.savePlants(plants, userId: localUserId)
            LocalGardenStore.saveReminders(reminders, userId: localUserId)
            var scans = LocalGardenStore.loadScans(userId: localUserId)
            scans.removeAll { $0.plantId == id }
            LocalGardenStore.saveScans(scans, userId: localUserId)
            for path in Set(([plantPhoto].compactMap { $0 }) + scanPhotos) {
                try? await StorageService.remove(path: path, isGuest: true)
            }
            return
        }
        do {
            try await SupabaseManager.client.from("plants").delete().eq("id", value: id).execute()
            plants.removeAll { $0.id == id }
            reminders.removeAll { $0.plantId == id }
            for path in Set(([plantPhoto].compactMap { $0 }) + scanPhotos) {
                try? await StorageService.remove(path: path, isGuest: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Scans

    @discardableResult
    func addScan(_ scan: NewScan) async throws -> PlantScan {
        if isGuest {
            let created = PlantScan(
                id: scan.id ?? UUID(),
                userId: scan.userId,
                plantId: scan.plantId,
                photoUrl: scan.photoUrl,
                scanType: scan.scanType,
                capturedAt: ISO8601DateFormatter().string(from: Date()),
                confidence: scan.confidence,
                healthStatus: scan.healthStatus,
                healthScore: scan.healthScore,
                aiResultJson: scan.aiResultJson
            )
            var scans = LocalGardenStore.loadScans(userId: scan.userId)
            scans.removeAll { $0.id == created.id }
            scans.insert(created, at: 0)
            LocalGardenStore.saveScans(scans, userId: scan.userId)
            return created
        }
        let inserted: [PlantScan]
        if scan.id != nil {
            inserted = try await SupabaseManager.client
                .from("scans")
                .upsert(scan, onConflict: "id")
                .select()
                .execute()
                .value
        } else {
            inserted = try await SupabaseManager.client
                .from("scans")
                .insert(scan)
                .select()
                .execute()
                .value
        }
        guard let created = inserted.first else {
            throw NSError(domain: "GardenStore", code: 2, userInfo: [NSLocalizedDescriptionKey: String(localized: "Could not save scan.")])
        }
        return created
    }

    func deleteScan(_ scan: PlantScan) async throws {
        if isGuest {
            var scans = LocalGardenStore.loadScans(userId: localUserId)
            scans.removeAll { $0.id == scan.id }
            LocalGardenStore.saveScans(scans, userId: localUserId)
        } else {
            try await SupabaseManager.client
                .from("scans")
                .delete()
                .eq("id", value: scan.id)
                .execute()
        }
        if let photoUrl = scan.photoUrl {
            try await StorageService.remove(path: photoUrl, isGuest: isGuest)
        }
    }

    // MARK: - Care guides

    func fetchCareGuide(userId: UUID, speciesLatinName: String) async throws -> CareGuide? {
        if isGuest {
            return LocalGardenStore.loadCareGuides(userId: userId).first { $0.speciesLatinName == speciesLatinName }
        }
        do {
            let guides: [CareGuide] = try await SupabaseManager.client
                .from("care_guides")
                .select()
                .eq("user_id", value: userId)
                .eq("species_latin_name", value: speciesLatinName)
                .order("generated_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return guides.first ?? LocalGardenStore.loadCareGuides(userId: userId).first { $0.speciesLatinName == speciesLatinName }
        } catch {
            return LocalGardenStore.loadCareGuides(userId: userId).first { $0.speciesLatinName == speciesLatinName }
        }
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
            var guides = LocalGardenStore.loadCareGuides(userId: guide.userId)
            guides.removeAll { $0.speciesLatinName == guide.speciesLatinName }
            guides.append(created)
            LocalGardenStore.saveCareGuides(guides, userId: guide.userId)
            return created
        }
        let inserted: [CareGuide] = try await SupabaseManager.client
            .from("care_guides")
            .upsert(guide, onConflict: "user_id,species_latin_name")
            .select()
            .execute()
            .value
        guard let created = inserted.first else {
            throw NSError(domain: "GardenStore", code: 3, userInfo: [NSLocalizedDescriptionKey: String(localized: "Could not save care guide.")])
        }
        return created
    }

    // MARK: - Reminders

    @discardableResult
    func addReminder(_ reminder: NewReminder) async throws -> Reminder {
        if isGuest {
            let created = Reminder(
                id: reminder.id ?? UUID(),
                userId: reminder.userId,
                plantId: reminder.plantId,
                type: reminder.type,
                dueAt: reminder.dueAt,
                amountLabel: reminder.amountLabel,
                isCompleted: false,
                snoozedUntil: nil
            )
            reminders.removeAll { $0.id == created.id }
            reminders.append(created)
            reminders.sort { $0.dueAt < $1.dueAt }
            LocalGardenStore.saveReminders(reminders, userId: reminder.userId)
            return created
        }
        let inserted: [Reminder]
        if reminder.id != nil {
            inserted = try await SupabaseManager.client
                .from("reminders")
                .upsert(reminder, onConflict: "id")
                .select()
                .execute()
                .value
        } else {
            inserted = try await SupabaseManager.client
                .from("reminders")
                .insert(reminder)
                .select()
                .execute()
                .value
        }
        guard let created = inserted.first else {
            throw NSError(domain: "GardenStore", code: 4, userInfo: [NSLocalizedDescriptionKey: String(localized: "Could not create reminder.")])
        }
        reminders.append(created)
        reminders.sort { $0.dueAt < $1.dueAt }
        return created
    }

    func markWatered(_ reminder: Reminder) async {
        do {
            try await completeReminder(reminder)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeReminder(_ reminder: Reminder) async throws {
        if isGuest {
            if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[idx].isCompleted = true
                LocalGardenStore.saveReminders(reminders, userId: localUserId)
            }
            if let plant = plants.first(where: { $0.id == reminder.plantId }), reminder.type == "watering" {
                let interval = plant.wateringIntervalDays ?? 7
                let nextDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
                try await updatePlant(id: plant.id, nextWateringDate: Self.dateFormatter.string(from: nextDate))
                _ = try await ensureWateringReminder(
                    userId: reminder.userId,
                    plant: plant,
                    due: nextDate
                )
            }
            return
        }
        struct Patch: Encodable { var is_completed: Bool }
        if let plant = plants.first(where: { $0.id == reminder.plantId }), reminder.type == "watering" {
            let interval = plant.wateringIntervalDays ?? 7
            let nextDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
            struct WateringCompletion: Encodable {
                var p_reminder_id: UUID
                var p_next_watering_date: String
                var p_next_due_at: String
                var p_next_amount_label: String?
            }
            struct WateringCompletionResult: Decodable {
                var next_watering_date: String
                var next_reminder_id: UUID
                var next_reminder_due_at: String
                var next_reminder_amount_label: String?
            }

            let result: [WateringCompletionResult] = try await SupabaseManager.client
                .rpc(
                    "complete_watering_reminder",
                    params: WateringCompletion(
                        p_reminder_id: reminder.id,
                        p_next_watering_date: Self.dateFormatter.string(from: nextDate),
                        p_next_due_at: ISO8601DateFormatter().string(from: nextDate),
                        p_next_amount_label: plant.wateringAmountMl.map { UnitsFormatting.waterAmount(ml: $0) }
                    )
                )
                .execute()
                .value
            guard let completion = result.first else {
                throw NSError(
                    domain: "GardenStore",
                    code: 6,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "Couldn't complete watering reminder.")]
                )
            }
            if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[idx].isCompleted = true
            }
            if let plantIndex = plants.firstIndex(where: { $0.id == plant.id }) {
                plants[plantIndex].nextWateringDate = completion.next_watering_date
            }
            let nextReminder = Reminder(
                id: completion.next_reminder_id,
                userId: reminder.userId,
                plantId: plant.id,
                type: "watering",
                dueAt: completion.next_reminder_due_at,
                amountLabel: completion.next_reminder_amount_label,
                isCompleted: false,
                snoozedUntil: nil
            )
            reminders.removeAll { $0.id == nextReminder.id }
            reminders.append(nextReminder)
            reminders.sort { $0.dueAt < $1.dueAt }
            return
        }
        try await SupabaseManager.client.from("reminders").update(Patch(is_completed: true)).eq("id", value: reminder.id).execute()
        if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[idx].isCompleted = true
        }
    }

    func updateWateringSchedule(
        plantId: UUID,
        userId: UUID,
        interval: Int,
        amount: Int
    ) async throws {
        guard let plant = plants.first(where: { $0.id == plantId }) else { return }
        let nextDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
        try await updatePlant(
            id: plantId,
            nextWateringDate: Self.dateFormatter.string(from: nextDate),
            wateringIntervalDays: interval,
            wateringAmountMl: amount
        )
        guard let updated = plants.first(where: { $0.id == plantId }) else { return }
        _ = try await ensureWateringReminder(userId: userId, plant: updated, due: nextDate)
    }

    func ensureWateringReminder(userId: UUID, plant: Plant, due: Date) async throws -> Reminder {
        let dueAt = ISO8601DateFormatter().string(from: due)
        let amountLabel = plant.wateringAmountMl.map { UnitsFormatting.waterAmount(ml: $0) }
        if let existing = reminders.first(where: { $0.plantId == plant.id && $0.type == "watering" && !$0.isCompleted }) {
            try await reschedule(existing, to: due)
            return reminders.first(where: { $0.id == existing.id }) ?? existing
        }
        return try await addReminder(
            NewReminder(
                userId: userId,
                plantId: plant.id,
                type: "watering",
                dueAt: dueAt,
                amountLabel: amountLabel
            )
        )
    }

    func snooze(_ reminder: Reminder, days: Int = 1) async {
        let newDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        do {
            try await reschedule(reminder, to: newDate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reschedule(_ reminder: Reminder, to date: Date) async throws {
        let iso = ISO8601DateFormatter().string(from: date)
        if isGuest {
            if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[idx].dueAt = iso
                reminders.sort { $0.dueAt < $1.dueAt }
                LocalGardenStore.saveReminders(reminders, userId: localUserId)
            }
            return
        }
        struct Patch: Encodable { var due_at: String }
        try await SupabaseManager.client.from("reminders").update(Patch(due_at: iso)).eq("id", value: reminder.id).execute()
        if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[idx].dueAt = iso
            reminders.sort { $0.dueAt < $1.dueAt }
        }
    }

    // MARK: - Demo seed (signed-in / Supabase)

    private func seedDemoDataIfNeeded(userId: UUID) async {
        if seededUserIds.contains(userId) { return }
        seededUserIds.insert(userId)
        guard let existing = try? await fetchPlants(userId: userId), existing.isEmpty else { return }

        for (index, seed) in Self.demoSeeds.enumerated() {
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
                wateringAmountMl: seed.amount,
                placement: index.isMultiple(of: 2) ? .indoor : .balcony
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
        guard LocalGardenStore.loadPlants(userId: userId).isEmpty else { return }
        var seededPlants: [Plant] = []
        var seededReminders: [Reminder] = []

        for (index, seed) in Self.demoSeeds.enumerated() {
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
                placement: index.isMultiple(of: 2) ? .indoor : .balcony,
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
        LocalGardenStore.savePlants(seededPlants, userId: userId)
        LocalGardenStore.saveReminders(seededReminders, userId: userId)
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
