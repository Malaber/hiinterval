import Foundation

public struct AppData: Codable, Equatable, Sendable {
    public var plans: [WorkoutPlan]
    public var history: [WorkoutHistoryEntry]
    public var preferences: UserPreferences
    public var usage: UsageRecord
    public var selectedPlanID: UUID?
    public var exerciseCatalogue: [CatalogueExercise]

    public init(
        plans: [WorkoutPlan] = [],
        history: [WorkoutHistoryEntry] = [],
        preferences: UserPreferences = UserPreferences(),
        usage: UsageRecord = UsageRecord(),
        selectedPlanID: UUID? = nil,
        exerciseCatalogue: [CatalogueExercise] = []
    ) {
        self.plans = plans
        self.history = history
        self.preferences = preferences
        self.usage = usage
        self.selectedPlanID = selectedPlanID
        self.exerciseCatalogue = exerciseCatalogue
        synchronizeExerciseCatalogue()
    }

    private enum CodingKeys: String, CodingKey {
        case plans, history, preferences, usage, selectedPlanID, exerciseCatalogue
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        plans = try values.decode([WorkoutPlan].self, forKey: .plans)
        history = try values.decode([WorkoutHistoryEntry].self, forKey: .history)
        preferences = try values.decode(UserPreferences.self, forKey: .preferences)
        usage = try values.decode(UsageRecord.self, forKey: .usage)
        selectedPlanID = try values.decodeIfPresent(UUID.self, forKey: .selectedPlanID)
        exerciseCatalogue = try values.decodeIfPresent([CatalogueExercise].self, forKey: .exerciseCatalogue) ?? []
        synchronizeExerciseCatalogue()
    }

    /// Ensures every live plan step has a stable catalogue entry while leaving historical snapshots intact.
    public mutating func synchronizeExerciseCatalogue() {
        var entries: [UUID: CatalogueExercise] = [:]
        for entry in exerciseCatalogue where entries[entry.id] == nil {
            entries[entry.id] = entry.normalized()
        }
        for planIndex in plans.indices {
            for stepIndex in plans[planIndex].exercises.indices {
                var step = plans[planIndex].exercises[stepIndex]
                if let catalogueID = step.catalogueExerciseID, let canonical = entries[catalogueID] {
                    step.name = canonical.name
                } else {
                    var entry = CatalogueExercise(step: step)
                    while entries[entry.id] != nil { entry.id = UUID() }
                    entry = entry.normalized()
                    entries[entry.id] = entry
                    step.catalogueExerciseID = entry.id
                    step.name = entry.name
                }
                plans[planIndex].exercises[stepIndex] = step
            }
        }
        // Keep catalogue order stable for the UI and only append migrated entries in plan order.
        var seen = Set<UUID>()
        exerciseCatalogue = exerciseCatalogue.compactMap { original in
            guard let entry = entries[original.id], seen.insert(entry.id).inserted else { return nil }
            return entry
        }
        for plan in plans {
            for step in plan.exercises {
                if let id = step.catalogueExerciseID,
                   let entry = entries[id],
                   seen.insert(id).inserted {
                    exerciseCatalogue.append(entry)
                }
            }
        }
    }

    public mutating func saveCatalogueExercise(_ entry: CatalogueExercise) throws {
        let normalized = entry.normalized()
        guard !normalized.name.isEmpty else { throw ExerciseCatalogueError.emptyName }
        do {
            try WorkoutPlan(name: "Validation", exercises: [normalized.makeStep()]).validate()
        } catch let error as LocalizedError {
            throw ExerciseCatalogueError.invalidConfiguration(error.errorDescription ?? "Invalid exercise configuration.")
        }
        if let index = exerciseCatalogue.firstIndex(where: { $0.id == normalized.id }) {
            exerciseCatalogue[index] = normalized
        } else {
            exerciseCatalogue.append(normalized)
        }
        for planIndex in plans.indices {
            for stepIndex in plans[planIndex].exercises.indices
            where plans[planIndex].exercises[stepIndex].catalogueExerciseID == normalized.id {
                plans[planIndex].exercises[stepIndex].name = normalized.name
            }
        }
    }

    public mutating func mergeCatalogueExercises(sourceIDs: Set<UUID>, into targetID: UUID) throws {
        guard var target = exerciseCatalogue.first(where: { $0.id == targetID }) else {
            throw ExerciseCatalogueError.missingMergeTarget(targetID)
        }
        if let missingID = sourceIDs.first(where: { sourceID in
            !exerciseCatalogue.contains(where: { $0.id == sourceID })
        }) {
            throw ExerciseCatalogueError.missingExercise(missingID)
        }
        let sources = exerciseCatalogue.filter { sourceIDs.contains($0.id) && $0.id != targetID }
        target.bodyAreas = CatalogueExercise.normalizedTerms(target.bodyAreas + sources.flatMap(\.bodyAreas))
        target.tags = CatalogueExercise.normalizedTerms(target.tags + sources.flatMap(\.tags))
        try saveCatalogueExercise(target)
        for planIndex in plans.indices {
            for stepIndex in plans[planIndex].exercises.indices {
                guard let sourceID = plans[planIndex].exercises[stepIndex].catalogueExerciseID,
                      sourceIDs.contains(sourceID) else { continue }
                plans[planIndex].exercises[stepIndex].catalogueExerciseID = targetID
                plans[planIndex].exercises[stepIndex].name = target.name
            }
        }
        exerciseCatalogue.removeAll { sourceIDs.contains($0.id) && $0.id != targetID }
    }

