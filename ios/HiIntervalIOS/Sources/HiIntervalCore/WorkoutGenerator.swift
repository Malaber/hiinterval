import Foundation

public struct WorkoutGenerationOptions: Codable, Equatable, Sendable {
    public var exerciseCount: Int
    public var requiredTagIDs: Set<UUID>
    public var excludedTagIDs: Set<UUID>
    public var alternateBodyAreas: Bool
    public init(
        exerciseCount: Int = 6,
        requiredTagIDs: Set<UUID> = [],
        excludedTagIDs: Set<UUID> = [],
        alternateBodyAreas: Bool = true
    ) {
        self.exerciseCount = exerciseCount
        self.requiredTagIDs = requiredTagIDs
        self.excludedTagIDs = excludedTagIDs
        self.alternateBodyAreas = alternateBodyAreas
    }
}

public enum WorkoutGenerationError: Error, Equatable, LocalizedError, Sendable {
    case invalidExerciseCount
    case insufficientEligibleExercises(available: Int, requested: Int)
    public var errorDescription: String? {
        switch self {
        case .invalidExerciseCount: return "Choose at least one exercise."
        case let .insufficientEligibleExercises(available, requested): return "Only \(available) eligible exercises are available; \(requested) were requested."
        }
    }
}

public enum WorkoutGenerator {
    public static func eligibleExercises(
        in catalogue: [CatalogueExercise],
        labels: [ExerciseLabel],
        options: WorkoutGenerationOptions
    ) -> [CatalogueExercise] {
        let knownTagIDs = Set(labels.filter { $0.kind == .tag }.map(\.id))
        let required = options.requiredTagIDs
        let excluded = options.excludedTagIDs
        var seen = Set<UUID>()
        return catalogue.filter { exercise in
            let tags = Set(exercise.labelIDs).intersection(knownTagIDs)
            return seen.insert(exercise.id).inserted
                && required.isSubset(of: tags)
                && excluded.isDisjoint(with: tags)
        }
    }

    public static func generate<R: RandomNumberGenerator>(
        from catalogue: [CatalogueExercise],
        labels: [ExerciseLabel],
        options: WorkoutGenerationOptions = WorkoutGenerationOptions(),
        using random: inout R
    ) throws -> WorkoutPlan {
        guard options.exerciseCount > 0 else { throw WorkoutGenerationError.invalidExerciseCount }
        var choices = eligibleExercises(in: catalogue, labels: labels, options: options)
        guard choices.count >= options.exerciseCount else {
            throw WorkoutGenerationError.insufficientEligibleExercises(available: choices.count, requested: options.exerciseCount)
        }
        choices.shuffle(using: &random)
        var selected: [CatalogueExercise] = []
        while selected.count < options.exerciseCount {
            let next: CatalogueExercise
            if options.alternateBodyAreas, let previous = selected.last,
               !bodyAreaIDs(for: previous, in: labels).isEmpty,
               let index = choices.firstIndex(where: { candidate in
                   let areas = bodyAreaIDs(for: candidate, in: labels)
                   return !areas.isEmpty && areas.isDisjoint(with: bodyAreaIDs(for: previous, in: labels))
               }) {
                next = choices.remove(at: index)
            } else {
                next = choices.removeFirst()
            }
            selected.append(next)
        }
        var plan = WorkoutPlan(
            name: "Generated workout",
            exercises: selected.map { $0.makeStep() }
        )
        plan.generationOptions = options
        try plan.validate()
        return plan
    }

    public static func generate(
        from catalogue: [CatalogueExercise],
        labels: [ExerciseLabel],
        options: WorkoutGenerationOptions = WorkoutGenerationOptions()
    ) throws -> WorkoutPlan {
        var random = SystemRandomNumberGenerator()
        return try generate(from: catalogue, labels: labels, options: options, using: &random)
    }

    /// Replaces exercise instances only. Prefer unused choices; retain some existing exercises
    /// when the eligible catalogue cannot supply a wholly new selection.
    public static func replacingExercises<R: RandomNumberGenerator>(
        in plan: WorkoutPlan,
        from catalogue: [CatalogueExercise],
        labels: [ExerciseLabel],
        options: WorkoutGenerationOptions,
        using random: inout R
    ) throws -> WorkoutPlan {
        let eligible = eligibleExercises(in: catalogue, labels: labels, options: options)
        let existing = Set(plan.exercises.compactMap(\.catalogueExerciseID))
        var fresh = eligible.filter { !existing.contains($0.id) }
        var reused = eligible.filter { existing.contains($0.id) }
        reused.shuffle(using: &random)
        fresh += reused.prefix(max(0, options.exerciseCount - fresh.count))
        let generated = try generate(from: fresh, labels: labels, options: options, using: &random)
        var result = plan
        result.exercises = generated.exercises
        result.generationOptions = options
        try result.validate()
        return result
    }

    private static func bodyAreaIDs(for exercise: CatalogueExercise, in labels: [ExerciseLabel]) -> Set<UUID> {
        Set(exercise.labelIDs).intersection(labels.lazy.filter { $0.kind == .bodyArea }.map(\.id))
    }
}
