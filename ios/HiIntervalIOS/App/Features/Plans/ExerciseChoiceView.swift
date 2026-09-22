import SwiftUI
import HiIntervalCore

/// Changes remain in the plan draft until the plan itself is saved.
struct ExerciseChoiceView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let defaultWorkSeconds: Int
    let defaultRecoverySeconds: Int
    let onChoose: (ExerciseStep) -> Void

    private var matches: [CatalogueExercise] {
        let needle = ExerciseLabel.normalizedName(query)
        return store.data.exerciseCatalogue.filter {
            needle.isEmpty || ExerciseLabel.normalizedName($0.name).contains(needle)
        }
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ExerciseEditorView(
                        exercise: ExerciseStep(name: query.trimmingCharacters(in: .whitespacesAndNewlines)),
                        defaultWorkSeconds: defaultWorkSeconds,
                        defaultRecoverySeconds: defaultRecoverySeconds,
                        isNew: true,
                        onSave: onChoose
                    )
                } label: {
                    Label("Create new exercise", systemImage: "plus")
                }
                .accessibilityIdentifier("exercise.choice.create")
            }
            Section("Choose from catalogue") {
                ForEach(matches) { exercise in
                    Button { onChoose(exercise.makeStep()) } label: {
                        Text(exercise.name).foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("catalogue.row.\(exercise.id.uuidString)")
                }
                if matches.isEmpty {
                    Text("No matching exercises. Create a new one above.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $query, prompt: "Find an exercise")
        .navigationTitle("Add exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("exercise.choice.cancel")
            }
        }
        .accessibilityIdentifier("catalogue.screen")
    }
}
