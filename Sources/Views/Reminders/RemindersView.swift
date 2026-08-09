import SwiftUI

struct RemindersView: View {
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @State private var showAddSheet = false
    @State private var rescheduleTarget: Reminder?
    @State private var rescheduleDate = Date()

    private var overdue: [Reminder] { pending.filter { due($0) < Calendar.current.startOfDay(for: Date()) && !Calendar.current.isDateInToday(due($0)) } }
    private var today: [Reminder] { garden.reminders.filter { Calendar.current.isDateInToday(due($0)) } }
    private var upcoming: [Reminder] { pending.filter { due($0) > endOfToday } }

    private var pending: [Reminder] { garden.reminders.filter { !$0.isCompleted } }
    private var endOfToday: Date { Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date() }

    var body: some View {
        List {
            if !overdue.isEmpty {
                Section("Overdue \u{00B7} \(overdue.count)") {
                    ForEach(overdue) { reminder in row(reminder) }
                }
            }
            if !today.isEmpty {
                Section("Today") {
                    ForEach(today) { reminder in row(reminder) }
                }
            }
            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { reminder in row(reminder) }
                }
            }
            if garden.reminders.isEmpty {
                Section {
                    Text("No reminders yet. Add one after scanning a plant.")
                        .font(theme.subheadFont)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Reminders")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddReminderSheet(plants: garden.plants) { newReminder in
                Task { _ = try? await garden.addReminder(newReminder) }
            }
        }
        .sheet(item: $rescheduleTarget) { reminder in
            NavigationStack {
                VStack {
                    DatePicker("New date", selection: $rescheduleDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .padding()
                    Spacer()
                }
                .navigationTitle("Reschedule")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await garden.reschedule(reminder, to: rescheduleDate) }
                            rescheduleTarget = nil
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { rescheduleTarget = nil }
                    }
                }
            }
        }
    }

    private func due(_ reminder: Reminder) -> Date {
        ISO8601DateFormatter().date(from: reminder.dueAt) ?? Date()
    }

    private func plantFor(_ reminder: Reminder) -> Plant? {
        garden.plants.first(where: { $0.id == reminder.plantId })
    }

    private func row(_ reminder: Reminder) -> some View {
        let plant = plantFor(reminder)
        return Button {
            coordinator.goToPlantDetail(reminder.plantId, from: .reminders)
        } label: {
            HStack(spacing: 12) {
                RemotePhoto(path: plant?.photoUrl)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(plant?.nickname ?? "Plant").font(theme.headlineFont).foregroundStyle(theme.textPrimary)
                    Text(dueLabel(reminder)).font(theme.footnoteFont).foregroundStyle(reminder.isCompleted ? theme.success : theme.textSecondary)
                    if let amount = reminder.amountLabel {
                        Text(amount).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(theme.textTertiary)
                    }
                }
                Spacer()
                if !reminder.isCompleted {
                    VStack(spacing: 6) {
                        Button("Water now") { Task { await garden.markWatered(reminder) } }
                            .font(.system(size: 11))
                            .buttonStyle(.borderedProminent)
                            .tint(theme.primary)
                            .controlSize(.mini)
                        HStack(spacing: 6) {
                            Button("Snooze") { Task { await garden.snooze(reminder) } }
                                .font(.system(size: 10))
                            Button("Reschedule") {
                                rescheduleDate = due(reminder)
                                rescheduleTarget = reminder
                            }
                            .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.primary)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.success)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func dueLabel(_ reminder: Reminder) -> String {
        if reminder.isCompleted { return "Watered" }
        let date = due(reminder)
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days < 0 { return "\(-days)d late" }
        if days == 0 {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return "Due by \(f.string(from: date))"
        }
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }
}

private struct AddReminderSheet: View {
    let plants: [Plant]
    var onAdd: (NewReminder) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var selectedPlantId: UUID?
    @State private var type = "watering"
    @State private var date = Date()
    @State private var amount = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Plant", selection: $selectedPlantId) {
                    ForEach(plants) { plant in
                        Text(plant.nickname).tag(plant.id as UUID?)
                    }
                }
                Picker("Type", selection: $type) {
                    Text("Watering").tag("watering")
                    Text("Feeding").tag("feeding")
                    Text("Custom").tag("custom")
                }
                DatePicker("Due", selection: $date)
                TextField("Amount label (optional)", text: $amount)
            }
            .navigationTitle("Add reminder")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let userId = appState.effectiveUserId, let plantId = selectedPlantId else { return }
                        onAdd(NewReminder(userId: userId, plantId: plantId, type: type, dueAt: ISO8601DateFormatter().string(from: date), amountLabel: amount.isEmpty ? nil : amount))
                        dismiss()
                    }
                    .disabled(selectedPlantId == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { if selectedPlantId == nil { selectedPlantId = plants.first?.id } }
        }
    }
}
