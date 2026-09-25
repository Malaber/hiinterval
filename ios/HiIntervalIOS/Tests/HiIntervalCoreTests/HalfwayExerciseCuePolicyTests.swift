import XCTest
@testable import HiIntervalCore

final class HalfwayExerciseCuePolicyTests: XCTestCase {
    func testTogetherExerciseEmitsOnceAtHalfActiveWork() {
        let timeline = timeline(
            phases: [work(name: "Squat", seconds: 10, round: 1, exercise: 1)]
        )
        var tracker = HalfwayExerciseCueTracker()

        XCTAssertNil(tracker.nextCue(in: timeline, currentPhaseIndex: 0, elapsedSeconds: 4.999))
        XCTAssertEqual(
            tracker.nextCue(in: timeline, currentPhaseIndex: 0, elapsedSeconds: 5),
            HalfwayExerciseCue(
                exerciseName: "Squat",
                position: position(round: 1, exercise: 1),
                offsetSeconds: 5
            )
        )
        XCTAssertNil(tracker.nextCue(in: timeline, currentPhaseIndex: 0, elapsedSeconds: 9))
    }

    func testSplitExerciseCountsBothWorkSidesAndExcludesSwitchTime() {
        let timeline = timeline(
            phases: [
                work(name: "Lunge", seconds: 6, round: 1, exercise: 1),
                sideSwitch(seconds: 4, round: 1, exercise: 1),
                work(name: "Lunge", seconds: 4, round: 1, exercise: 1),
            ]
        )
        var tracker = HalfwayExerciseCueTracker()

        XCTAssertEqual(
            tracker.nextCue(in: timeline, currentPhaseIndex: 0, elapsedSeconds: 5),
            HalfwayExerciseCue(
                exerciseName: "Lunge",
                position: position(round: 1, exercise: 1),
                offsetSeconds: 5
            )
        )
        XCTAssertNil(tracker.nextCue(in: timeline, currentPhaseIndex: 1, elapsedSeconds: 6))
    }

    func testSplitExerciseMidpointAfterSwitchIncludesSwitchInTimelineOffset() {
        let timeline = timeline(
            phases: [
                work(name: "Lunge", seconds: 3, round: 1, exercise: 1),
                sideSwitch(seconds: 4, round: 1, exercise: 1),
                work(name: "Lunge", seconds: 7, round: 1, exercise: 1),
            ]
        )
        var tracker = HalfwayExerciseCueTracker()

        XCTAssertNil(tracker.nextCue(in: timeline, currentPhaseIndex: 1, elapsedSeconds: 7))
        XCTAssertEqual(
            tracker.nextCue(in: timeline, currentPhaseIndex: 2, elapsedSeconds: 9),
            HalfwayExerciseCue(
                exerciseName: "Lunge",
                position: position(round: 1, exercise: 1),
                offsetSeconds: 9
            )
        )
    }

    func testRecoveryNeverEmitsLateCueAndNextExerciseCanEmit() {
        let timeline = timeline(
            phases: [
                work(name: "Squat", seconds: 10, round: 1, exercise: 1),
                recovery(seconds: 5, round: 1, exercise: 1),
                work(name: "Plank", seconds: 10, round: 1, exercise: 2),
            ]
        )
        var tracker = HalfwayExerciseCueTracker()

        XCTAssertNil(tracker.nextCue(in: timeline, currentPhaseIndex: 1, elapsedSeconds: 12))
        XCTAssertEqual(
            tracker.nextCue(in: timeline, currentPhaseIndex: 2, elapsedSeconds: 20),
            HalfwayExerciseCue(
                exerciseName: "Plank",
                position: position(round: 1, exercise: 2),
                offsetSeconds: 20
            )
        )
    }

    func testRoundsAreDistinctOccurrencesAndInvalidCurrentPhaseIsIgnored() {
        let timeline = timeline(
            phases: [
                work(name: "Squat", seconds: 8, round: 1, exercise: 1),
                work(name: "Squat", seconds: 8, round: 2, exercise: 1),
            ]
        )
        var tracker = HalfwayExerciseCueTracker()

        XCTAssertNil(tracker.nextCue(in: timeline, currentPhaseIndex: -1, elapsedSeconds: 4))
        XCTAssertEqual(tracker.nextCue(in: timeline, currentPhaseIndex: 0, elapsedSeconds: 4)?.position.roundIndex, 1)
        XCTAssertEqual(tracker.nextCue(in: timeline, currentPhaseIndex: 1, elapsedSeconds: 12)?.position.roundIndex, 2)
    }

