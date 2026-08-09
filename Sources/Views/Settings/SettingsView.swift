import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var garden: GardenStore
    @EnvironmentObject private var coordinator: Coordinator
    @Environment(\.appTheme) private var theme

    @AppStorage("pp.wateringReminders") private var wateringReminders = true
    @AppStorage("pp.scanNudges") private var scanNudges = false
    @AppStorage("pp.unitsMetric") private var unitsMetric = true
    @AppStorage("pp.darkMode") private var darkModeOn = false
    @AppStorage("pp.reminderTime") private var reminderTimeRaw = 27000.0
    @AppStorage("pp.homeRegion") private var homeRegion = "Lisbon, PT"
    @AppStorage(AppLanguage.Keys.appLanguage) private var appLanguageRaw = AppLanguage.system.rawValue

    @State private var showAuth = false
    @State private var showAccountInfo = false
    @State private var showHelp = false
    @State private var showAbout = false
    @State private var showTimePicker = false
    @State private var showRegionPicker = false
    @State private var showLanguagePicker = false
    @State private var showShareSheet = false
    @State private var isSigningOut = false
    @State private var shareText = ""

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }
    private var displayName: String {
        if let email = appState.userEmail, let local = email.split(separator: "@").first {
            return local.replacingOccurrences(of: ".", with: " ").capitalized
        }
        return appState.isGuest ? "Guest keeper" : "Plant keeper"
    }

    private var reminderTimeLabel: String {
        let total = Int(reminderTimeRaw)
        return String(format: "%02d:%02d", total / 3600, (total % 3600) / 60)
    }

    private var signOutLabel: String {
        if appState.session != nil {
            return "Sign out"
        }
        return "End guest session"
    }

    private var hasRealSession: Bool { appState.session != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button {
                    if hasRealSession {
                        showAccountInfo = true
                    } else {
                        showAuth = true
                    }
                } label: {
                    profileHeader
                }
                .buttonStyle(.plain)

                sectionCap("Watering & reminders")
                settingsGroup {
                    toggleRow(
                        mark: "leaf.fill",
                        title: "Watering reminders",
                        subtitle: "Push notifications on this device",
                        isOn: $wateringReminders
                    )
                    Button { showTimePicker = true } label: {
                        trailRow(
                            mark: "clock",
                            title: "Daily reminder time",
                            subtitle: "Grouped into one morning digest",
                            trail: reminderTimeLabel
                        )
                    }
                    .buttonStyle(.plain)
                    toggleRow(
                        mark: "sparkles",
                        title: "Health scan nudges",
                        subtitle: "Every 30 days per plant",
                        isOn: $scanNudges
                    )
                }

                sectionCap("Field measurements")
                settingsGroup {
                    unitsRow
                    Button { showLanguagePicker = true } label: {
                        trailRow(
                            mark: "globe",
                            title: "Language",
                            subtitle: "English, Français, Deutsch",
                            trail: appLanguage.shortLabel
                        )
                    }
                    .buttonStyle(.plain)
                    toggleRow(
                        mark: "moon.fill",
                        title: "Dark mode",
                        subtitle: darkModeOn ? "Dark appearance is on" : "Follows system appearance",
                        isOn: $darkModeOn
                    )
                    Button { showRegionPicker = true } label: {
                        trailRow(
                            mark: "house.fill",
                            title: "Home location",
                            subtitle: "Where you live — frost dates & light hours",
                            trail: homeRegion
                        )
                    }
                    .buttonStyle(.plain)
                }

                sectionCap("Notebook & support")
                settingsGroup {
                    Button {
                        shareText = exportSummary()
                        showShareSheet = true
                    } label: {
                        trailRow(mark: "square.and.arrow.down", title: "Export garden journal", subtitle: nil, trail: nil)
                    }
                    .buttonStyle(.plain)
                    Button { showHelp = true } label: {
                        trailRow(mark: "questionmark", title: "Help & contact", subtitle: nil, trail: nil)
                    }
                    .buttonStyle(.plain)
                    Button { showAbout = true } label: {
                        trailRow(mark: "info", title: "About PlantPal", subtitle: nil, trail: nil)
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task {
                            isSigningOut = true
                            await appState.signOut()
                            isSigningOut = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            markBadge("arrow.uturn.backward")
                            Text(isSigningOut ? "Signing out…" : signOutLabel)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(theme.error)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningOut)
                }

                VStack(spacing: 4) {
                    Text("Pressed & catalogued since 2024")
                        .font(theme.footnoteFont)
                        .foregroundStyle(theme.textTertiary)
                    Text("v1.0 \u{00B7} build 1")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
        }
        .background {
            ZStack(alignment: .bottomTrailing) {
                theme.background
                JournalPaperBackground(showMarginRail: false)
                LeafWatermark(opacity: 0.08, rotation: 20, color: theme.primary)
                    .frame(width: 200, height: 240)
                    .offset(x: 50, y: 40)
            }
            .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAuth) {
            NavigationStack {
                AuthView(postSignInTab: .settings)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showAuth = false }
                        }
                    }
            }
            .environmentObject(appState)
            .environmentObject(coordinator)
        }
        .sheet(isPresented: $showAccountInfo) { accountInfoSheet }
        .sheet(isPresented: $showHelp) { helpSheet }
        .sheet(isPresented: $showAbout) { aboutSheet }
        .sheet(isPresented: $showTimePicker) { timePickerSheet }
        .sheet(isPresented: $showRegionPicker) {
            HomeLocationPicker(selection: $homeRegion) {
                showRegionPicker = false
            }
        }
        .sheet(isPresented: $showLanguagePicker) { languagePickerSheet }
        .sheet(isPresented: $showShareSheet) {
            ActivityShareSheet(activityItems: [shareText])
        }
        .onAppear { Task { await rescheduleNotifications() } }
        .onChange(of: wateringReminders) { _, _ in Task { await rescheduleNotifications() } }
        .onChange(of: scanNudges) { _, _ in Task { await rescheduleNotifications() } }
        .onChange(of: reminderTimeRaw) { _, _ in Task { await rescheduleNotifications() } }
    }

    // MARK: - Profile

    private var profileHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Ellipse()
                    .fill(theme.primary.opacity(0.18))
                    .frame(width: 58, height: 68)
                    .rotationEffect(.degrees(-8))
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(theme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(theme.primary)
                Text(appState.userEmail ?? (appState.isGuest ? "Local guest session" : "No email on file"))
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.textSecondary)
                Text("KEEPER OF \(garden.plants.count) SPECIMENS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.primary.opacity(0.8))
                    .padding(.top, 2)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(theme.surfaceSunken)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1)
        }
    }

    // MARK: - Rows

    private func sectionCap(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 8)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    private func markBadge(_ systemImage: String) -> some View {
        ZStack {
            Circle()
                .fill(theme.secondary.opacity(0.22))
                .frame(width: 30, height: 30)
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.primary)
        }
    }

    private func toggleRow(mark: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            markBadge(mark)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(theme.textPrimary)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(theme.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1).padding(.leading, 56)
        }
    }

    private func trailRow(mark: String, title: String, subtitle: String?, trail: String?) -> some View {
        HStack(spacing: 12) {
            markBadge(mark)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(theme.textPrimary)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            if let trail {
                Text(trail)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1).padding(.leading, 56)
        }
    }

    private var unitsRow: some View {
        HStack(spacing: 12) {
            markBadge("ruler")
            Text("Units")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            HStack(spacing: 0) {
                unitPill("METRIC", selected: unitsMetric) { unitsMetric = true }
                unitPill("IMPERIAL", selected: !unitsMetric) { unitsMetric = false }
            }
            .padding(3)
            .background(theme.surfaceSunken)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1).padding(.leading, 56)
        }
    }

    private func unitPill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? theme.primary : Color.clear)
                .foregroundStyle(selected ? theme.onPrimary : theme.textSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sheets

    private var accountInfoSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(displayName).font(theme.title2Font).foregroundStyle(theme.primary)
                Text(appState.userEmail ?? "Signed in")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textSecondary)
                Text("Your garden syncs to this account across devices.")
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            }
            .padding(20)
            .journalPaperBackground(showMarginRail: false)
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showAccountInfo = false }.foregroundStyle(theme.primary)
                }
            }
        }
    }

    private var helpSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Need help?").font(theme.title2Font).foregroundStyle(theme.primary)
                Text("Reach us for anything about identification accuracy, watering schedules, or your account.")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textSecondary)
                if let mailURL = URL(string: "mailto:support@plantpal.app") {
                    Link("support@plantpal.app", destination: mailURL)
                        .font(theme.headlineFont)
                        .foregroundStyle(theme.primary)
                }
                Spacer()
            }
            .padding(20)
            .journalPaperBackground(showMarginRail: false)
            .navigationTitle("Help & contact")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showHelp = false }.foregroundStyle(theme.primary)
                }
            }
        }
    }

    private var aboutSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("PlantPal").font(.system(size: 28, weight: .bold, design: .serif)).foregroundStyle(theme.primary)
                Text("A field journal for living specimens — identify, diagnose, and keep a watering ledger.")
                    .font(theme.subheadFont)
                    .foregroundStyle(theme.textSecondary)
                Text("v1.0 · build 1")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            }
            .padding(20)
            .journalPaperBackground(showMarginRail: false)
            .navigationTitle("About PlantPal")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showAbout = false }.foregroundStyle(theme.primary)
                }
            }
        }
    }

    private var timePickerSheet: some View {
        NavigationStack {
            DatePicker("Daily reminder", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .tint(theme.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .navigationTitle("Reminder time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showTimePicker = false }.foregroundStyle(theme.primary)
                    }
                }
        }
        .presentationDetents([.medium])
    }

    private var languagePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        appLanguageRaw = language.rawValue
                        AppLanguage.apply(language)
                        showLanguagePicker = false
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            if appLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Language")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLanguagePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: Int(reminderTimeRaw) / 3600,
                    minute: (Int(reminderTimeRaw) % 3600) / 60,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderTimeRaw = Double((comps.hour ?? 7) * 3600 + (comps.minute ?? 30) * 60)
            }
        )
    }

    private func exportSummary() -> String {
        let lines = garden.plants.map { plant in
            "• \(plant.nickname) (\(plant.speciesLatinName ?? "unknown")) — \(plant.placement.label) — next water \(plant.nextWateringDate ?? "—")"
        }
        return "Exported \(garden.plants.count) specimens:\n" + (lines.isEmpty ? "No plants yet." : lines.joined(separator: "\n"))
    }

    private func rescheduleNotifications() async {
        await NotificationService.reschedule(
            wateringEnabled: wateringReminders,
            scanNudgesEnabled: scanNudges,
            reminderTimeSeconds: reminderTimeRaw,
            plants: garden.plants
        )
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
