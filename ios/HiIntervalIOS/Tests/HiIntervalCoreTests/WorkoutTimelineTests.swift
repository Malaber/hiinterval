import XCTest
@testable import HiIntervalCore

final class WorkoutTimelineTests: XCTestCase {
    func testBuildsCompleteRepeatedTimelineWithoutTrailingRoundRecovery() throws {
        let plan = makePlan(
            warmUp: 5,
            work: 10,
            recovery: 3,
            roundRecovery: 7,
            coolDown: 4,
            rounds: 2,
            exercises: [ExerciseStep(name: "Squat"), ExerciseStep(name: "Plank")]
        )

        let timeline = try WorkoutTimeline(plan: plan)

        XCTAssertEqual(
            timeline.phases.map(\.kind),
            [
                .warmUp,
                .work, .recovery,
                .work,
                .roundRecovery,
                .work, .recovery,
                .work,
                .coolDown,
            ]
        )
        XCTAssertEqual(timeline.totalDurationSeconds, 62)
        XCTAssertEqual(timeline.phases[1].position?.roundIndex, 1)
        XCTAssertEqual(timeline.phases[6].position?.roundIndex, 2)
        XCTAssertEqual(timeline.phases[7].position?.exerciseIndex, 2)
    }

    func testExpandsLeftRightStepAndPreservesTotalWorkDuration() throws {
        let step = ExerciseStep(
            name: "Split squat",
            duration: .custom(seconds: 41),
            recovery: .none,
            sideConfiguration: .leftRight(firstSide: .right, switchSeconds: 3)
        )
        let plan = makePlan(
            warmUp: 0,
            work: 30,
            recovery: 0,
            roundRecovery: 0,
            coolDown: 0,
            rounds: 1,
            exercises: [step]
        )

        let phases = try WorkoutTimeline(plan: plan).phases

        XCTAssertEqual(phases.map(\.kind), [.work, .sideSwitch, .work])
        XCTAssertEqual(phases.map(\.durationSeconds), [21, 3, 20])
        XCTAssertEqual(phases.map(\.side), [.right, .left, .left])
        XCTAssertEqual(phases.reduce(0) { $0 + $1.durationSeconds }, 44)
    }

    func testRoundOverrideCanChangeDurationAndSplitOnlyOneRound() throws {
        var plan = makePlan(
            warmUp: 0,
            work: 20,
            recovery: 0,
            roundRecovery: 0,
            coolDown: 0,
            rounds: 2,
            exercises: [ExerciseStep(name: "Lunge", recovery: .none)]
        )
        plan.roundOverrides = [
            WorkoutRoundOverride(
                roundNumber: 2,
                workSeconds: 30,
                sideConfiguration: .leftRight(firstSide: .left, switchSeconds: 2)
            ),
        ]

        let phases = try WorkoutTimeline(plan: plan).phases

        XCTAssertEqual(phases.map(\.durationSeconds), [20, 15, 2, 15])
        XCTAssertEqual(phases.map(\.side), [nil, .left, .right, .right])
        XCTAssertEqual(phases.last?.position?.roundIndex, 2)
    }

    func testCustomRecoveryAndNoRecoveryResolveCorrectly() throws {
        let plan = makePlan(
            warmUp: 0,
            work: 10,
            recovery: 5,
            roundRecovery: 0,
            coolDown: 0,
            rounds: 1,
            exercises: [
                ExerciseStep(name: "A", recovery: .custom(seconds: 8)),
                ExerciseStep(name: "B", recovery: .none),
            ]
        )

        let phases = try WorkoutTimeline(plan: plan).phases

        XCTAssertEqual(phases.map(\.kind), [.work, .recovery, .work])
        XCTAssertEqual(phases.map(\.durationSeconds), [10, 8, 10])
    }

    func testValidationRejectsInvalidRecipes() {
        assertValidationError(makePlan(name: " "), equals: .emptyName)
        assertValidationError(makePlan(exercises: []), equals: .emptyExercises)
        assertValidationError(makePlan(rounds: 0), equals: .invalidRoundCount)
        assertValidationError(makePlan(work: -1), equals: .invalidDuration(field: "Default work"))
        assertValidationError(
            makePlan(exercises: [ExerciseStep(name: "")]),
            equals: .emptyExerciseName(index: 0)
        )
        assertValidationError(
            makePlan(
                work: 1,
                exercises: [ExerciseStep(name: "Split", sideConfiguration: .leftRight())]
            ),
            equals: .splitDurationTooShort(index: 0)
        )
    }

    func testStarterPlanIsValidAndStable() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plan = WorkoutPlan.starter(now: now)

        XCTAssertNoThrow(try plan.validate())
        XCTAssertEqual(plan.createdAt, now)
        XCTAssertEqual(plan.updatedAt, now)
        XCTAssertEqual(plan.exercises.count, 4)
        XCTAssertGreaterThan(try WorkoutTimeline(plan: plan).totalDurationSeconds, 0)
    }

    private func assertValidationError(
        _ plan: WorkoutPlan,
        equals expected: WorkoutValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try WorkoutTimeline(plan: plan), file: file, line: line) { error in
            XCTAssertEqual(error as? WorkoutValidationError, expected, file: file, line: line)
            XCTAssertNotNil((error as? WorkoutValidationError)?.errorDescription, file: file, line: line)
        }
    }
}

private func makePlan(
    name: String = "Test",
    warmUp: Int = 0,
    work: Int = 20,
    recovery: Int = 0,
    roundRecovery: Int = 0,
    coolDown: Int = 0,
    rounds: Int = 1,
    exercises: [ExerciseStep] = [ExerciseStep(name: "Move", recovery: .none)]
) -> WorkoutPlan {
    WorkoutPlan(
        name: name,
        warmUpSeconds: warmUp,
        defaultWorkSeconds: work,
        defaultRecoverySeconds: recovery,
        roundRecoverySeconds: roundRecovery,
        coolDownSeconds: coolDown,
        roundCount: rounds,
        exercises: exercises,
        createdAt: Date(timeIntervalSince1970: 100),
        updatedAt: Date(timeIntervalSince1970: 100)
    )
}
