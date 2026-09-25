import Foundation

public struct WorkoutPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var warmUpSeconds: Int
    public var warmUpNotes: String?
    public var defaultWorkSeconds: Int
    public var defaultRecoverySeconds: Int
    public var recoveryNotes: String?
    public var roundRecoverySeconds: Int
    public var roundRecoveryNotes: String?
    public var coolDownSeconds: Int
    public var coolDownNotes: String?
    public var roundCount: Int
    public var exercises: [ExerciseStep]
    public var roundOverrides: [WorkoutRoundOverride]
    public var logo: WorkoutLogo
    public var generationOptions: WorkoutGenerationOptions?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        warmUpSeconds: Int = 10,
        warmUpNotes: String? = nil,
        defaultWorkSeconds: Int = 40,
        defaultRecoverySeconds: Int = 20,
        recoveryNotes: String? = nil,
        roundRecoverySeconds: Int = 60,
        roundRecoveryNotes: String? = nil,
        coolDownSeconds: Int = 30,
        coolDownNotes: String? = nil,
        roundCount: Int = 3,
        exercises: [ExerciseStep],
        roundOverrides: [WorkoutRoundOverride] = [],
        logo: WorkoutLogo = .default,
        generationOptions: WorkoutGenerationOptions? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.warmUpSeconds = warmUpSeconds
        self.warmUpNotes = warmUpNotes
        self.defaultWorkSeconds = defaultWorkSeconds
        self.defaultRecoverySeconds = defaultRecoverySeconds
        self.recoveryNotes = recoveryNotes
        self.roundRecoverySeconds = roundRecoverySeconds
        self.roundRecoveryNotes = roundRecoveryNotes
        self.coolDownSeconds = coolDownSeconds
        self.coolDownNotes = coolDownNotes
        self.roundCount = roundCount
        self.exercises = exercises
        self.roundOverrides = roundOverrides
        self.logo = logo
        self.generationOptions = generationOptions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, warmUpSeconds, warmUpNotes, defaultWorkSeconds, defaultRecoverySeconds
        case recoveryNotes, roundRecoverySeconds, roundRecoveryNotes, coolDownSeconds, coolDownNotes
        case roundCount, exercises, roundOverrides, logo, generationOptions, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        warmUpSeconds = try values.decode(Int.self, forKey: .warmUpSeconds)
        warmUpNotes = try values.decodeIfPresent(String.self, forKey: .warmUpNotes)
        defaultWorkSeconds = try values.decode(Int.self, forKey: .defaultWorkSeconds)
        defaultRecoverySeconds = try values.decode(Int.self, forKey: .defaultRecoverySeconds)
        recoveryNotes = try values.decodeIfPresent(String.self, forKey: .recoveryNotes)
        roundRecoverySeconds = try values.decode(Int.self, forKey: .roundRecoverySeconds)
        roundRecoveryNotes = try values.decodeIfPresent(String.self, forKey: .roundRecoveryNotes)
        coolDownSeconds = try values.decode(Int.self, forKey: .coolDownSeconds)
        coolDownNotes = try values.decodeIfPresent(String.self, forKey: .coolDownNotes)
        roundCount = try values.decode(Int.self, forKey: .roundCount)
        exercises = try values.decode([ExerciseStep].self, forKey: .exercises)
        roundOverrides = try values.decodeIfPresent([WorkoutRoundOverride].self, forKey: .roundOverrides) ?? []
        logo = try values.decodeIfPresent(WorkoutLogo.self, forKey: .logo) ?? .default
        generationOptions = try values.decodeIfPresent(WorkoutGenerationOptions.self, forKey: .generationOptions)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(name, forKey: .name)
        try values.encode(warmUpSeconds, forKey: .warmUpSeconds)
        try values.encodeIfPresent(warmUpNotes, forKey: .warmUpNotes)
        try values.encode(defaultWorkSeconds, forKey: .defaultWorkSeconds)
        try values.encode(defaultRecoverySeconds, forKey: .defaultRecoverySeconds)
        try values.encodeIfPresent(recoveryNotes, forKey: .recoveryNotes)
        try values.encode(roundRecoverySeconds, forKey: .roundRecoverySeconds)
        try values.encodeIfPresent(roundRecoveryNotes, forKey: .roundRecoveryNotes)
        try values.encode(coolDownSeconds, forKey: .coolDownSeconds)
        try values.encodeIfPresent(coolDownNotes, forKey: .coolDownNotes)
        try values.encode(roundCount, forKey: .roundCount)
        try values.encode(exercises, forKey: .exercises)
        try values.encode(roundOverrides, forKey: .roundOverrides)
        try values.encode(logo, forKey: .logo)
        try values.encodeIfPresent(generationOptions, forKey: .generationOptions)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(updatedAt, forKey: .updatedAt)
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
    /// The reusable catalogue exercise this instance was created from, if any.
    public var catalogueExerciseID: UUID?

    public init(
        id: UUID = UUID(),
        name: String,
        duration: DurationSetting = .planDefault,
        recovery: RecoverySetting = .planDefault,
        sideConfiguration: SideConfiguration = .together,
        notes: String = "",
        catalogueExerciseID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.duration = duration
        self.recovery = recovery
        self.sideConfiguration = sideConfiguration
        self.notes = notes
        self.catalogueExerciseID = catalogueExerciseID
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
