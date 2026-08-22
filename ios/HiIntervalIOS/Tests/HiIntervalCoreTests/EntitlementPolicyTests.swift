import XCTest
@testable import HiIntervalCore

final class EntitlementPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testCurrentFreeLaunchAlwaysAllowsWorkouts() {
        let policy = EntitlementPolicy()
        let usage = UsageRecord(
            trialStartedAt: date(2025, 1, 1),
            completedWorkoutDates: (1...20).map { date(2025, 1, $0) }
        )

        XCTAssertEqual(policy.access(for: usage, now: date(2026, 8, 22), calendar: calendar), .freeLaunch)
        XCTAssertTrue(policy.access(for: usage, now: date(2026, 8, 22), calendar: calendar).canStartWorkout)
    }

    func testFutureTrialEndsWhenWorkoutLimitReached() {
        let policy = EntitlementPolicy(monetizationEnabled: true)
        let start = date(2026, 8, 1)
        let four = (1...4).map { date(2026, 8, $0 + 1) }

        XCTAssertEqual(
            policy.access(
                for: UsageRecord(trialStartedAt: start, completedWorkoutDates: four),
                now: date(2026, 8, 10),
                calendar: calendar
            ),
            .trial(workoutsRemaining: 1, daysRemaining: 21)
        )

        let five = four + [date(2026, 8, 7)]
        XCTAssertEqual(
            policy.access(
                for: UsageRecord(trialStartedAt: start, completedWorkoutDates: five),
                now: date(2026, 8, 10),
                calendar: calendar
            ),
            .monthlyCredit
        )

        let monthlyCreditUsed = five + [date(2026, 8, 8)]
        XCTAssertEqual(
            policy.access(
                for: UsageRecord(trialStartedAt: start, completedWorkoutDates: monthlyCreditUsed),
                now: date(2026, 8, 10),
                calendar: calendar
            ),
            .locked
        )
        XCTAssertEqual(
            policy.access(
                for: UsageRecord(trialStartedAt: start, completedWorkoutDates: monthlyCreditUsed),
                now: date(2026, 9, 1),
                calendar: calendar
            ),
            .monthlyCredit
        )
    }

    func testFutureTrialEndsAtThirtyDayBoundary() {
        let policy = EntitlementPolicy(monetizationEnabled: true)
        let usage = UsageRecord(trialStartedAt: date(2026, 1, 1))

        XCTAssertTrue(
            policy.access(for: usage, now: date(2026, 1, 30), calendar: calendar).canStartWorkout
        )
        XCTAssertEqual(
            policy.access(for: usage, now: date(2026, 1, 31), calendar: calendar),
            .monthlyCredit
        )
    }

    func testMonthlyCreditDoesNotAccumulate() {
        let policy = EntitlementPolicy(monetizationEnabled: true)
        let start = date(2026, 1, 1)
        let usage = UsageRecord(
            trialStartedAt: start,
            completedWorkoutDates: [date(2026, 8, 3)]
        )

        XCTAssertEqual(policy.access(for: usage, now: date(2026, 8, 22), calendar: calendar), .locked)
        XCTAssertEqual(policy.access(for: usage, now: date(2026, 9, 1), calendar: calendar), .monthlyCredit)
    }

    func testWorkoutAfterDateTrialExpiryConsumesMonthlyCredit() {
        let policy = EntitlementPolicy(monetizationEnabled: true)
        let start = date(2026, 1, 1)
        let usage = UsageRecord(
            trialStartedAt: start,
            completedWorkoutDates: [
                date(2026, 1, 2),
                date(2026, 1, 3),
                date(2026, 2, 2),
            ]
        )

        XCTAssertEqual(
            policy.access(for: usage, now: date(2026, 2, 20), calendar: calendar),
            .locked
        )
        XCTAssertEqual(
            policy.access(for: usage, now: date(2026, 3, 1), calendar: calendar),
            .monthlyCredit
        )
    }

    func testPurchaseWinsAndUnstartedTrialReportsFullAllowance() {
        let policy = EntitlementPolicy(monetizationEnabled: true)
        XCTAssertEqual(
            policy.access(for: UsageRecord(), now: date(2026, 8, 22), calendar: calendar),
            .trial(workoutsRemaining: 5, daysRemaining: 30)
        )
        XCTAssertEqual(
            policy.access(
                for: UsageRecord(purchasedUnlimited: true),
                now: date(2030, 1, 1),
                calendar: calendar
            ),
            .purchased
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
