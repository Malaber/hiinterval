import Foundation

public struct WorkoutGenerationOptions: Equatable, Sendable {
    public var exerciseCount: Int
    public var requiredTags: Set<String>
    public var excludedTags: Set<String>
    public var alternateBodyAreas: Bool
    public init(
        exerciseCount: Int = 6,
        requiredTags: Set<String> = [],
        excludedTags: Set<String> = [],
        alternateBodyAreas: Bool = true
    ) {
        self.exerciseCount = exerciseCount
        self.requiredTags = requiredTags
        self.excludedTags = excludedTags
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
        options: WorkoutGenerationOptions
    ) -> [CatalogueExercise] {
        let required = normalized(options.requiredTags)
        let excluded = normalized(options.excludedTags)
        var seen = Set<UUID>()
        return catalogue.filter { exercise in
            let tags = normalized(Set(exercise.tags))
            return seen.insert(exercise.id).inserted
                && required.isSubset(of: tags)
                && excluded.isDisjoint(with: tags)
        }
    }

    public static func generate<R: RandomNumberGenerator>(
        from catalogue: [CatalogueExercise],
        options: WorkoutGenerationOptions = WorkoutGenerationOptions(),
        using random: inout R
    ) throws -> WorkoutPlan {
        guard options.exerciseCount > 0 else { throw WorkoutGenerationError.invalidExerciseCount }
        var choices = eligibleExercises(in: catalogue, options: options)
        guard choices.count >= options.exerciseCount else {
            throw WorkoutGenerationError.insufficientEligibleExercises(available: choices.count, requested: options.exerciseCount)
        }
        choices.shuffle(using: &random)
        var selected: [CatalogueExercise] = []
        while selected.count < options.exerciseCount {
            let next: CatalogueExercise
            if options.alternateBodyAreas, let previous = selected.last,
               !normalized(previous.bodyAreas).isEmpty,
               let index = choices.firstIndex(where: { candidate in
                   let areas = normalized(candidate.bodyAreas)
                   return !areas.isEmpty && Set(areas).isDisjoint(with: Set(normalized(previous.bodyAreas)))
               }) {
                next = choices.remove(at: index)
            } else {
                next = choices.removeFirst()
            }
            selected.append(next)
        }
        let plan = WorkoutPlan(
            name: "Generated workout",
            exercises: selected.map { $0.makeStep() }
        )
        try plan.validate()
        return plan
    }

    public static func generate(
        from catalogue: [CatalogueExercise],
        options: WorkoutGenerationOptions = WorkoutGenerationOptions()
    ) throws -> WorkoutPlan {
        var random = SystemRandomNumberGenerator()
        return try generate(from: catalogue, options: options, using: &random)
    }

    private static func normalized(_ values: Set<String>) -> Set<String> {
        Set(values.map(CatalogueExercise.normalizedLabel).filter { !$0.isEmpty })
    }
    private static func normalized(_ values: [String]) -> [String] {
        CatalogueExercise.normalizedTerms(values).map(CatalogueExercise.normalizedLabel)
    }
}
