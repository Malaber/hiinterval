import HiIntervalCore
import SwiftUI

/// Editor for shared planning labels. It only updates its bindings; persistence belongs to the
/// surrounding catalogue editor so Cancel remains atomic.
struct ExerciseLabelPicker: View {
    let kind: ExerciseLabel.Kind
    let available: [ExerciseLabel]
    @Binding var selection: [ExerciseLabel]
    @Binding var query: String

    private static let bodyAreaPresets = [
        "Arms", "Legs", "Core", "Back", "Chest", "Shoulders", "Glutes", "Calves", "Full body"
    ]
    private static let tagPresets = [
        "Strength", "Mobility", "Balance", "Recovery", "Low impact", "No equipment", "Warm-up", "Stretching"
    ]

    private var prefix: String {
        kind == .bodyArea ? "catalogue.editor.bodyAreas" : "catalogue.editor.tags"
    }

    private var title: String {
        kind == .bodyArea ? "Body areas" : "Tags"
    }

    private var inputPrompt: String {
        kind == .bodyArea ? "Add body area" : "Add tag"
    }

    private var selectedLabels: [ExerciseLabel] {
        selection.filter { $0.kind == kind }
    }

    private var selectedNames: Set<String> {
        Set(selectedLabels.map { ExerciseLabel.normalizedName($0.name) })
    }

    private var existingSuggestions: [ExerciseLabel] {
        uniqueAvailableLabels.filter(matchesQuery)
    }

    private var presetSuggestions: [ExerciseLabel] {
        presets
            .filter { !selectedNames.contains(ExerciseLabel.normalizedName($0)) }
            .filter { preset in
                !uniqueAvailableLabels.contains {
                    ExerciseLabel.normalizedName($0.name) == ExerciseLabel.normalizedName(preset)
                }
            }
            .filter(matchesQuery)
            .map { ExerciseLabel(name: $0, kind: kind) }
    }

    private var suggestions: (existing: [ExerciseLabel], presets: [ExerciseLabel]) {
        guard normalizedQuery.isEmpty else {
            return (existingSuggestions, presetSuggestions)
        }

        // Keep both sources visible before filtering so common starter labels stay discoverable
        // even after a large catalogue migration.
        return (
            Array(initialExistingSuggestions.prefix(3)),
            Array(presetSuggestions.prefix(3))
        )
    }

    var body: some View {
        Section {
            if !selectedLabels.isEmpty {
                HIPillLayout(spacing: 6) {
                    ForEach(selectedLabels) { label in
                        removePill(label)
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(alignment: .firstTextBaseline, spacing: HITheme.Spacing.small) {
                TextField(inputPrompt, text: $query)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(addQuery)
                    .accessibilityIdentifier(prefix)

                Button("Add", action: addQuery)
                    .buttonStyle(.plain)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(HITheme.accentStrong)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("\(prefix).add")
                    .disabled(resolveQuery() == nil)
            }

            if !suggestions.existing.isEmpty {
                suggestionGroup("Existing", labels: suggestions.existing)
            }
            if !suggestions.presets.isEmpty {
                suggestionGroup("Suggested", labels: suggestions.presets)
            }
        } header: {
            Text(title)
        } footer: {
            Text("Shared labels help plan balanced workouts and stay hidden during training.")
        }
    }

    /// Returns a matching catalogue label when possible, otherwise a new in-memory label.
    /// The caller persists it only when the exercise itself is saved.
    static func resolveLabel(
        name: String,
        kind: ExerciseLabel.Kind,
        available: [ExerciseLabel]
    ) -> ExerciseLabel? {
        let displayName = name
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        let normalized = ExerciseLabel.normalizedName(displayName)
        guard !normalized.isEmpty else { return nil }

        if let existing = available.first(where: {
            $0.kind == kind && ExerciseLabel.normalizedName($0.name) == normalized
        }) {
            return existing
        }
        return ExerciseLabel(name: displayName, kind: kind)
    }

    static func stableSlug(_ name: String) -> String {
        let pieces = name.lowercased().unicodeScalars.reduce(into: [String]()) { result, scalar in
            if CharacterSet.alphanumerics.contains(scalar) {
                result.append(String(scalar))
            } else if result.last != "-" {
                result.append("-")
            }
        }
        return pieces.joined().trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private var uniqueAvailableLabels: [ExerciseLabel] {
        var seen = Set<String>()
        return available
            .filter { $0.kind == kind }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .filter { label in
                let normalized = ExerciseLabel.normalizedName(label.name)
                return !selectedNames.contains(normalized) && seen.insert(normalized).inserted
            }
    }

    private var initialExistingSuggestions: [ExerciseLabel] {
        let presetOrder = Dictionary(
            uniqueKeysWithValues: presets.enumerated().map {
                (ExerciseLabel.normalizedName($0.element), $0.offset)
            }
        )
        return uniqueAvailableLabels.sorted { lhs, rhs in
            let leftPriority = presetOrder[ExerciseLabel.normalizedName(lhs.name)] ?? Int.max
            let rightPriority = presetOrder[ExerciseLabel.normalizedName(rhs.name)] ?? Int.max
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var presets: [String] {
        kind == .bodyArea ? Self.bodyAreaPresets : Self.tagPresets
    }

    private var normalizedQuery: String {
        ExerciseLabel.normalizedName(query)
    }

    private func matchesQuery(_ label: ExerciseLabel) -> Bool {
        normalizedQuery.isEmpty || ExerciseLabel.normalizedName(label.name).contains(normalizedQuery)
    }

    private func matchesQuery(_ name: String) -> Bool {
        normalizedQuery.isEmpty || ExerciseLabel.normalizedName(name).contains(normalizedQuery)
    }

    @ViewBuilder
    private func suggestionGroup(_ heading: String, labels: [ExerciseLabel]) -> some View {
        VStack(alignment: .leading, spacing: HITheme.Spacing.xSmall) {
            Text(heading)
                .font(.caption)
                .foregroundStyle(HITheme.textSecondary)
            HIPillLayout(spacing: 6) {
                ForEach(labels, id: \.name) { label in
                    Button {
                        add(label)
                    } label: {
                        Text(label.name)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(minHeight: 44)
                            .foregroundStyle(HITheme.textPrimary)
                            .background(HITheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(label.name)")
                    .accessibilityIdentifier("\(prefix).suggestion.\(Self.stableSlug(label.name))")
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func removePill(_ label: ExerciseLabel) -> some View {
        HStack(spacing: 2) {
            Text(label.name)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 10)
                .padding(.vertical, 6)
            Button {
                selection.removeAll { $0.id == label.id }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(label.name)")
            .accessibilityIdentifier("\(prefix).remove.\(Self.stableSlug(label.name))")
        }
        .foregroundStyle(HITheme.textPrimary)
        .background(HITheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(HITheme.stroke, lineWidth: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(prefix).pill.\(Self.stableSlug(label.name))")
    }

    private func resolveQuery() -> ExerciseLabel? {
        Self.resolveLabel(name: query, kind: kind, available: available)
    }

    private func addQuery() {
        guard let label = resolveQuery() else { return }
        add(label)
        query = ""
    }

    private func add(_ label: ExerciseLabel) {
        let normalized = ExerciseLabel.normalizedName(label.name)
        guard !selectedNames.contains(normalized) else { return }
        selection.append(label)
        query = ""
    }
}
