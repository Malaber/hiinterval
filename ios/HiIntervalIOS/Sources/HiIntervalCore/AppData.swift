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
    public var pauseWhenInactive: Bool
    public var countdownEnabled: Bool
    public var keepScreenAwake: Bool
    public var appearance: AppearancePreference
    public var reminders: ReminderSettings

    public init(
        cueStyle: CueStyle = .tones,
        cueLanguage: CueLanguage = .system,
        hapticsEnabled: Bool = true,
        pauseWhenInactive: Bool = false,
        countdownEnabled: Bool = true,
        keepScreenAwake: Bool = true,
        appearance: AppearancePreference = .system,
        reminders: ReminderSettings = ReminderSettings()
    ) {
        self.cueStyle = cueStyle
        self.cueLanguage = cueLanguage
        self.hapticsEnabled = hapticsEnabled
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
        pauseWhenInactive = try values.decodeIfPresent(Bool.self, forKey: .pauseWhenInactive) ?? false
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