    func testOddShortDurationsDelayedTicksRestartAndPause() {
        let timeline = timeline(phases: [work(name: "Squat", seconds: 5, round: 1, exercise: 1)])
        var tracker = HalfwayExerciseCueTracker()
        var engine = IntervalTimerEngine(timeline: timeline)
        let start = Date(timeIntervalSince1970: 0)
        _ = engine.start(at: start)
        _ = engine.tick(at: start.addingTimeInterval(2))
        XCTAssertNil(tracker.nextCue(in: timeline, currentPhaseIndex: 0, elapsedSeconds: engine.totalElapsedSeconds))
        _ = engine.pause(at: start.addingTimeInterval(2))
        _ = engine.tick(at: start.addingTimeInterval(90))
        XCTAssertEqual(engine.totalElapsedSeconds, 2)
        _ = engine.resume(at: start.addingTimeInterval(90))
        _ = engine.tick(at: start.addingTimeInterval(92))
        XCTAssertEqual(tracker.nextCue(in: timeline, currentPhaseIndex: 0, elapsedSeconds: engine.totalElapsedSeconds)?.offsetSeconds, 2.5)
        _ = engine.restartPhase(at: start.addingTimeInterval(92))
        _ = engine.tick(at: start.addingTimeInterval(95))
        XCTAssertNil(tracker.nextCue(in: timeline, currentPhaseIndex: 0, elapsedSeconds: engine.totalElapsedSeconds))
        var short = HalfwayExerciseCueTracker()
        let shortTimeline = self.timeline(phases: [work(name: "One", seconds: 1, round: 1, exercise: 1)])
        XCTAssertEqual(short.nextCue(in: shortTimeline, currentPhaseIndex: 0, elapsedSeconds: 0.5)?.offsetSeconds, 0.5)
    }

    func testMissingPositionOrActiveWorkDoesNotEmit() {
        var tracker = HalfwayExerciseCueTracker()
        let noPosition = timeline(phases: [WorkoutPhase(kind: .work, title: "Work", durationSeconds: 10)])
        XCTAssertNil(tracker.nextCue(in: noPosition, currentPhaseIndex: 0, elapsedSeconds: 9))
        let switchOnly = timeline(phases: [sideSwitch(seconds: 4, round: 1, exercise: 1)])
        XCTAssertNil(tracker.nextCue(in: switchOnly, currentPhaseIndex: 0, elapsedSeconds: 3))
        let zeroWork = timeline(phases: [work(name: "Zero", seconds: 0, round: 1, exercise: 1)])
        XCTAssertNil(tracker.nextCue(in: zeroWork, currentPhaseIndex: 0, elapsedSeconds: 0))
    }

    func testSkippedSplitDoesNotAnnounceButNextExerciseStillDoes() {
        let timeline = timeline(phases: [
            work(name: "Lunge", seconds: 5, round: 1, exercise: 1),
            sideSwitch(seconds: 2, round: 1, exercise: 1),
            work(name: "Lunge", seconds: 5, round: 1, exercise: 1),
            work(name: "Plank", seconds: 10, round: 1, exercise: 2),
        ])
        var tracker = HalfwayExerciseCueTracker()
        tracker.suppressCue(for: nil)
        tracker.suppressCue(for: position(round: 1, exercise: 1))
        XCTAssertNil(tracker.nextCue(in: timeline, currentPhaseIndex: 1, elapsedSeconds: 6))
        XCTAssertNil(tracker.nextCue(in: timeline, currentPhaseIndex: 2, elapsedSeconds: 10))
        XCTAssertEqual(tracker.nextCue(in: timeline, currentPhaseIndex: 3, elapsedSeconds: 17)?.exerciseName, "Plank")
    }

    private func timeline(phases: [WorkoutPhase]) -> WorkoutTimeline {
        WorkoutTimeline(planID: UUID(), planName: "Test", phases: phases)
    }

    private func position(round: Int, exercise: Int) -> PhasePosition {
        PhasePosition(roundIndex: round, roundCount: 2, exerciseIndex: exercise, exerciseCount: 2)
    }

    private func work(name: String, seconds: Int, round: Int, exercise: Int) -> WorkoutPhase {
        WorkoutPhase(
            kind: .work,
            title: name,
            durationSeconds: seconds,
            position: position(round: round, exercise: exercise)
        )
    }

    private func sideSwitch(seconds: Int, round: Int, exercise: Int) -> WorkoutPhase {
        WorkoutPhase(
            kind: .sideSwitch,
            title: "Switch sides",
            durationSeconds: seconds,
            position: position(round: round, exercise: exercise)
        )
    }

    private func recovery(seconds: Int, round: Int, exercise: Int) -> WorkoutPhase {
        WorkoutPhase(
            kind: .recovery,
            title: "Recover",
            durationSeconds: seconds,
            position: position(round: round, exercise: exercise)
        )
    }
}
