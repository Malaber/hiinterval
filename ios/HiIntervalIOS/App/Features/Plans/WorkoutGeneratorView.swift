import SwiftUI
import HiIntervalCore

/// Builds an editable plan from the local catalogue. It has no network or model dependency.
struct WorkoutGeneratorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var options = WorkoutGenerationOptions()
    @State private var generatedPlan: WorkoutPlan?
    @State private var errorMessage: String?
    @State private var showsCatalogue = false

    private var tags: [ExerciseLabel] {
        store.data.exerciseLabels.filter { $0.kind == .tag }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var eligibleCount: Int {
        WorkoutGenerator.eligibleExercises(
            in: store.data.exerciseCatalogue,
            labels: store.data.exerciseLabels,
            options: options
        ).count
    }

    var body: some View {
        Form {
            Section {
                Stepper(value: $options.exerciseCount, in: 1...100) {
                    LabeledContent("Exercises") {
                        Text("\(options.exerciseCount)").monospacedDigit().fontWeight(.semibold)
                    }
                }
                .accessibilityIdentifier("generator.count")

                Toggle("Alternate body areas", isOn: $options.alternateBodyAreas)
                    .accessibilityIdentifier("generator.alternate")
            } footer: {
                Text(options.alternateBodyAreas
                    ? "Prefer different body areas for adjacent exercises. Areas can repeat when matching choices run out or have no areas assigned. Each round uses the same order."
                    : "Exercises are placed in a random order. Each round uses the same order.")
            }

            if !tags.isEmpty {
                tagSection(title: "Must include all tags", selected: requiredTags)
                tagSection(title: "Exclude any tags", selected: excludedTags)
            }

            Section("Available") {
                LabeledContent("Matching exercises") {
                    Text("\(eligibleCount)").monospacedDigit().fontWeight(.semibold)
                }
                if store.data.exerciseCatalogue.isEmpty {
                    Label("Add exercises to your catalogue first.", systemImage: "square.stack.3d.up")
                        .foregroundStyle(.secondary)
                } else if eligibleCount < options.exerciseCount {
                    Label("Add matching exercises or reduce the number requested.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.primary)
                }
                Button { showsCatalogue = true } label: {
                    Label("Manage exercise catalogue", systemImage: "square.stack.3d.up")
                }
                .accessibilityIdentifier("generator.catalogue")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Generate workout")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: tags) { _, availableTags in
            let availableIDs = Set(availableTags.map(\.id))
            options.requiredTagIDs.formIntersection(availableIDs)
            options.excludedTagIDs.formIntersection(availableIDs)
            errorMessage = nil
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("generator.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Preview", action: generate)
                    .fontWeight(.semibold)
                    .disabled(eligibleCount < options.exerciseCount)
                    .accessibilityIdentifier("generator.generate")
            }
        }
        .sheet(isPresented: $showsCatalogue) {
            NavigationStack { ExerciseCatalogueView() }
                .tint(PlanPalette.accent)
        }
        .sheet(item: $generatedPlan) { plan in
            NavigationStack {
                PlanEditorView(plan: plan, isNew: true) { savedPlan, logoDraft in
                    guard store.savePlan(savedPlan, logoDraft: logoDraft) else {
                        errorMessage = store.lastErrorMessage
                        return
                    }
                    generatedPlan = nil
                    dismiss()
                }
            }
            .tint(PlanPalette.accent)
        }
        .accessibilityIdentifier("generator.screen")
    }

    private func tagSection(title: String, selected: Binding<Set<UUID>>) -> some View {
        Section(title) {
            ForEach(tags) { tag in
                Toggle(tag.name, isOn: Binding(
                    get: { selected.wrappedValue.contains(tag.id) },
                    set: { enabled in
                        if enabled { selected.wrappedValue.insert(tag.id) }
                        else { selected.wrappedValue.remove(tag.id) }
                    }
                ))
                .accessibilityIdentifier("generator.\(title.hasPrefix("Must") ? "requiredTags" : "excludedTags").\(stableID(tag.name))")
            }
        }
    }

    private var requiredTags: Binding<Set<UUID>> {
        Binding(get: { options.requiredTagIDs }, set: { options.requiredTagIDs = $0 })
    }

    private var excludedTags: Binding<Set<UUID>> {
        Binding(get: { options.excludedTagIDs }, set: { options.excludedTagIDs = $0 })
    }

    private func stableID(_ text: String) -> String {
        text.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
    }

    private func generate() {
        do {
            generatedPlan = try WorkoutGenerator.generate(
                from: store.data.exerciseCatalogue,
                labels: store.data.exerciseLabels,
                options: options
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
