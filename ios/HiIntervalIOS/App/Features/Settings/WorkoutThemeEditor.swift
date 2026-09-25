import HiIntervalCore
import SwiftUI
import UIKit

struct WorkoutThemeEditor: View {
    let initialTheme: WorkoutTheme
    let save: (WorkoutTheme) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkoutTheme

    init(initialTheme: WorkoutTheme, save: @escaping (WorkoutTheme) -> Void) {
        self.initialTheme = initialTheme
        self.save = save
        _draft = State(initialValue: initialTheme)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    WorkoutThemePreview(theme: draft)
                        .accessibilityIdentifier("settings.workout-theme.preview")
                } header: {
                    Text("Preview")
                } footer: {
                    Text("These colors apply to every running workout. Text color adapts for contrast.")
                }

                Section("Presets") {
                    ForEach(WorkoutThemePreset.allCases, id: \.self) { preset in
                        Button {
                            draft = preset.theme
                        } label: {
                            HStack(spacing: 12) {
                                WorkoutThemeSwatches(theme: preset.theme)
                                Text(preset.displayName)
                                Spacer()
                                if draft == preset.theme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(HITheme.accentStrong)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("settings.workout-theme.preset.\(preset.rawValue)")
                        .accessibilityValue(draft == preset.theme ? "Selected" : "Not selected")
                    }
                }

                if !draft.hasDistinctWorkAndRecovery {
                    Text("Choose more distinct work and recovery colors so phases remain easy to recognize.")
                        .foregroundStyle(.secondary)
                }
                Section("Custom colors") {
                    ColorPicker("Work", selection: colorBinding(\.workColor), supportsOpacity: false)
                        .accessibilityIdentifier("settings.workout-theme.work")
                    ColorPicker("Recovery", selection: colorBinding(\.recoveryColor), supportsOpacity: false)
                        .accessibilityIdentifier("settings.workout-theme.recovery")
                    ColorPicker("Transitions", selection: colorBinding(\.transitionColor), supportsOpacity: false)
                        .accessibilityIdentifier("settings.workout-theme.transition")
                    ColorPicker("Round recovery", selection: colorBinding(\.roundRecoveryColor), supportsOpacity: false)
                        .accessibilityIdentifier("settings.workout-theme.round-recovery")
                    ColorPicker("Side switch", selection: colorBinding(\.sideSwitchColor), supportsOpacity: false)
                        .accessibilityIdentifier("settings.workout-theme.side-switch")
                }
            }
            .navigationTitle("Workout colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("settings.workout-theme.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(draft)
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.workout-theme.save")
                    .disabled(!draft.hasDistinctWorkAndRecovery)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset to default", role: .destructive) {
                        draft = .default
                    }
                    .accessibilityIdentifier("settings.workout-theme.reset")
                }
            }
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<WorkoutTheme, WorkoutLogoColor>) -> Binding<Color> {
        Binding(
            get: { Color(draft[keyPath: keyPath]) },
            set: { draft[keyPath: keyPath] = WorkoutLogoColor($0) }
        )
    }
}

private struct WorkoutThemePreview: View {
    let theme: WorkoutTheme

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            WorkoutThemePreviewPhase(title: "Work", color: theme.workColor, usesDarkText: theme.prefersDarkText(for: theme.workColor))
            WorkoutThemePreviewPhase(title: "Recover", color: theme.recoveryColor, usesDarkText: theme.prefersDarkText(for: theme.recoveryColor))
            WorkoutThemePreviewPhase(title: "Warm-up / cool-down", color: theme.transitionColor, usesDarkText: theme.prefersDarkText(for: theme.transitionColor))
            WorkoutThemePreviewPhase(title: "Round recovery", color: theme.roundRecoveryColor, usesDarkText: theme.prefersDarkText(for: theme.roundRecoveryColor))
            WorkoutThemePreviewPhase(title: "Side switch", color: theme.sideSwitchColor, usesDarkText: theme.prefersDarkText(for: theme.sideSwitchColor))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout color preview")
    }
}

private struct WorkoutThemePreviewPhase: View {
    let title: String
    let color: WorkoutLogoColor
    let usesDarkText: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(6)
            .foregroundStyle(usesDarkText ? Color.black : Color.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color(color), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WorkoutThemeSwatches: View {
    let theme: WorkoutTheme

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(Color(theme.workColor))
            Circle().fill(Color(theme.recoveryColor))
            Circle().fill(Color(theme.transitionColor))
            Circle().fill(Color(theme.roundRecoveryColor))
            Circle().fill(Color(theme.sideSwitchColor))
        }
        .frame(width: 72, height: 16)
        .accessibilityHidden(true)
    }
}

private extension WorkoutLogoColor {
    init(_ color: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}
