import XCTest
@testable import HiIntervalCore

final class OneMoreRoundTests: XCTestCase {
    func testRecoverySubtractsElapsedTimeAndKeepsReactionMinimum() {
        let policy = OneMoreRoundRecovery()

        XCTAssertEqual(policy.remainingSeconds(configuredSeconds: 60, elapsedSeconds: 12.9), 48)
        XCTAssertEqual(policy.remainingSeconds(configuredSeconds: 60, elapsedSeconds: 58), 10)
        XCTAssertEqual(policy.remainingSeconds(configuredSeconds: 0, elapsedSeconds: 4), 10)
        XCTAssertEqual(policy.remainingSeconds(configuredSeconds: -2, elapsedSeconds: -4), 10)
        XCTAssertEqual(
            OneMoreRoundRecovery(minimumSeconds: -1)
                .remainingSeconds(configuredSeconds: 3, elapsedSeconds: 1),
            2
        )
    }

    func testTimelineStartsWithRecoveryThenRunsOneFullDefaultRound() throws {
        var plan = WorkoutPlan(
            name: "Intervals",
            warmUpSeconds: 15,
            defaultWorkSeconds: 20,
            defaultRecoverySeconds: 5,
            roundRecoverySeconds: 60,
            roundRecoveryNotes: "  Breathe deeply  ",
            coolDownSeconds: 30,
            roundCount: 3,
            exercises: [
                ExerciseStep(name: "Squat"),
                ExerciseStep(
                    name: "Lunge",
                    duration: .custom(seconds: 10),
                    recovery: .none,
                    sideConfiguration: .leftRight(switchSeconds: 2)
                ),
            ]
        )
        plan.roundOverrides = [WorkoutRoundOverride(roundNumber: 3, workSeconds: 45)]

        let timeline = try WorkoutTimeline.oneMoreRound(
            for: plan,
            recoverySeconds: 42,
            roundNumber: 4
        )

        XCTAssertEqual(
            timeline.phases.map(\.kind),
            [.roundRecovery, .work, .recovery, .work, .sideSwitch, .work]
        )
        XCTAssertEqual(timeline.phases.map(\.durationSeconds), [42, 20, 5, 5, 2, 5])
        XCTAssertEqual(timeline.phases.first?.notes, "Breathe deeply")
        XCTAssertTrue(timeline.phases.dropFirst().allSatisfy { $0.position?.roundIndex == 4 })
        XCTAssertTrue(timeline.phases.allSatisfy { $0.position?.roundCount == 4 })
        XCTAssertEqual(timeline.totalDurationSeconds, 79)
    }

    func testTimelineAdvancesRoundNumberAndNormalizesEmptyRecovery() throws {
        var plan = WorkoutPlan(
            name: "Short",
            roundRecoveryNotes: "   ",
            coolDownSeconds: 0,
            roundCount: 2,
            exercises: [ExerciseStep(name: "Move", recovery: .none)]
        )
        plan.warmUpSeconds = 0

        let timeline = try WorkoutTimeline.oneMoreRound(
            for: plan,
            recoverySeconds: -3,
            roundNumber: 1
        )

        XCTAssertEqual(timeline.phases.first?.durationSeconds, 0)
        XCTAssertNil(timeline.phases.first?.notes)
        XCTAssertTrue(timeline.phases.allSatisfy { $0.position?.roundIndex == 3 })
    }
}
