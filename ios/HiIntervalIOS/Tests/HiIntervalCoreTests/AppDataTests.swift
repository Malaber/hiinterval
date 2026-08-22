import XCTest
@testable import HiIntervalCore

final class AppDataTests: XCTestCase {
    func testAppDataRoundTripsThroughJSON() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var data = AppData.starter(now: now)
        data.preferences.cueStyle = .spoken
        data.preferences.reminders = ReminderSettings(
            enabled: true,
            weekdays: [2, 4, 6],
            hour: 7,
            minute: 30
        )
        data.usage.completedWorkoutDates = [now]

        let encoded = try AppDataCodec.encode(data)
        let decoded = try AppDataCodec.decode(encoded)

        XCTAssertEqual(decoded, data)
        XCTAssertFalse(encoded.isEmpty)
    }

    func testHistorySummaryCountsDurationAndCurrentStreak() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 22, hour: 12))!
        let dates = [18, 19, 20, 21].map {
            calendar.date(from: DateComponents(year: 2026, month: 8, day: $0, hour: 9))!
        }
        let entries = dates.enumerated().map { index, date in
            makeEntry(date: date, seconds: (index + 1) * 60)
        }

        let summary = HistorySummary.calculate(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(summary.completedWorkouts, 4)
        XCTAssertEqual(summary.totalDurationSeconds, 600)
        XCTAssertEqual(summary.currentStreakDays, 4)
    }

    func testHistoryStreakIsZeroWhenTodayAndYesterdayMissing() {
        let old = Date(timeIntervalSince1970: 100)
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(
            HistorySummary.calculate(entries: [makeEntry(date: old)], now: now).currentStreakDays,
            0
        )
    }

    func testPreferencesDecodeOlderDataWithoutCueLanguage() throws {
        let json = """
        {
          "appearance": "system",
          "countdownEnabled": true,
          "cueStyle": "spoken",
          "hapticsEnabled": true,
          "keepScreenAwake": true,
          "pauseWhenInactive": false,
          "reminders": {
            "enabled": false,
            "hour": 18,
            "minute": 0,
            "weekdays": []
          }
        }
        """

        let preferences = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))

        XCTAssertEqual(preferences.cueStyle, .spoken)
        XCTAssertEqual(preferences.cueLanguage, .system)
    }

    func testPreferencesDecodeMissingFieldsWithSafeDefaults() throws {
        let preferences = try JSONDecoder().decode(UserPreferences.self, from: Data("{}".utf8))

        XCTAssertEqual(preferences, UserPreferences())
    }

    private func makeEntry(date: Date, seconds: Int = 60) -> WorkoutHistoryEntry {
        WorkoutHistoryEntry(
            planID: UUID(),
            planName: "Plan",
            startedAt: date.addingTimeInterval(TimeInterval(-seconds)),
            completedAt: date,
            plannedDurationSeconds: seconds,
            elapsedDurationSeconds: seconds,
            roundCount: 1,
            exerciseCount: 1
        )
    }
}
