import HiIntervalCore
import SwiftUI
import UIKit

struct WorkoutThemeEditor: View {
    let initialTheme: WorkoutTheme
    let hapticsEnabled: Bool
    let save: (WorkoutTheme) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkoutTheme
    @State private var selectedPreviewPhase: PreviewPhase = .work

    init(
        initialTheme: WorkoutTheme,
        hapticsEnabled: Bool,
        save: @escaping (WorkoutTheme) -> Void
    ) {
        self.initialTheme = initialTheme
        self.hapticsEnabled = hapticsEnabled
        self.save = save
        _draft = State(initialValue: initialTheme)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Phase", selection: $selectedPreviewPhase) {
                        ForEach(PreviewPhase.allCases, id: \.self) { phase in
                            Text(phase.title).tag(phase)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("settings.workout-theme.preview-phase")

                    WorkoutSessionPreview(
                        scenario: selectedPreviewPhase.scenario,
                        theme: draft,
                        hapticsEnabled: hapticsEnabled,
                        accessibilityIdentifier: "settings.workout-theme.preview"
                    )
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

    private enum PreviewPhase: String, CaseIterable, Hashable {
        case work
        case recovery
        case warmUp
        case roundRecovery
        case sideSwitch

        var title: String {
            switch self {
            case .work: "Work"
            case .recovery: "Recovery"
            case .warmUp: "Warm-up / cool-down"
            case .roundRecovery: "Round recovery"
            case .sideSwitch: "Side switch"
            }
        }

        var scenario: WorkoutSessionPreviewScenario {
            switch self {
            case .work: .work
            case .recovery: .recovery
            case .warmUp: .warmUp
            case .roundRecovery: .roundRecovery
            case .sideSwitch: .sideSwitch
            }
        }
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
