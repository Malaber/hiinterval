public enum ExerciseEditorInitialFocus: Equatable, Sendable {
    case name
}

public enum ExerciseEditorPresentation {
    public static func initialFocus(isNew: Bool) -> ExerciseEditorInitialFocus? {
        isNew ? .name : nil
    }
}
