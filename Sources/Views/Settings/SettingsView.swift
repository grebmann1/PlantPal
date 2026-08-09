import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var garden: GardenStore
    @Environment(\.appTheme) private var theme

    @AppStorage("pp.wateringReminders") private var wateringReminders = true
    @AppStorage("pp.scanNudges") private var scanNudges = true
    @AppStorage("pp.unitsMetric") private var unitsMetric = true
    @AppStorage("pp.darkMode") private var darkModeOn = false
    @AppStorage("pp.reminderTime") private var reminderTimeRaw = 27000.0 // seconds since midnight, 07:30 default

    @State private var showHelp = false
    @State private var isSigningOut = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Circle()
                        .fill(theme.primary.opacity(0.15))
                        .frame(width: 52, height: 52)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(theme.primary))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.userEmail ?? "Plant keeper").font(theme.headlineFont).foregroundStyle(theme.textPrimary)
                        Text("Keeper of \(garden.plants.count) specimens").font(theme.footnoteFont).foregroundStyle(theme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Notifications") {
                Toggle("Watering reminders", isOn: $wateringReminders)
                Toggle("Health scan nudges", isOn: $scanNudges)
                DatePicker("Daily reminder time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
            }

            Section("Preferences") {
                Picker("Units", selection: $unitsMetric) {
                    Text("Metric").tag(true)
                    Text("Imperial").tag(false)
                }
                Toggle("Dark mode", isOn: $darkModeOn)
            }

            Section("Support") {
                Button("Help & contact") { showHelp = true }
                    .foregroundStyle(theme.textPrimary)
                HStack {
                    Text("App version")
                    Spacer()
                    Text("v1.0 \u{00B7} build 1").foregroundStyle(theme.textSecondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        isSigningOut = true
                        await appState.signOut()
                        isSigningOut = false
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isSigningOut { ProgressView() } else { Text("Sign out") }
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showHelp) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Need help?").font(theme.title2Font)
                    Text("Reach us at support@plantpal.app for anything about identification accuracy, watering schedules, or your account.")
                        .font(theme.subheadFont)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
                .padding(20)
                .navigationTitle("Help & contact")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showHelp = false }
                    }
                }
            }
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: Int(reminderTimeRaw) / 3600, minute: (Int(reminderTimeRaw) % 3600) / 60, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderTimeRaw = Double((comps.hour ?? 7) * 3600 + (comps.minute ?? 30) * 60)
            }
        )
    }
}
