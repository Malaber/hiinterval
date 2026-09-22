import SwiftUI
import HiIntervalCore

/// The reusable exercise library. Planning metadata lives here and is deliberately
/// kept out of the timer experience.
struct ExerciseCatalogueView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    @State private var query = ""
    @State private var editor: CatalogueEditorDestination?
    @State private var selectedIDs = Set<UUID>()
    @State private var selectionMode = false
    @State private var showsMergeConfirmation = false
    @State private var exercisePendingDeletion: CatalogueExercise?
    @State private var deletionAfterEditorDismissal: CatalogueExercise?
    private let onChoose: ((CatalogueExercise) -> Void)?

    init(onChoose: ((CatalogueExercise) -> Void)? = nil) {
        self.onChoose = onChoose
    }

    private var filteredExercises: [CatalogueExercise] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return store.data.exerciseCatalogue }
        return store.data.exerciseCatalogue.filter {
            $0.name.localizedCaseInsensitiveContains(needle)
                || store.data.labels(for: $0).contains { $0.name.localizedCaseInsensitiveContains(needle) }
        }
    }

    var body: some View {
        List {
            if store.data.exerciseCatalogue.isEmpty {
                ContentUnavailableView(
                    "Your exercise catalogue is empty",
                    systemImage: "square.stack.3d.up",
                    description: Text("Add exercises once, then use them in plans and generated workouts.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filteredExercises) { exercise in
                        catalogueRow(exercise)
                    }
                } footer: {
                    Text("Body areas and tags help build balanced workouts. They never appear during a workout.")
                }
            }
            if let error = store.lastErrorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .searchable(text: $query, prompt: "Search exercises, areas, or tags")
        .navigationTitle("Exercise catalogue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("catalogue.done")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = CatalogueEditorDestination(exercise: nil)
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
                .accessibilityIdentifier("catalogue.add")
            }
            ToolbarItem(placement: .topBarTrailing) {
                if onChoose == nil, !store.data.exerciseCatalogue.isEmpty {
                    Button(selectionMode ? "Cancel selection" : "Select") {
                        selectionMode.toggle()
                        if !selectionMode { selectedIDs.removeAll() }
                    }
                    .accessibilityIdentifier("catalogue.select")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                if onChoose == nil, selectedIDs.count >= 2 {
                    Button {
                        showsMergeConfirmation = true
                    } label: {
                        Label("Merge \(selectedIDs.count) exercises", systemImage: "arrow.triangle.merge")
                    }
                    .accessibilityIdentifier("catalogue.merge")
                }
            }
        }
        .sheet(item: $editor, onDismiss: {
            if let exercise = deletionAfterEditorDismissal {
                deletionAfterEditorDismissal = nil
                exercisePendingDeletion = exercise
            }
        }) { destination in
            NavigationStack {
                CatalogueExerciseEditorView(
                    exercise: destination.exercise,
                    labels: destination.exercise.map { store.data.labels(for: $0) } ?? [],
                    onDelete: { requestDeletion($0) }
                ) { saved, labels in
                    if store.saveCatalogueExercise(saved, labels: labels) { editor = nil }
                }
            }
            .tint(PlanPalette.accent)
        }
        .confirmationDialog(
            "Merge selected exercises?",
            isPresented: $showsMergeConfirmation,
            titleVisibility: .visible
        ) {
            ForEach(selectedExercises) { target in
                Button(mergeTargetLabel(target)) {
                    guard store.mergeCatalogueExercises(sourceIDs: selectedIDs, into: target.id) else { return }
                    selectedIDs.removeAll()
                    selectionMode = false
                    showsMergeConfirmation = false
                }
                .accessibilityIdentifier("catalogue.merge.target.\(target.id.uuidString)")
            }
            Button("Cancel", role: .cancel) { showsMergeConfirmation = false }
        } message: {
            Text("Choose the name and defaults to keep. Tags and body areas are combined. Existing plan timing, notes, and workout history stay exactly as they are.")
                .accessibilityIdentifier("catalogue.merge.confirm")
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: deletionDialogIsPresented,
            titleVisibility: .visible
        ) {
            Button("Delete exercise", role: .destructive) {
                guard let exercise = exercisePendingDeletion else { return }
                if store.deleteCatalogueExercise(id: exercise.id) {
                    selectedIDs.remove(exercise.id)
                    exercisePendingDeletion = nil
                }
            }
            .accessibilityIdentifier("catalogue.delete.confirm")
            Button("Cancel", role: .cancel) { exercisePendingDeletion = nil }
                .accessibilityIdentifier("catalogue.delete.cancel")
        } message: {
            Text(deletionMessage)
                .accessibilityIdentifier("catalogue.delete.warning")
        }
        .onAppear { store.clearError() }
        .accessibilityIdentifier("catalogue.screen")
    }

    private var selectedExercises: [CatalogueExercise] {
        store.data.exerciseCatalogue.filter { selectedIDs.contains($0.id) }
    }

    private func catalogueRow(_ exercise: CatalogueExercise) -> some View {
        Button {
            if let onChoose {
                onChoose(exercise)
                dismiss()
            } else if !selectionMode {
                editor = CatalogueEditorDestination(exercise: exercise)
            } else {
                toggleSelection(exercise.id)
            }
        } label: {
            HStack(spacing: 12) {
                if selectionMode || !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: selectedIDs.contains(exercise.id) ? "checkmark.circle.fill" : (selectionMode ? "circle" : "figure.strengthtraining.traditional"))
                        .foregroundStyle(selectedIDs.contains(exercise.id) ? PlanPalette.accent : PlanPalette.secondary)
                        .font(.title3)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text(exercise.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                    let labels = store.data.labels(for: exercise)
                    if !labels.isEmpty {
                        HIPillLayout(spacing: 6) {
                            ForEach(labels) { label in
                                Text(label.name)
                                    .font(.caption)
                                    .foregroundStyle(HITheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }
                    let plans = linkedPlans(for: exercise.id)
                    if !plans.isEmpty {
                        HIPillLayout(spacing: 6) {
                            ForEach(plans) { plan in
                                workoutPill(plan, exerciseID: exercise.id)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !selectionMode && !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(selectionMode ? "catalogue.select.\(exercise.id.uuidString)" : "catalogue.row.\(exercise.id.uuidString)")
        .accessibilityValue(selectionMode ? (selectedIDs.contains(exercise.id) ? "Selected for merge" : "Not selected for merge") : "")
        .contextMenu {
            if onChoose == nil, !selectionMode {
                Button(role: .destructive) {
                    requestDeletion(exercise)
                } label: {
                    Label("Delete exercise", systemImage: "trash")
                }
                .accessibilityIdentifier("catalogue.delete.\(exercise.id.uuidString)")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if onChoose == nil, !selectionMode {
                Button(role: .destructive) { requestDeletion(exercise) } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("catalogue.delete.\(exercise.id.uuidString)")
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func workoutPill(_ plan: WorkoutPlan, exerciseID: UUID) -> some View {
        let tint = PlanPalette.workoutTint(for: plan.id)
        return HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(plan.name)
                .foregroundStyle(HITheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(colorScheme == .dark ? 0.14 : 0.09), in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(tint.opacity(0.15)) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Used in \(plan.name)")
        .accessibilityIdentifier("catalogue.usage.\(exerciseID.uuidString).\(plan.id.uuidString)")
    }

    private func linkedPlans(for catalogueID: UUID) -> [WorkoutPlan] {
        store.data.plans.filter { plan in
            plan.exercises.contains { $0.catalogueExerciseID == catalogueID }
        }
    }

    private func mergeTargetLabel(_ exercise: CatalogueExercise) -> String {
        let plans = linkedPlans(for: exercise.id).map(\.name)
        let context = plans.isEmpty ? "Catalogue only" : plans.joined(separator: ", ")
        return "Keep \(exercise.name) · \(context)"
    }

    private func requestDeletion(_ exercise: CatalogueExercise) {
        if editor != nil {
            deletionAfterEditorDismissal = exercise
            editor = nil
        } else {
            exercisePendingDeletion = exercise
        }
    }

    private var deletionDialogIsPresented: Binding<Bool> {
        Binding(
            get: { exercisePendingDeletion != nil },
            set: { if !$0 { exercisePendingDeletion = nil } }
        )
    }

    private var deletionTitle: String {
        guard let exercise = exercisePendingDeletion else { return "Delete exercise?" }
        return "Delete \(exercise.name)?"
    }

    private var deletionMessage: String {
        guard let exercise = exercisePendingDeletion else { return "" }
        let plans = linkedPlans(for: exercise.id).map(\.name)
        guard !plans.isEmpty else {
            return "This removes the exercise from the catalogue. Existing workout steps and completed workout history stay unchanged."
        }
        return "Used in \(plans.joined(separator: ", ")). Its steps keep their timing, sides, notes, and name. Completed workout history stays unchanged."
    }
}

private struct CatalogueEditorDestination: Identifiable {
    let id = UUID()
    let exercise: CatalogueExercise?
}

struct CatalogueExerciseEditorView: View {
    private enum Field: Hashable { case name }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @FocusState private var focusedField: Field?
    let onSave: (CatalogueExercise, [ExerciseLabel]) -> Void
    let onDelete: ((CatalogueExercise) -> Void)?
    private let isNew: Bool
    @State private var exercise: CatalogueExercise
    @State private var selectedLabels: [ExerciseLabel]
    @State private var bodyAreasText = ""
    @State private var tagsText = ""
    @State private var showsDefaultsEditor = false

    init(
        exercise: CatalogueExercise?,
        labels: [ExerciseLabel] = [],
        onDelete: ((CatalogueExercise) -> Void)? = nil,
        onSave: @escaping (CatalogueExercise, [ExerciseLabel]) -> Void
    ) {
        let entry = exercise ?? CatalogueExercise(name: "")
        _exercise = State(initialValue: entry)
        _selectedLabels = State(initialValue: labels)
        self.isNew = exercise == nil
        self.onDelete = onDelete
        self.onSave = onSave
    }

    private var isValid: Bool { !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Form {
            Section {
                TextField("Exercise name", text: $exercise.name)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .accessibilityIdentifier("catalogue.editor.name")
            } header: {
                Text("Exercise")
            } footer: {
                Text("Renaming updates every linked saved plan. Timing, sides, and notes below are defaults for new uses; existing plan settings and completed workouts stay unchanged.")
            }
            ExerciseLabelPicker(
                kind: .bodyArea,
                available: store.data.exerciseLabels,
                selection: $selectedLabels,
                query: $bodyAreasText
            )
            ExerciseLabelPicker(
                kind: .tag,
                available: store.data.exerciseLabels,
                selection: $selectedLabels,
                query: $tagsText
            )
            Section("Exercise defaults") {
                Button { showsDefaultsEditor = true } label: {
                    Label("Set timing, sides, and notes", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("catalogue.editor.defaults")
                Text(defaultsSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let error = store.lastErrorMessage {
                Section { ValidationBanner(message: error) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { store.clearError() }
        .navigationTitle(isNew ? "Add catalogue exercise" : "Edit catalogue exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("catalogue.editor.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).fontWeight(.semibold).disabled(!isValid)
                    .accessibilityIdentifier("catalogue.editor.save")
            }
            if !isNew, let onDelete {
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete exercise", role: .destructive) { onDelete(exercise) }
                        .accessibilityIdentifier("catalogue.editor.delete")
                }
            }
        }
        .task {
            guard isNew else { return }
            try? await Task.sleep(for: .milliseconds(350))
            if !Task.isCancelled { focusedField = .name }
        }
        .sheet(isPresented: $showsDefaultsEditor) {
            NavigationStack {
                ExerciseEditorView(
                    exercise: exercise.makeStep(),
                    defaultWorkSeconds: 40,
                    defaultRecoverySeconds: 20,
                    isNew: false,
                    suggestsCatalogue: false
                ) { edited in
                    exercise.name = edited.name
                    exercise.duration = edited.duration
                    exercise.recovery = edited.recovery
                    exercise.sideConfiguration = edited.sideConfiguration
                    exercise.notes = edited.notes
                    showsDefaultsEditor = false
                }
            }
            .tint(PlanPalette.accent)
        }
        .accessibilityIdentifier("catalogue.editor.screen")
    }

    private func save() {
        exercise.name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Save also commits unfinished single-label input, so leaving the keyboard open never
        // loses a label. The store resolves draft IDs against its shared catalogue atomically.
        for (name, kind) in [(bodyAreasText, ExerciseLabel.Kind.bodyArea), (tagsText, .tag)] {
            if let label = ExerciseLabelPicker.resolveLabel(
                name: name,
                kind: kind,
                available: store.data.exerciseLabels + selectedLabels
            ), !selectedLabels.contains(where: { $0.id == label.id }) {
                selectedLabels.append(label)
            }
        }
        exercise.labelIDs = selectedLabels.map(\.id)
        onSave(exercise, selectedLabels)
    }

    private var defaultsSummary: String {
        let work = exercise.duration == .planDefault ? "Plan work default" : "Custom work"
        let sides = exercise.sideConfiguration.mode == .leftRight ? "left + right" : "together"
        return "\(work) · \(sides)"
    }

}
