import SwiftUI
import HiIntervalCore

struct ExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let defaultWorkSeconds: Int
    let defaultRecoverySeconds: Int
    let isNew: Bool
    let onSave: (ExerciseStep) -> Void

    @State private var exercise: ExerciseStep

    init(
        exercise: ExerciseStep,
        defaultWorkSeconds: Int,
        defaultRecoverySeconds: Int,
        isNew: Bool,
        onSave: @escaping (ExerciseStep) -> Void
    ) {
        _exercise = State(initialValue: exercise)
        self.defaultWorkSeconds = defaultWorkSeconds
        self.defaultRecoverySeconds = defaultRecoverySeconds
        self.isNew = isNew
        self.onSave = onSave
    }

    private var resolvedWorkSeconds: Int {
        exercise.resolvedWorkSeconds(default: defaultWorkSeconds)
    }

    private var resolvedRecoverySeconds: Int {
        exercise.resolvedRecoverySeconds(default: defaultRecoverySeconds)
    }

    private var validationMessage: String? {
        if exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter an exercise name."
        }
        if resolvedWorkSeconds <= 0 {
            return "Work duration must be at least one second."
        }
        if exercise.sideConfiguration.mode == .leftRight, resolvedWorkSeconds < 2 {
            return "Left/right exercises need at least two seconds."
        }
        return nil
    }

    var body: some View {
        Form {
            previewSection
            nameSection
            durationSection
            recoverySection
            sideSection
            notesSection
        }
        .navigationTitle(isNew ? "Add exercise" : "Edit exercise")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("exercise.editor.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: save)
                    .fontWeight(.semibold)
                    .disabled(validationMessage != nil)
                    .accessibilityIdentifier("exercise.editor.save")
            }
        }
        .accessibilityIdentifier("exercise.editor.screen")
    }

    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: exercise.sideConfiguration.mode == .leftRight ? "arrow.left.arrow.right" : "figure.strengthtraining.traditional")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(
                            LinearGradient(
                                colors: [PlanPalette.secondary, PlanPalette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name.isEmpty ? "New exercise" : exercise.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(previewDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if let validationMessage {
                    ValidationBanner(message: validationMessage)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
        .accessibilityIdentifier("exercise.editor.preview")
    }

    private var nameSection: some View {
        Section("Exercise") {
            TextField("Exercise name", text: $exercise.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .accessibilityIdentifier("exercise.editor.name")
        }
    }

    private var durationSection: some View {
        Section {
            Picker("Work duration", selection: durationChoice) {
                Text("Plan default").tag(WorkDurationChoice.planDefault)
                Text("Custom").tag(WorkDurationChoice.custom)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("exercise.editor.duration.mode")

            if durationChoice.wrappedValue == .custom {
                PlanDurationStepper(
                    "Custom work",
                    seconds: customWorkSeconds,
                    range: 1...3_600,
                    accessibilityID: "exercise.editor.duration.custom"
                )
            } else {
                LabeledContent("Current plan default") {
                    Text(PlanFormatting.compactDuration(defaultWorkSeconds))
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(PlanPalette.accent)
                }
            }
        } header: {
            Text("Work")
        } footer: {
            Text("Custom time applies only to this exercise unless a round override is active.")
        }
    }

    private var recoverySection: some View {
        Section {
            Picker("Recovery", selection: recoveryChoice) {
                Text("Default").tag(RecoveryChoice.planDefault)
                Text("Custom").tag(RecoveryChoice.custom)
                Text("None").tag(RecoveryChoice.none)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("exercise.editor.recovery.mode")

            switch recoveryChoice.wrappedValue {
            case .planDefault:
                LabeledContent("Current plan default") {
                    Text(PlanFormatting.compactDuration(defaultRecoverySeconds))
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(PlanPalette.accent)
                }
            case .custom:
                PlanDurationStepper(
                    "Custom recovery",
                    seconds: customRecoverySeconds,
                    accessibilityID: "exercise.editor.recovery.custom"
                )
            case .none:
                Label("Next exercise starts immediately", systemImage: "forward.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("After exercise")
        }
    }

    private var sideSection: some View {
        Section {
            Picker("Training style", selection: $exercise.sideConfiguration.mode) {
                Text("Together").tag(SideMode.together)
                Text("Left + right").tag(SideMode.leftRight)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("exercise.editor.side.mode")

            if exercise.sideConfiguration.mode == .leftRight {
                Picker("Start on", selection: $exercise.sideConfiguration.firstSide) {
                    ForEach(WorkoutSide.allCases, id: \.self) { side in
                        Text(PlanFormatting.sideLabel(side)).tag(side)
                    }
                }
                .accessibilityIdentifier("exercise.editor.side.first")

                PlanDurationStepper(
                    "Time to switch",
                    subtitle: "Inserted between sides",
                    seconds: $exercise.sideConfiguration.switchSeconds,
                    range: 0...300,
                    step: 1,
                    accessibilityID: "exercise.editor.side.switch"
                )

                HStack(spacing: 10) {
                    sideDurationPill(
                        side: exercise.sideConfiguration.firstSide,
                        seconds: (resolvedWorkSeconds + 1) / 2
                    )
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    sideDurationPill(
                        side: exercise.sideConfiguration.firstSide.opposite,
                        seconds: resolvedWorkSeconds / 2
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("exercise.editor.side.preview")
            }
        } header: {
            Text("Sides")
        } footer: {
            if exercise.sideConfiguration.mode == .leftRight {
                Text("Work time is split as evenly as possible. Switch time is extra and does not reduce either side.")
            } else {
                Text("Use left + right when each side should get its own timed interval.")
            }
        }
    }

    private var notesSection: some View {
        Section("Notes (optional)") {
            TextField("Technique, equipment, or target reps", text: $exercise.notes, axis: .vertical)
                .lineLimit(2...5)
                .accessibilityIdentifier("exercise.editor.notes")
        }
    }

    private var previewDescription: String {
        var parts = ["\(PlanFormatting.compactDuration(resolvedWorkSeconds)) work"]
        if exercise.sideConfiguration.mode == .leftRight {
            parts.append("split sides")
        }
        parts.append(resolvedRecoverySeconds == 0 ? "no recovery" : "\(PlanFormatting.compactDuration(resolvedRecoverySeconds)) recovery")
        return parts.joined(separator: " · ")
    }

    private var durationChoice: Binding<WorkDurationChoice> {
        Binding {
            switch exercise.duration {
            case .planDefault: .planDefault
            case .custom: .custom
            }
        } set: { choice in
            switch choice {
            case .planDefault:
                exercise.duration = .planDefault
            case .custom:
                exercise.duration = .custom(seconds: max(1, resolvedWorkSeconds))
            }
        }
    }

    private var customWorkSeconds: Binding<Int> {
        Binding {
            if case let .custom(seconds) = exercise.duration { return seconds }
            return max(1, defaultWorkSeconds)
        } set: { seconds in
            exercise.duration = .custom(seconds: seconds)
        }
    }

    private var recoveryChoice: Binding<RecoveryChoice> {
        Binding {
            switch exercise.recovery {
            case .planDefault: .planDefault
            case .custom: .custom
            case .none: .none
            }
        } set: { choice in
            switch choice {
            case .planDefault:
                exercise.recovery = .planDefault
            case .custom:
                exercise.recovery = .custom(seconds: resolvedRecoverySeconds)
            case .none:
                exercise.recovery = .none
            }
        }
    }

    private var customRecoverySeconds: Binding<Int> {
        Binding {
            if case let .custom(seconds) = exercise.recovery { return seconds }
            return defaultRecoverySeconds
        } set: { seconds in
            exercise.recovery = .custom(seconds: seconds)
        }
    }

    private func sideDurationPill(side: WorkoutSide, seconds: Int) -> some View {
        VStack(spacing: 3) {
            Text(PlanFormatting.sideLabel(side))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(PlanFormatting.compactDuration(seconds))
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(PlanPalette.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
    }

    private func save() {
        guard validationMessage == nil else { return }
        exercise.name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.notes = exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(exercise)
    }
}

private enum WorkDurationChoice: Hashable {
    case planDefault
    case custom
}

private enum RecoveryChoice: Hashable {
    case planDefault
    case custom
    case none
}
