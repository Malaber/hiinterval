import Foundation

public struct WorkoutPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var warmUpSeconds: Int
    public var defaultWorkSeconds: Int
    public var defaultRecoverySeconds: Int
    public var roundRecoverySeconds: Int
    public var coolDownSeconds: Int
    public var roundCount: Int
    public var exercises: [ExerciseStep]
    public var roundOverrides: [WorkoutRoundOverride]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        warmUpSeconds: Int = 10,
        defaultWorkSeconds: Int = 40,
        defaultRecoverySeconds: Int = 20,
        roundRecoverySeconds: Int = 60,
        coolDownSeconds: Int = 30,
        roundCount: Int = 3,
        exercises: [ExerciseStep],
        roundOverrides: [WorkoutRoundOverride] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.warmUpSeconds = warmUpSeconds
        self.defaultWorkSeconds = defaultWorkSeconds
        self.defaultRecoverySeconds = defaultRecoverySeconds
        self.roundRecoverySeconds = roundRecoverySeconds
        self.coolDownSeconds = coolDownSeconds
        self.roundCount = roundCount
        self.exercises = exercises
        self.roundOverrides = roundOverrides
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func starter(now: Date = Date()) -> WorkoutPlan {
        WorkoutPlan(
            name: "Full Body Reset",
            exercises: [
                ExerciseStep(name: "Jumping Jacks"),
                ExerciseStep(name: "Reverse Lunges", sideConfiguration: .leftRight()),
                ExerciseStep(name: "Push-ups"),
                ExerciseStep(name: "Mountain Climbers", duration: .custom(seconds: 30)),
            ],
            createdAt: now,
            updatedAt: now
        )
    }
}

public struct WorkoutRoundOverride: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var roundNumber: Int
    public var workSeconds: Int?
    public var sideConfiguration: SideConfiguration?

    public init(
        id: UUID = UUID(),
        roundNumber: Int,
        workSeconds: Int? = nil,
        sideConfiguration: SideConfiguration? = nil
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.workSeconds = workSeconds
        self.sideConfiguration = sideConfiguration
    }
}

public struct ExerciseStep: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var duration: DurationSetting
    public var recovery: RecoverySetting
    public var sideConfiguration: SideConfiguration
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        duration: DurationSetting = .planDefault,
        recovery: RecoverySetting = .planDefault,
        sideConfiguration: SideConfiguration = .together,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.duration = duration
        self.recovery = recovery
        self.sideConfiguration = sideConfiguration
        self.notes = notes
    }

    public func resolvedWorkSeconds(default defaultSeconds: Int) -> Int {
        switch duration {
        case .planDefault:
            return defaultSeconds
        case let .custom(seconds):
            return seconds
        }
    }

    public func resolvedRecoverySeconds(default defaultSeconds: Int) -> Int {
        switch recovery {
        case .planDefault:
            return defaultSeconds
        case let .custom(seconds):
            return seconds
        case .none:
            return 0
        }
    }
}

public enum DurationSetting: Codable, Equatable, Sendable {
    case planDefault
    case custom(seconds: Int)
}

public enum RecoverySetting: Codable, Equatable, Sendable {
    case planDefault
    case custom(seconds: Int)
    case none
}

public struct SideConfiguration: Codable, Equatable, Sendable {
    public var mode: SideMode
    public var firstSide: WorkoutSide
    public var switchSeconds: Int

    public init(mode: SideMode, firstSide: WorkoutSide = .left, switchSeconds: Int = 0) {
        self.mode = mode
        self.firstSide = firstSide
        self.switchSeconds = switchSeconds
    }

    public static let together = SideConfiguration(mode: .together)

    public static func leftRight(
        firstSide: WorkoutSide = .left,
        switchSeconds: Int = 0
    ) -> SideConfiguration {
        SideConfiguration(mode: .leftRight, firstSide: firstSide, switchSeconds: switchSeconds)
    }
}

public enum SideMode: String, Codable, CaseIterable, Equatable, Sendable {
    case together
    case leftRight
}

public enum WorkoutSide: String, Codable, CaseIterable, Equatable, Sendable {
    case left
    case right

    public var opposite: WorkoutSide { self == .left ? .right : .left }
}

public enum WorkoutValidationError: Error, Equatable, LocalizedError, Sendable {
    case emptyName
    case emptyExercises
    case invalidRoundCount
    case invalidDuration(field: String)
    case emptyExerciseName(index: Int)
    case splitDurationTooShort(index: Int)

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Workout name cannot be empty."
        case .emptyExercises:
            return "Add at least one exercise."
        case .invalidRoundCount:
            return "Round count must be at least one."
        case let .invalidDuration(field):
            return "\(field) cannot be negative."
        case let .emptyExerciseName(index):
            return "Exercise \(index + 1) needs a name."
        case let .splitDurationTooShort(index):
            return "Exercise \(index + 1) needs at least two seconds for left/right mode."
        }
    }
}

public extension WorkoutPlan {
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WorkoutValidationError.emptyName
        }
        guard !exercises.isEmpty else { throw WorkoutValidationError.emptyExercises }
        guard roundCount > 0 else { throw WorkoutValidationError.invalidRoundCount }

        let durations: [(String, Int)] = [
            ("Warm-up", warmUpSeconds),
            ("Default work", defaultWorkSeconds),
            ("Default recovery", defaultRecoverySeconds),
            ("Round recovery", roundRecoverySeconds),
            ("Cool-down", coolDownSeconds),
        ]
        if let invalid = durations.first(where: { $0.1 < 0 }) {
            throw WorkoutValidationError.invalidDuration(field: invalid.0)
        }

        for (index, exercise) in exercises.enumerated() {
            guard !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WorkoutValidationError.emptyExerciseName(index: index)
            }
            let work = exercise.resolvedWorkSeconds(default: defaultWorkSeconds)
            let recovery = exercise.resolvedRecoverySeconds(default: defaultRecoverySeconds)
            guard work > 0 else {
                throw WorkoutValidationError.invalidDuration(field: "Exercise work")
            }
            guard recovery >= 0, exercise.sideConfiguration.switchSeconds >= 0 else {
                throw WorkoutValidationError.invalidDuration(field: "Exercise recovery")
            }
            if exercise.sideConfiguration.mode == .leftRight, work < 2 {
                throw WorkoutValidationError.splitDurationTooShort(index: index)
            }
        }

        for override in roundOverrides {
            guard (1...roundCount).contains(override.roundNumber) else {
                throw WorkoutValidationError.invalidRoundCount
            }
            if let workSeconds = override.workSeconds, workSeconds <= 0 {
                throw WorkoutValidationError.invalidDuration(field: "Round work")
            }
            if let sideConfiguration = override.sideConfiguration,
               sideConfiguration.switchSeconds < 0 {
                throw WorkoutValidationError.invalidDuration(field: "Side switch")
            }
            if override.sideConfiguration?.mode == .leftRight,
               exercises.contains(where: {
                   (override.workSeconds ?? $0.resolvedWorkSeconds(default: defaultWorkSeconds)) < 2
               }) {
                throw WorkoutValidationError.invalidDuration(field: "Split round work")
            }
        }
    }
}
