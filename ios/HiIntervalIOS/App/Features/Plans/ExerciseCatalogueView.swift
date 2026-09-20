import SwiftUI
import HiIntervalCore

/// The reusable exercise library. Planning metadata lives here and is deliberately
/// kept out of the timer experience.
struct ExerciseCatalogueView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var editor: CatalogueEditorDestination?
    @State private var selectedIDs = Set<UUID>()
    @State private var selectionMode = false
    @State private var showsMergeConfirmation = false
    private let onChoose: ((CatalogueExercise) -> Void)?

    init(onChoose: ((CatalogueExercise) -> Void)? = nil) {
        self.onChoose = onChoose
    }

    private var filteredExercises: [CatalogueExercise] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return store.data.exerciseCatalogue }
        return store.data.exerciseCatalogue.filter {
            $0.name.localizedCaseInsensitiveContains(needle)
                || $0.bodyAreas.contains { $0.localizedCaseInsensitiveContains(needle) }
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(needle) }
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
        .sheet(item: $editor) { destination in
            NavigationStack {
                CatalogueExerciseEditorView(exercise: destination.exercise) { saved in
                    if store.saveCatalogueExercise(saved) { editor = nil }
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
                Image(systemName: selectedIDs.contains(exercise.id) ? "checkmark.circle.fill" : "figure.strengthtraining.traditional")
                    .foregroundStyle(selectedIDs.contains(exercise.id) ? PlanPalette.accent : PlanPalette.secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                    if !exercise.bodyAreas.isEmpty || !exercise.tags.isEmpty {
                        Text((exercise.bodyAreas + exercise.tags).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    let plans = linkedPlanNames(for: exercise.id)
                    if !plans.isEmpty {
                        Text("Used in \(plans.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(PlanPalette.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if !selectionMode { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(selectionMode ? "catalogue.select.\(exercise.id.uuidString)" : "catalogue.row.\(exercise.id.uuidString)")
        .accessibilityValue(selectionMode ? (selectedIDs.contains(exercise.id) ? "Selected for merge" : "Not selected for merge") : "")
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func linkedPlanNames(for catalogueID: UUID) -> [String] {
        store.data.plans.filter { plan in
            plan.exercises.contains { $0.catalogueExerciseID == catalogueID }
        }.map(\.name)
    }

    private func mergeTargetLabel(_ exercise: CatalogueExercise) -> String {
        let plans = linkedPlanNames(for: exercise.id)
        let context = plans.isEmpty ? "Catalogue only" : plans.joined(separator: ", ")
        return "Keep \(exercise.name) · \(context)"
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
    let onSave: (CatalogueExercise) -> Void
    private let isNew: Bool
    @State private var exercise: CatalogueExercise
    @State private var bodyAreasText: String
    @State private var tagsText: String
    @State private var showsDefaultsEditor = false

    init(exercise: CatalogueExercise?, onSave: @escaping (CatalogueExercise) -> Void) {
        let entry = exercise ?? CatalogueExercise(name: "")
        _exercise = State(initialValue: entry)
        _bodyAreasText = State(initialValue: entry.bodyAreas.joined(separator: ", "))
        _tagsText = State(initialValue: entry.tags.joined(separator: ", "))
        self.isNew = exercise == nil
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
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body areas").font(.caption).foregroundStyle(PlanPalette.secondary)
                    TextField("e.g. arms, legs", text: $bodyAreasText, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityLabel("Body areas")
                        .accessibilityIdentifier("catalogue.editor.bodyAreas")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tags").font(.caption).foregroundStyle(PlanPalette.secondary)
                    TextField("e.g. achilles recovery", text: $tagsText, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityLabel("Tags")
                        .accessibilityIdentifier("catalogue.editor.tags")
                }
            } header: {
                Text("Planning")
            } footer: {
                Text("Separate entries with commas. These are used while planning and are hidden during training.")
            }
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
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).fontWeight(.semibold).disabled(!isValid)
                    .accessibilityIdentifier("catalogue.editor.save")
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
                    isNew: false
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
        exercise.bodyAreas = commaSeparatedTerms(bodyAreasText)
        exercise.tags = commaSeparatedTerms(tagsText)
        onSave(exercise)
    }

    private var defaultsSummary: String {
        let work = exercise.duration == .planDefault ? "Plan work default" : "Custom work"
        let sides = exercise.sideConfiguration.mode == .leftRight ? "left + right" : "together"
        return "\(work) · \(sides)"
    }

    private func commaSeparatedTerms(_ value: String) -> [String] {
        value.split(separator: ",").map { String($0) }
    }
}
