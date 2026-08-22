import HiIntervalCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var reminderMessage: String?

    private let weekdays: [(Int, String)] = [
        (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                accessSection
                cuesSection
                behaviorSection
                remindersSection
                appearanceSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
        .accessibilityIdentifier("settings.screen")
    }

    private var accessSection: some View {
        Section("Access") {
            HStack(spacing: 14) {
                Image(systemName: "infinity")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Unlimited early access")
                        .font(.headline)
                    Text("Everything is free. Future purchase rules are disabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.free-status")
        }
    }

    private var cuesSection: some View {
        Section {
            Picker("Audio cues", selection: preferenceBinding(\.cueStyle)) {
                Label("Tones", systemImage: "bell.fill").tag(CueStyle.tones)
                Label("Spoken", systemImage: "waveform").tag(CueStyle.spoken)
                Label("Silent", systemImage: "speaker.slash.fill").tag(CueStyle.silent)
            }
            .pickerStyle(.navigationLink)
            .accessibilityIdentifier("settings.cues")

            if store.data.preferences.cueStyle == .spoken {
                Picker("Spoken language", selection: preferenceBinding(\.cueLanguage)) {
                    Text("System").tag(CueLanguage.system)
                    Text("English").tag(CueLanguage.english)
                    Text("Deutsch").tag(CueLanguage.german)
                }
                .accessibilityIdentifier("settings.cue-language")
            }

            Toggle("Haptic cues", isOn: preferenceBinding(\.hapticsEnabled))
                .accessibilityIdentifier("settings.haptics")
            Toggle("Final three-second countdown", isOn: preferenceBinding(\.countdownEnabled))
                .accessibilityIdentifier("settings.countdown")
        } header: {
            Text("Cues")
        } footer: {
            Text("Spoken cues can follow device language or use English or German.")
        }
    }

    private var behaviorSection: some View {
        Section("Workout behavior") {
            Toggle("Pause when app leaves foreground", isOn: preferenceBinding(\.pauseWhenInactive))
                .accessibilityIdentifier("settings.pause-background")
            Toggle("Keep screen awake during workouts", isOn: preferenceBinding(\.keepScreenAwake))
                .accessibilityIdentifier("settings.keep-awake")
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle("Workout reminders", isOn: reminderEnabledBinding)
                .accessibilityIdentifier("settings.reminders")

            if store.data.preferences.reminders.enabled {
                HStack(spacing: 7) {
                    ForEach(weekdays, id: \.0) { weekday, label in
                        Button {
                            toggleWeekday(weekday)
                        } label: {
                            Text(label)
                                .font(.subheadline.weight(.bold))
                                .frame(width: 34, height: 34)
                                .foregroundStyle(
                                    store.data.preferences.reminders.weekdays.contains(weekday)
                                        ? Color(uiColor: .systemBackground)
                                        : Color.primary
                                )
                                .background(
                                    store.data.preferences.reminders.weekdays.contains(weekday)
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.15),
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(weekdayName(weekday))
                        .accessibilityValue(
                            store.data.preferences.reminders.weekdays.contains(weekday)
                                ? "Selected"
                                : "Not selected"
                        )
                        .accessibilityIdentifier("settings.weekday.\(weekday)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                DatePicker(
                    "Time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityIdentifier("settings.reminder-time")
            }

            if let reminderMessage {
                Text(reminderMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Scheduled reminders")
        } footer: {
            Text("Reminders repeat weekly and stay entirely on this device.")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: preferenceBinding(\.appearance)) {
                Text("System").tag(AppearancePreference.system)
                Text("Light").tag(AppearancePreference.light)
                Text("Dark").tag(AppearancePreference.dark)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.appearance")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("App", value: "HiInterval")
            LabeledContent("Version", value: version)
            LabeledContent("Storage", value: "On device")
        } header: {
            Text("About")
        } footer: {
            Text("No account, tracking, ads, or network connection required.")
        }
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func preferenceBinding<Value>(_ keyPath: WritableKeyPath<UserPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { store.data.preferences[keyPath: keyPath] },
            set: { value in
                var preferences = store.data.preferences
                preferences[keyPath: keyPath] = value
                store.updatePreferences(preferences)
            }
        )
    }

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.data.preferences.reminders.enabled },
            set: { enabled in
                var preferences = store.data.preferences
                preferences.reminders.enabled = enabled
                if enabled, preferences.reminders.weekdays.isEmpty {
                    preferences.reminders.weekdays = [2, 4, 6]
                }
                store.updatePreferences(preferences)
                schedule(preferences.reminders)
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                let settings = store.data.preferences.reminders
                return Calendar.current.date(
                    bySettingHour: settings.hour,
                    minute: settings.minute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                var preferences = store.data.preferences
                preferences.reminders.hour = components.hour ?? 18
                preferences.reminders.minute = components.minute ?? 0
                store.updatePreferences(preferences)
                schedule(preferences.reminders)
            }
        )
    }

    private func toggleWeekday(_ weekday: Int) {
        var preferences = store.data.preferences
        if preferences.reminders.weekdays.contains(weekday) {
            preferences.reminders.weekdays.remove(weekday)
        } else {
            preferences.reminders.weekdays.insert(weekday)
        }
        store.updatePreferences(preferences)
        schedule(preferences.reminders)
    }

    private func schedule(_ settings: ReminderSettings) {
        Task {
            do {
                let accepted = try await store.reminders.synchronize(settings: settings)
                reminderMessage = accepted
                    ? (settings.enabled ? "Reminder schedule updated." : nil)
                    : "Notification permission is disabled. Enable it in iOS Settings."
            } catch {
                reminderMessage = error.localizedDescription
            }
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard (1...symbols.count).contains(weekday) else { return "Day" }
        return symbols[weekday - 1]
    }
}
