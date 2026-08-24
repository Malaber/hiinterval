import SwiftUI
import HiIntervalCore

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    let onSave: (WorkoutPlan) -> Void

    @State private var plan: WorkoutPlan
    @State private var exerciseDestination: ExerciseEditorDestination?
    @State private var showsRoundOverrides = false
    @State private var exerciseEditMode: EditMode = .inactive

    init(plan: WorkoutPlan, isNew: Bool, onSave: @escaping (WorkoutPlan) -> Void) {
        _plan = State(initialValue: plan)
        self.isNew = isNew
        self.onSave = onSave
    }

    private var validationMessage: String? {
        PlanFormatting.validationMessage(for: plan)
    }

    private var timeline: WorkoutTimeline? {
        try? WorkoutTimeline(plan: plan)
    }

    var body: some View {
        List {
            previewSection
            identitySection
            timingSection
            roundsSection
            exercisesSection
            finishSection
        }
        .listSectionSpacing(18)
        .scrollDismissesKeyboard(.interactively)
        .environment(\.editMode, $exerciseEditMode)
        .navigationTitle(isNew ? "New plan" : "Edit plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("plan.editor.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(validationMessage != nil)
                    .accessibilityIdentifier("plan.editor.save")
            }
        }
        .onChange(of: plan.roundCount) { _, roundCount in
            plan.roundOverrides.removeAll { $0.roundNumber > roundCount }
        }
        .sheet(item: $exerciseDestination) { destination in
            NavigationStack {
                ExerciseEditorView(
                    exercise: destination.exercise,
                    defaultWorkSeconds: plan.defaultWorkSeconds,
                    defaultRecoverySeconds: plan.defaultRecoverySeconds,
                    isNew: destination.index == nil
                ) { exercise in
                    saveExercise(exercise, at: destination.index)
                    exerciseDestination = nil
                }
            }
            .tint(PlanPalette.accent)
        }
        .sheet(isPresented: $showsRoundOverrides) {
            NavigationStack {
                RoundOverridesEditorView(
                    roundCount: plan.roundCount,
                    defaultWorkSeconds: plan.defaultWorkSeconds,
                    overrides: $plan.roundOverrides
                )
            }
            .tint(PlanPalette.accent)
        }
        .accessibilityIdentifier("plan.editor.screen")
    }

    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [PlanPalette.secondary, PlanPalette.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "waveform.path.ecg")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(timeline.map { PlanFormatting.duration($0.totalDurationSeconds) } ?? "—")
                            .font(.system(.title, design: .rounded, weight: .bold).monospacedDigit())
                        Text("estimated workout")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 0) {
                    PlanMetric(icon: "repeat", value: "\(plan.roundCount)", label: "Rounds")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PlanMetric(icon: "figure.run", value: "\(plan.exercises.count)", label: "Exercises")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PlanMetric(icon: "square.stack.3d.up", value: "\(timeline?.phases.count ?? 0)", label: "Intervals")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let validationMessage {
                    ValidationBanner(message: validationMessage)
                }
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(Color.clear)
        .accessibilityIdentifier("plan.editor.preview")
    }

    private var identitySection: some View {
        Section("Plan name") {
            TextField("e.g. Lower-body power", text: $plan.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .accessibilityIdentifier("plan.editor.name")
        }
    }

    private var timingSection: some View {
        Section {
            PlanDurationStepper(
                "Warm-up",
                subtitle: "Before round one",
                seconds: $plan.warmUpSeconds,
                accessibilityID: "plan.editor.warmup"
            )
            PlanDurationStepper(
                "Default work",
                subtitle: "Can be changed per exercise or round",
                seconds: $plan.defaultWorkSeconds,
                range: 1...3_600,
                accessibilityID: "plan.editor.work"
            )
            PlanDurationStepper(
                "Default recovery",
                subtitle: "After each exercise",
                seconds: $plan.defaultRecoverySeconds,
                accessibilityID: "plan.editor.recovery"
            )
        } header: {
            Text("Core timing")
        } footer: {
            Text("Exercise settings take priority over these defaults. Round overrides take priority during their round.")
        }
    }

    private var roundsSection: some View {
        Section {
            Stepper(value: $plan.roundCount, in: 1...50) {
                HStack {
                    Text("Rounds")
                    Spacer()
                    Text("\(plan.roundCount)")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(PlanPalette.secondary)
                }
            }
            .accessibilityIdentifier("plan.editor.rounds")

            PlanDurationStepper(
                "Between rounds",
                seconds: $plan.roundRecoverySeconds,
                accessibilityID: "plan.editor.roundRecovery"
            )

            Button {
                showsRoundOverrides = true
            } label: {
                HStack {
                    Label("Customize individual rounds", systemImage: "square.3.layers.3d.down.right")
                    Spacer()
                    if !plan.roundOverrides.isEmpty {
                        Text("\(plan.roundOverrides.count)")
                            .font(.caption.bold())
                            .foregroundStyle(PlanPalette.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PlanPalette.secondary.opacity(0.14), in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityIdentifier("plan.editor.roundOverrides")
        } header: {
            Text("Rounds")
        } footer: {
            Text("Round overrides can change work duration or switch every exercise to left/right for one round.")
        }
    }

    private var exercisesSection: some View {
        Section {
            ForEach(Array(plan.exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseRow(exercise: exercise, plan: plan, index: index) {
                    exerciseDestination = ExerciseEditorDestination(exercise: exercise, index: index)
                }
                .accessibilityIdentifier("plan.editor.exercise.\(index)")
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        plan.exercises.remove(at: index)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("plan.editor.exercise.delete.\(index)")
                }
            }
            .onMove { offsets, destination in
                plan.exercises.move(fromOffsets: offsets, toOffset: destination)
            }
            .onDelete { offsets in
                plan.exercises.remove(atOffsets: offsets)
            }

            Button {
                exerciseDestination = ExerciseEditorDestination(
                    exercise: ExerciseStep(name: ""),
                    index: nil
                )
            } label: {
                Label("Add exercise", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
            }
            .accessibilityIdentifier("plan.editor.exercise.add")
        } header: {
            HStack {
                Text("Exercises")
                Spacer()
                if plan.exercises.count > 1 {
                    Button(exerciseEditMode == .active ? "Done" : "Reorder") {
                        withAnimation {
                            exerciseEditMode = exerciseEditMode == .active ? .inactive : .active
                        }
                    }
                    .textCase(nil)
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("plan.editor.exercise.reorder")
                }
            }
        } footer: {
            Text("Tap an exercise for custom work, recovery, notes, and left/right timing.")
        }
    }

    private var finishSection: some View {
        Section("Finish") {
            PlanDurationStepper(
                "Cool-down",
                subtitle: "After the final round",
                seconds: $plan.coolDownSeconds,
                accessibilityID: "plan.editor.cooldown"
            )
        }
    }

    private func saveExercise(_ exercise: ExerciseStep, at index: Int?) {
        if let index, plan.exercises.indices.contains(index) {
            plan.exercises[index] = exercise
        } else {
            plan.exercises.append(exercise)
        }
    }

    private func save() {
        guard validationMessage == nil else { return }
        plan.name = plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.exercises = plan.exercises.map { exercise in
            var copy = exercise
            copy.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.notes = copy.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            return copy
        }
        plan.updatedAt = Date()
        onSave(plan)
    }
}

private struct ExerciseEditorDestination: Identifiable {
    let id = UUID()
    let exercise: ExerciseStep
    let index: Int?
}

private struct ExerciseRow: View {
    let exercise: ExerciseStep
    let plan: WorkoutPlan
    let index: Int
    let action: () -> Void

    private var workSeconds: Int {
        exercise.resolvedWorkSeconds(default: plan.defaultWorkSeconds)
    }

    private var recoverySeconds: Int {
        exercise.resolvedRecoverySeconds(default: plan.defaultRecoverySeconds)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(PlanPalette.secondary)
                    .frame(width: 30, height: 30)
                    .background(PlanPalette.secondary.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text(PlanFormatting.compactDuration(workSeconds))
                        Text("work")
                        Text("·")
                        Text(recoverySeconds == 0 ? "no recovery" : "\(PlanFormatting.compactDuration(recoverySeconds)) recovery")
                        if exercise.sideConfiguration.mode == .leftRight {
                            Text("·")
                            Label("split", systemImage: "arrow.left.arrow.right")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Exercise \(index + 1), \(exercise.name)")
        .accessibilityValue("\(workSeconds) seconds work, \(recoverySeconds) seconds recovery\(exercise.sideConfiguration.mode == .leftRight ? ", left and right split" : "")")
        .accessibilityHint("Opens exercise settings")
    }
}
