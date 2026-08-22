import Foundation

public struct HistorySummary: Equatable, Sendable {
    public var completedWorkouts: Int
    public var totalDurationSeconds: Int
    public var currentStreakDays: Int

    public init(
        completedWorkouts: Int,
        totalDurationSeconds: Int,
        currentStreakDays: Int
    ) {
        self.completedWorkouts = completedWorkouts
        self.totalDurationSeconds = totalDurationSeconds
        self.currentStreakDays = currentStreakDays
    }

    public static func calculate(
        entries: [WorkoutHistoryEntry],
        now: Date,
        calendar: Calendar = .current
    ) -> HistorySummary {
        let days = Set(entries.map { calendar.startOfDay(for: $0.completedAt) })
        var streak = 0
        var cursor = calendar.startOfDay(for: now)

        if !days.contains(cursor),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
           days.contains(yesterday) {
            cursor = yesterday
        }

        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return HistorySummary(
            completedWorkouts: entries.count,
            totalDurationSeconds: entries.reduce(0) { $0 + $1.elapsedDurationSeconds },
            currentStreakDays: streak
        )
    }
}

