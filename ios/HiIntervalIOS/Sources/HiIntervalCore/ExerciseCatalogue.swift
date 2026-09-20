import Foundation

public struct CatalogueExercise: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var bodyAreas: [String]
    public var tags: [String]
    public var duration: DurationSetting
    public var recovery: RecoverySetting
    public var sideConfiguration: SideConfiguration
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        bodyAreas: [String] = [],
        tags: [String] = [],
        duration: DurationSetting = .planDefault,
        recovery: RecoverySetting = .planDefault,
        sideConfiguration: SideConfiguration = .together,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.bodyAreas = bodyAreas
        self.tags = tags
        self.duration = duration
        self.recovery = recovery
        self.sideConfiguration = sideConfiguration
        self.notes = notes
    }

    public init(step: ExerciseStep) {
        self.init(
            id: step.id,
            name: step.name,
            duration: step.duration,
            recovery: step.recovery,
            sideConfiguration: step.sideConfiguration,
            notes: step.notes
        )
    }

    public func makeStep() -> ExerciseStep {
        ExerciseStep(
            name: name,
            duration: duration,
            recovery: recovery,
            sideConfiguration: sideConfiguration,
            notes: notes,
            catalogueExerciseID: id
        )
    }

    public func normalized() -> CatalogueExercise {
        var value = self
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.bodyAreas = Self.normalizedTerms(bodyAreas)
        value.tags = Self.normalizedTerms(tags)
        return value
    }

    static func normalizedTerms(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { raw in
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(Self.normalizedLabel(value)).inserted else {
                return nil
            }
            return value
        }
    }

    static func normalizedLabel(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

public enum ExerciseCatalogueError: Error, Equatable, LocalizedError, Sendable {
    case emptyName
    case missingExercise(UUID)
    case missingMergeTarget(UUID)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Exercise name cannot be empty."
        case .missingExercise: return "One or more exercises could not be found."
        case .missingMergeTarget: return "The exercise to merge into could not be found."
        case let .invalidConfiguration(description): return description
        }
    }
}
