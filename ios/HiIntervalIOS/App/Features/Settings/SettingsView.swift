import HiIntervalCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var reminderMessage: String?
    @State private var reminderTask: Task<Void, Never>?

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
            .hiStableScrollContrast()
            .safeAreaPadding(.bottom, 48)
            .navigationTitle("Settings")
        }
        .accessibilityIdentifier("settings.screen")
    }

    private var accessSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "infinity")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Unlimited early access")
                        .font(.headline)
                        .foregroundStyle(settingsTextColor)
                    Text("Everything is free. Future purchase rules are disabled.")
                        .font(.caption)
                        .foregroundStyle(settingsTextColor)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.free-status")
        } header: {
            settingsHeader("Access")
        }
    }

    private var cuesSection: some View {
        Section {
            Picker(selection: preferenceBinding(\.cueStyle)) {
                Text("Tones").tag(CueStyle.tones)
                Text("Spoken").tag(CueStyle.spoken)
                Text("Silent").tag(CueStyle.silent)
            } label: {
                Text("Audio cues")
                    .foregroundStyle(settingsTextColor)
            }
            .pickerStyle(.navigationLink)
            .tint(.primary)
            .accessibilityIdentifier("settings.cues")

            if store.data.preferences.cueStyle == .spoken {
                Picker("Spoken language", selection: preferenceBinding(\.cueLanguage)) {
                    Text("System").tag(CueLanguage.system)
                    Text("English").tag(CueLanguage.english)
                    Text("Deutsch").tag(CueLanguage.german)
                }
                .tint(.primary)
                .accessibilityIdentifier("settings.cue-language")
            }

            Toggle("Haptic cues", isOn: preferenceBinding(\.hapticsEnabled))
                .accessibilityIdentifier("settings.haptics")
            Toggle("Lower other audio during cues", isOn: preferenceBinding(\.duckOtherAudio))
                .accessibilityIdentifier("settings.duck-audio")
            Toggle("Final three-second countdown", isOn: preferenceBinding(\.countdownEnabled))
                .accessibilityIdentifier("settings.countdown")

            settingsNote("Spoken cues can follow device language or use English or German.")
                .accessibilityIdentifier("settings.cues-note")
        } header: {
            settingsHeader("Cues")
        }
    }

    private var behaviorSection: some View {
        Section {
            Toggle(isOn: preferenceBinding(\.pauseWhenInactive)) {
                Text("Pause when app leaves foreground")
                    .foregroundStyle(settingsTextColor)
            }
            .accessibilityIdentifier("settings.pause-background")
            Toggle(isOn: preferenceBinding(\.keepScreenAwake)) {
                Text("Keep screen awake during workouts")
                    .fontWeight(.semibold)
                    .foregroundStyle(settingsTextColor)
            }
            .accessibilityIdentifier("settings.keep-awake")

            settingsNote("If background pause is off, elapsed time catches up when HiInterval returns; cues resume in the app.")
                .accessibilityIdentifier("settings.background-behavior-note")
        } header: {
            settingsHeader("Workout behavior")
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle(isOn: reminderEnabledBinding) {
                Text("Workout reminders")
                    .foregroundStyle(settingsTextColor)
            }
                .accessibilityIdentifier("settings.reminders")

            if store.data.preferences.reminders.enabled {
                HStack(spacing: 7) {
                    ForEach(weekdays, id: \.0) { weekday, label in
                        Button {
                            toggleWeekday(weekday)
                        } label: {
                            Text(label)
                                .font(.subheadline.weight(.bold))
                                .frame(width: 44, height: 44)
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
                    .foregroundStyle(.primary)
            }

            settingsNote("Reminders repeat weekly and stay entirely on this device.")
        } header: {
            settingsHeader("Scheduled reminders")
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Theme", selection: preferenceBinding(\.appearance)) {
                Text("System").tag(AppearancePreference.system)
                Text("Light").tag(AppearancePreference.light)
                Text("Dark").tag(AppearancePreference.dark)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.appearance")
        } header: {
            settingsHeader("Appearance")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("App", value: "HiInterval")
            LabeledContent("Version", value: version)
            LabeledContent("Storage", value: "On device")
            settingsNote("No account, tracking, ads, or network connection required.")
        } header: {
            settingsHeader("About")
        }
    }

    private func settingsHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.bold)
            .textCase(nil)
            .foregroundStyle(settingsTextColor)
            .accessibilityAddTraits(.isHeader)
    }

    private func settingsNote(_ message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.bold))
            .foregroundStyle(settingsTextColor)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
            .padding(.vertical, 2)
    }

    private var settingsTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black
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
        reminderTask?.cancel()
        reminderTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(200))
                let accepted = try await store.reminders.synchronize(settings: settings)
                guard !Task.isCancelled else { return }
                reminderMessage = accepted
                    ? (settings.enabled ? "Reminder schedule updated." : nil)
                    : "Notification permission is disabled. Enable it in iOS Settings."
            } catch is CancellationError {
                return
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
