import Foundation

public struct AppData: Codable, Equatable, Sendable {
    public var plans: [WorkoutPlan]
    public var history: [WorkoutHistoryEntry]
    public var preferences: UserPreferences
    public var usage: UsageRecord
    public var selectedPlanID: UUID?

    public init(
        plans: [WorkoutPlan] = [],
        history: [WorkoutHistoryEntry] = [],
        preferences: UserPreferences = UserPreferences(),
        usage: UsageRecord = UsageRecord(),
        selectedPlanID: UUID? = nil
    ) {
        self.plans = plans
        self.history = history
        self.preferences = preferences
        self.usage = usage
        self.selectedPlanID = selectedPlanID
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

    public init(
        id: UUID = UUID(),
        planID: UUID,
        planName: String,
        startedAt: Date,
        completedAt: Date,
        plannedDurationSeconds: Int,
        elapsedDurationSeconds: Int,
        roundCount: Int,
        exerciseCount: Int
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
    }
}

public struct UserPreferences: Codable, Equatable, Sendable {
    public var cueStyle: CueStyle
    public var hapticsEnabled: Bool
    public var pauseWhenInactive: Bool
    public var countdownEnabled: Bool
    public var keepScreenAwake: Bool
    public var appearance: AppearancePreference
    public var reminders: ReminderSettings

    public init(
        cueStyle: CueStyle = .tones,
        hapticsEnabled: Bool = true,
        pauseWhenInactive: Bool = false,
        countdownEnabled: Bool = true,
        keepScreenAwake: Bool = true,
        appearance: AppearancePreference = .system,
        reminders: ReminderSettings = ReminderSettings()
    ) {
        self.cueStyle = cueStyle
        self.hapticsEnabled = hapticsEnabled
        self.pauseWhenInactive = pauseWhenInactive
        self.countdownEnabled = countdownEnabled
        self.keepScreenAwake = keepScreenAwake
        self.appearance = appearance
        self.reminders = reminders
    }
}

public enum CueStyle: String, Codable, CaseIterable, Sendable {
    case tones
    case spoken
    case silent
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

