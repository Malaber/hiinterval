import Foundation

public struct UsageRecord: Codable, Equatable, Sendable {
    public var trialStartedAt: Date?
    public var completedWorkoutDates: [Date]
    public var purchasedUnlimited: Bool

    public init(
        trialStartedAt: Date? = nil,
        completedWorkoutDates: [Date] = [],
        purchasedUnlimited: Bool = false
    ) {
        self.trialStartedAt = trialStartedAt
        self.completedWorkoutDates = completedWorkoutDates
        self.purchasedUnlimited = purchasedUnlimited
    }
}

public struct EntitlementPolicy: Equatable, Sendable {
    public var monetizationEnabled: Bool
    public var trialDays: Int
    public var trialWorkoutLimit: Int

    public init(
        monetizationEnabled: Bool = false,
        trialDays: Int = 30,
        trialWorkoutLimit: Int = 5
    ) {
        self.monetizationEnabled = monetizationEnabled
        self.trialDays = trialDays
        self.trialWorkoutLimit = trialWorkoutLimit
    }

    public func access(
        for usage: UsageRecord,
        now: Date,
        calendar: Calendar = .current
    ) -> WorkoutAccess {
        guard monetizationEnabled else { return .freeLaunch }
        if usage.purchasedUnlimited { return .purchased }

        guard let trialStart = usage.trialStartedAt else {
            return .trial(workoutsRemaining: trialWorkoutLimit, daysRemaining: trialDays)
        }

        let trialEnd = calendar.date(byAdding: .day, value: trialDays, to: trialStart) ?? trialStart
        let trialWorkouts = usage.completedWorkoutDates.filter { $0 >= trialStart }.count
        if now < trialEnd, trialWorkouts < trialWorkoutLimit {
            let days = max(0, calendar.dateComponents([.day], from: now, to: trialEnd).day ?? 0)
            return .trial(
                workoutsRemaining: max(0, trialWorkoutLimit - trialWorkouts),
                daysRemaining: days
            )
        }

        let alreadyUsedMonthlyCredit = usage.completedWorkoutDates.contains {
            calendar.isDate($0, equalTo: now, toGranularity: .month) && $0 >= trialEnd
        }
        return alreadyUsedMonthlyCredit ? .locked : .monthlyCredit
    }
}

public enum WorkoutAccess: Equatable, Sendable {
    case freeLaunch
    case purchased
    case trial(workoutsRemaining: Int, daysRemaining: Int)
    case monthlyCredit
    case locked

    public var canStartWorkout: Bool {
        self != .locked
    }
}