    public static func starter(now: Date = Date()) -> AppData {
        let plan = WorkoutPlan.starter(now: now)
        return AppData(plans: [plan], selectedPlanID: plan.id)
    }
}

public struct WorkoutHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var planID: UUID
    public var planName: String
    public var startedAt: Date
    public var completedAt: Date
    public var plannedDurationSeconds: Int
    public var elapsedDurationSeconds: Int
    public var roundCount: Int
    public var exerciseCount: Int
    public var planSnapshot: WorkoutPlan?

    public init(
        id: UUID = UUID(),
        planID: UUID,
        planName: String,
        startedAt: Date,
        completedAt: Date,
        plannedDurationSeconds: Int,
        elapsedDurationSeconds: Int,
        roundCount: Int,
        exerciseCount: Int,
        planSnapshot: WorkoutPlan? = nil
    ) {
        self.id = id
        self.planID = planID
        self.planName = planName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.plannedDurationSeconds = plannedDurationSeconds
        self.elapsedDurationSeconds = elapsedDurationSeconds
        self.roundCount = roundCount
        self.exerciseCount = exerciseCount
        self.planSnapshot = planSnapshot
    }
}

public struct UserPreferences: Codable, Equatable, Sendable {
    public var cueStyle: CueStyle
    public var cueLanguage: CueLanguage
    public var hapticsEnabled: Bool
    public var duckOtherAudio: Bool
    public var pauseWhenInactive: Bool
    public var countdownEnabled: Bool
    public var keepScreenAwake: Bool
    public var appearance: AppearancePreference
    public var reminders: ReminderSettings

    public init(
        cueStyle: CueStyle = .tones,
        cueLanguage: CueLanguage = .system,
        hapticsEnabled: Bool = true,
        duckOtherAudio: Bool = false,
        pauseWhenInactive: Bool = true,
        countdownEnabled: Bool = true,
        keepScreenAwake: Bool = true,
        appearance: AppearancePreference = .system,
        reminders: ReminderSettings = ReminderSettings()
    ) {
        self.cueStyle = cueStyle
        self.cueLanguage = cueLanguage
        self.hapticsEnabled = hapticsEnabled
        self.duckOtherAudio = duckOtherAudio
        self.pauseWhenInactive = pauseWhenInactive
        self.countdownEnabled = countdownEnabled
        self.keepScreenAwake = keepScreenAwake
        self.appearance = appearance
        self.reminders = reminders
    }

    private enum CodingKeys: String, CodingKey {
        case cueStyle
        case cueLanguage
        case hapticsEnabled
        case duckOtherAudio
        case pauseWhenInactive
        case countdownEnabled
        case keepScreenAwake
        case appearance
        case reminders
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cueStyle = try values.decodeIfPresent(CueStyle.self, forKey: .cueStyle) ?? .tones
        cueLanguage = try values.decodeIfPresent(CueLanguage.self, forKey: .cueLanguage) ?? .system
        hapticsEnabled = try values.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        duckOtherAudio = try values.decodeIfPresent(Bool.self, forKey: .duckOtherAudio) ?? false
        pauseWhenInactive = try values.decodeIfPresent(Bool.self, forKey: .pauseWhenInactive) ?? true
        countdownEnabled = try values.decodeIfPresent(Bool.self, forKey: .countdownEnabled) ?? true
        keepScreenAwake = try values.decodeIfPresent(Bool.self, forKey: .keepScreenAwake) ?? true
        appearance = try values.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? .system
        reminders = try values.decodeIfPresent(ReminderSettings.self, forKey: .reminders) ?? ReminderSettings()
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(cueStyle, forKey: .cueStyle)
        try values.encode(cueLanguage, forKey: .cueLanguage)
        try values.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try values.encode(duckOtherAudio, forKey: .duckOtherAudio)
        try values.encode(pauseWhenInactive, forKey: .pauseWhenInactive)
        try values.encode(countdownEnabled, forKey: .countdownEnabled)
        try values.encode(keepScreenAwake, forKey: .keepScreenAwake)
        try values.encode(appearance, forKey: .appearance)
        try values.encode(reminders, forKey: .reminders)
    }
}

public enum CueStyle: String, Codable, CaseIterable, Sendable {
    case tones
    case spoken
    case silent
}

public enum CueLanguage: String, Codable, CaseIterable, Sendable {
    case system
    case english
    case german
}

public enum AppearancePreference: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public struct ReminderSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var weekdays: Set<Int>
    public var hour: Int
    public var minute: Int

    public init(
        enabled: Bool = false,
        weekdays: Set<Int> = [],
        hour: Int = 18,
        minute: Int = 0
    ) {
        self.enabled = enabled
        self.weekdays = weekdays
        self.hour = hour
        self.minute = minute
    }
}

public enum AppDataCodec {
    public static func encode(_ value: AppData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    public static func decode(_ data: Data) throws -> AppData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppData.self, from: data)
    }
}
