import SwiftUI

struct RemindersView: View {
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @State private var showAddSheet = false
    @State private var rescheduleTarget: Reminder?
    @State private var rescheduleDate = Date()

    private var overdue: [Reminder] {
        pending
            .filter {
                due($0) < Calendar.current.startOfDay(for: Date())
                    && !Calendar.current.isDateInToday(due($0))
            }
            .sorted { due($0) < due($1) }
    }

    private var todayPending: [Reminder] {
        todayAll.filter { !$0.isCompleted }.sorted { due($0) < due($1) }
    }

    private var todayDone: [Reminder] {
        todayAll.filter(\.isCompleted).sorted { due($0) < due($1) }
    }

    /// Today's reminders (pending first, then completed).
    private var today: [Reminder] {
        todayPending + todayDone
    }

    private var todayAll: [Reminder] {
        garden.reminders.filter { Calendar.current.isDateInToday(due($0)) }
    }

    private var upcoming: [Reminder] {
        pending
            .filter { due($0) > endOfToday }
            .sorted { due($0) < due($1) }
    }

    private var pending: [Reminder] { garden.reminders.filter { !$0.isCompleted } }
    private var endOfToday: Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
    }

    private var weekNumber: Int {
        Calendar.current.component(.weekOfYear, from: Date())
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .topTrailing) {
                LeafWatermark(opacity: 0.08, rotation: -22, color: theme.primary)
                    .frame(width: 160, height: 200)
                    .offset(x: 40, y: -10)

                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    if garden.reminders.isEmpty {
                        emptyState
                            .padding(.horizontal, 20)
                    } else if pending.isEmpty && todayDone.isEmpty {
                        allCaughtUp
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    } else if pending.isEmpty {
                        allCaughtUp
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                        if !today.isEmpty {
                            ledgerSection(
                                title: "TODAY · \(todayHeading)",
                                countLabel: todayCountLabel,
                                tint: theme.primary,
                                background: theme.surfaceSunken,
                                rail: theme.primary.opacity(0.30),
                                reminders: today,
                                kind: .today
                            )
                        }
                    } else {
                        if !overdue.isEmpty {
                            ledgerSection(
                                title: "OVERDUE",
                                countLabel: "\(overdue.count)",
                                tint: theme.error,
                                background: theme.error.opacity(0.08),
                                rail: theme.error.opacity(0.40),
                                reminders: overdue,
                                kind: .overdue
                            )
                        }
                        if !today.isEmpty {
                            ledgerSection(
                                title: "TODAY · \(todayHeading)",
                                countLabel: todayCountLabel,
                                tint: theme.primary,
                                background: theme.surfaceSunken,
                                rail: theme.primary.opacity(0.30),
                                reminders: today,
                                kind: .today
                            )
                        }
                        if !upcoming.isEmpty {
                            ledgerSection(
                                title: "UPCOMING",
                                countLabel: "\(upcoming.count)",
                                tint: theme.textSecondary,
                                background: theme.accent.opacity(0.12),
                                rail: theme.textTertiary.opacity(0.55),
                                reminders: upcoming,
                                kind: .upcoming,
                                dashedRail: true
                            )
                        }
                    }

                    addReminderCTA
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                        .padding(.bottom, 28)
                }
            }
        }
        .background(theme.background.ignoresSafeArea())
        .accessibilityIdentifier("reminders-screen")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { EmptyView() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(theme.primary)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddReminderSheet(plants: garden.plants) { newReminder in
                Task {
                    do {
                        _ = try await garden.addReminder(newReminder)
                    } catch {
                        garden.errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .sheet(item: $rescheduleTarget) { reminder in
            RescheduleReminderSheet(date: $rescheduleDate) {
                Task {
                    do {
                        try await garden.reschedule(reminder, to: rescheduleDate)
                    } catch {
                        garden.errorMessage = error.localizedDescription
                    }
                }
                rescheduleTarget = nil
            } onCancel: {
                rescheduleTarget = nil
            }
        }
    }

    private var todayCountLabel: String {
        if todayPending.isEmpty && !todayDone.isEmpty {
            return "\(todayDone.count) done"
        }
        if !todayDone.isEmpty {
            return "\(todayPending.count) due"
        }
        return "\(todayPending.count)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WATERING LEDGER · WEEK \(weekNumber)")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(theme.textTertiary)

            Text("Reminders")
                .font(theme.title1Font)
                .foregroundStyle(theme.primary)

            HStack(spacing: 8) {
                Text("\(overdue.count) overdue")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                Text("·").foregroundStyle(theme.textTertiary)
                Text("\(todayPending.count) due today")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                Text("·").foregroundStyle(theme.textTertiary)
                Text("\(upcoming.count) upcoming")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.top, 4)
        }
    }

    private var todayHeading: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: Date()).uppercased()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "drop")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(theme.primary)
            Text("No reminders yet")
                .font(theme.headlineFont)
                .foregroundStyle(theme.textPrimary)
            Text("Add one after scanning a plant, or create a reminder manually.")
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                Text("Add reminder")
                    .font(theme.headlineFont)
                    .foregroundStyle(theme.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
            .clipShape(Capsule())
            .disabled(garden.plants.isEmpty)

            Button {
                coordinator.goToScan(mode: .identify)
            } label: {
                Text("Scan a plant")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.primary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(theme.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
    }

    private var allCaughtUp: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(theme.success)
            Text("All caught up")
                .font(theme.headlineFont)
                .foregroundStyle(theme.textPrimary)
            Text("Nothing overdue. Enjoy the quiet garden.")
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(theme.success.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
    }

    private var addReminderCTA: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack(spacing: 12) {
                Text("＋")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add custom reminder")
                        .font(theme.headlineFont)
                        .foregroundStyle(theme.textPrimary)
                    Text("WATERING · FEEDING · MISTING")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.md)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(theme.primary.opacity(0.45))
            )
        }
        .buttonStyle(.plain)
        .disabled(garden.plants.isEmpty)
        .opacity(garden.plants.isEmpty ? 0.45 : 1)
    }

    private enum SectionKind { case overdue, today, upcoming }

    private func ledgerSection(
        title: String,
        countLabel: String,
        tint: Color,
        background: Color,
        rail: Color,
        reminders: [Reminder],
        kind: SectionKind,
        dashedRail: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(tint)
                Spacer()
                Text(countLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint.opacity(0.85))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(tint.opacity(kind == .overdue ? 0.16 : kind == .today ? 0.12 : 0.10))
            .overlay(alignment: .top) { Rectangle().fill(theme.separator).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(theme.separator).frame(height: 1) }

            ZStack(alignment: .topLeading) {
                timelineRail(color: rail, dashed: dashedRail)
                    .padding(.leading, 32)

                VStack(spacing: 0) {
                    ForEach(Array(reminders.enumerated()), id: \.element.id) { index, reminder in
                        reminderBlock(reminder, kind: kind, background: background, isLast: index == reminders.count - 1)
                    }
                }
            }
            .background(background)
        }
    }

    private func timelineRail(color: Color, dashed: Bool) -> some View {
        Group {
            if dashed {
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: 1, y: 0))
                    path.addLine(to: CGPoint(x: 1, y: size.height))
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                    )
                }
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 2)
            }
        }
        .frame(width: 2)
        .frame(maxHeight: .infinity)
    }

    private func reminderBlock(_ reminder: Reminder, kind: SectionKind, background: Color, isLast: Bool) -> some View {
        let plant = plantFor(reminder)
        let showActions = !reminder.isCompleted && (kind == .overdue || kind == .today)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                checkControl(for: reminder, kind: kind, ground: background)
                    .frame(width: 26)

                Button {
                    coordinator.goToPlantDetail(reminder.plantId, from: .reminders)
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        RemotePhoto(path: plant?.photoUrl)
                            .frame(width: 46, height: 56)
                            .clipped()
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.white.opacity(0.85), lineWidth: 3)
                            )
                            .appElevation(AppTheme.Shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rowTitle(reminder, plant: plant))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(reminder.isCompleted ? theme.textSecondary : theme.textPrimary)
                                .strikethrough(reminder.isCompleted, color: theme.textSecondary)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                if let plant, !reminder.isCompleted {
                                    Circle().fill(dotColor(plant)).frame(width: 7, height: 7)
                                }
                                if reminder.isCompleted {
                                    Text(doneSubline(reminder))
                                        .font(theme.footnoteFont)
                                        .foregroundStyle(theme.textSecondary)
                                } else if let latin = plant?.speciesLatinName {
                                    Text(latin)
                                        .italic()
                                        .font(theme.footnoteFont)
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(1)
                                } else if let note = typeNote(reminder) {
                                    Text(note)
                                        .font(theme.footnoteFont)
                                        .foregroundStyle(theme.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(UnitsFormatting.waterAmount(label: reminder.amountLabel))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(reminder.isCompleted ? theme.textSecondary : theme.textPrimary)
                    Text(dueLabel(reminder))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(dueColor(reminder, kind: kind))
                }
                .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.top, showActions ? 10 : 12)
            .padding(.bottom, showActions ? 8 : 12)

            if showActions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        actionChip(
                            title: completionLabel(for: reminder),
                            filled: true
                        ) {
                            Task { await garden.markWatered(reminder) }
                        }
                        actionChip(title: "Snooze 1d", filled: false, muted: true) {
                            Task { await garden.snooze(reminder) }
                        }
                        actionChip(title: "Reschedule", filled: false, muted: true) {
                            rescheduleDate = due(reminder)
                            rescheduleTarget = reminder
                        }
                    }
                    .padding(.leading, 56)
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 12)
            }

            if !isLast || showActions {
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)
            }
        }
    }

    private func checkControl(for reminder: Reminder, kind: SectionKind, ground: Color) -> some View {
        Button {
            guard !reminder.isCompleted else { return }
            Task { await garden.markWatered(reminder) }
        } label: {
            ZStack {
                // Punch a hole in the rail so the check sits on the timeline
                Circle()
                    .fill(ground)
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(reminder.isCompleted ? theme.primary : Color.clear)
                    .overlay(
                        Circle().stroke(
                            reminder.isCompleted
                                ? theme.primary
                                : (kind == .overdue ? theme.error : theme.textTertiary),
                            lineWidth: 1.5
                        )
                    )
                    .frame(width: 26, height: 26)
                if reminder.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.onPrimary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(reminder.isCompleted)
        .accessibilityLabel(reminder.isCompleted ? "Completed" : "Mark complete")
    }

    private func actionChip(title: String, filled: Bool, muted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(filled ? theme.onPrimary : (muted ? theme.textSecondary : theme.primary))
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(filled ? theme.primary : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        filled
                            ? theme.primary
                            : (muted ? theme.textTertiary.opacity(0.55) : theme.primary.opacity(0.40)),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func rowTitle(_ reminder: Reminder, plant: Plant?) -> String {
        let name = plant?.nickname ?? "Plant"
        switch reminder.type {
        case "feeding":
            return "\(name) — feed"
        case "custom":
            return "\(name) — mist"
        default:
            return name
        }
    }

    private func typeNote(_ reminder: Reminder) -> String? {
        switch reminder.type {
        case "feeding": return "Liquid fertiliser"
        case "custom": return "Misting / custom care"
        default: return nil
        }
    }

    private func doneSubline(_ reminder: Reminder) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "\(completedVerb(for: reminder)) \(f.string(from: due(reminder)))"
    }

    private func completionLabel(for reminder: Reminder) -> String {
        switch reminder.type {
        case "feeding": return "Mark fed"
        case "custom": return "Mark misted"
        default: return "Water now"
        }
    }

    private func completedVerb(for reminder: Reminder) -> String {
        switch reminder.type {
        case "feeding": return "Fed"
        case "custom": return "Misted"
        default: return "Watered"
        }
    }

    private func due(_ reminder: Reminder) -> Date {
        GardenStore.dateTimeFormatter.date(from: reminder.dueAt)
            ?? ISO8601DateFormatter().date(from: reminder.dueAt)
            ?? Date()
    }

    private func plantFor(_ reminder: Reminder) -> Plant? {
        garden.plants.first(where: { $0.id == reminder.plantId })
    }

    private func dueLabel(_ reminder: Reminder) -> String {
        if reminder.isCompleted { return "Done" }
        let date = due(reminder)
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        if days < 0 { return "\(-days) day\(-days == 1 ? "" : "s") late" }
        if days == 0 {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return "by \(f.string(from: date))"
        }
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }

    private func dueColor(_ reminder: Reminder, kind: SectionKind) -> Color {
        if reminder.isCompleted { return theme.textSecondary }
        if kind == .overdue { return theme.error }
        return theme.textTertiary
    }

    private func dotColor(_ plant: Plant) -> Color {
        switch plant.healthStatus {
        case .healthy: return theme.success
        case .needsAttention: return theme.warning
        case .atRisk: return theme.error
        }
    }
}

private struct RescheduleReminderSheet: View {
    @Binding var date: Date
    var onSave: () -> Void
    var onCancel: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("New date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .tint(theme.primary)
                    .padding()
                Spacer()
            }
            .background(theme.background)
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

private struct AddReminderSheet: View {
    let plants: [Plant]
    var onAdd: (NewReminder) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @Environment(\.appTheme) private var theme

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
                    Text("Misting").tag("custom")
                }
                DatePicker("Due", selection: $date)
                    .tint(theme.primary)
                TextField("Amount label (optional)", text: $amount)
            }
            .navigationTitle("Add reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let userId = appState.effectiveUserId, let plantId = selectedPlantId else { return }
                        onAdd(NewReminder(
                            userId: userId,
                            plantId: plantId,
                            type: type,
                            dueAt: ISO8601DateFormatter().string(from: date),
                            amountLabel: amount.isEmpty ? nil : amount
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.primary)
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
