import XCTest
@testable import HiIntervalCore

final class IntervalTimerEngineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 10_000)

    func testStartsAndAdvancesAtExactBoundary() {
        var engine = makeEngine(durations: [5, 3])

        XCTAssertEqual(engine.start(at: start).count, 2)
        XCTAssertEqual(engine.state, .running)
        XCTAssertEqual(engine.displayedRemainingSeconds, 5)
        XCTAssertEqual(engine.tick(at: start.addingTimeInterval(4.2)), [])
        XCTAssertEqual(engine.displayedRemainingSeconds, 1)

        let events = engine.tick(at: start.addingTimeInterval(5))

        XCTAssertEqual(events, [.phaseStarted(engine.timeline.phases[1])])
        XCTAssertEqual(engine.currentPhaseIndex, 1)
        XCTAssertEqual(engine.remainingSeconds, 3, accuracy: 0.0001)
        XCTAssertEqual(engine.totalElapsedSeconds, 5, accuracy: 0.0001)
    }

    func testDelayedTickCrossesMultiplePhasesWithoutDrift() {
        var engine = makeEngine(durations: [2, 3, 5])
        _ = engine.start(at: start)

        let events = engine.tick(at: start.addingTimeInterval(7.5))

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(engine.currentPhaseIndex, 2)
        XCTAssertEqual(engine.remainingSeconds, 2.5, accuracy: 0.0001)
        XCTAssertEqual(engine.totalProgress, 0.75, accuracy: 0.0001)

        _ = engine.tick(at: start.addingTimeInterval(8.5))
        XCTAssertEqual(engine.remainingSeconds, 1.5, accuracy: 0.0001)
    }

    func testCompletionOccursOnce() {
        var engine = makeEngine(durations: [1])
        _ = engine.start(at: start)

        XCTAssertEqual(engine.tick(at: start.addingTimeInterval(1)), [.workoutCompleted])
        XCTAssertEqual(engine.state, .finished)
        XCTAssertEqual(engine.totalProgress, 1)
        XCTAssertNil(engine.currentPhase)
        XCTAssertEqual(engine.tick(at: start.addingTimeInterval(100)), [])
    }

    func testPauseFreezesAndResumeUsesNewAnchor() {
        var engine = makeEngine(durations: [10])
        _ = engine.start(at: start)

        XCTAssertEqual(engine.pause(at: start.addingTimeInterval(3)), [.paused])
        XCTAssertEqual(engine.remainingSeconds, 7, accuracy: 0.0001)
        XCTAssertEqual(engine.tick(at: start.addingTimeInterval(50)), [])
        XCTAssertEqual(engine.remainingSeconds, 7, accuracy: 0.0001)

        XCTAssertEqual(engine.resume(at: start.addingTimeInterval(50)), [.resumed])
        _ = engine.tick(at: start.addingTimeInterval(52))
        XCTAssertEqual(engine.remainingSeconds, 5, accuracy: 0.0001)
    }

    func testSkipWorksWhileRunningAndPaused() {
        var running = makeEngine(durations: [10, 20])
        _ = running.start(at: start)
        XCTAssertEqual(
            running.skip(at: start.addingTimeInterval(2)),
            [.phaseStarted(running.timeline.phases[1])]
        )
        XCTAssertEqual(running.remainingSeconds, 20)
        _ = running.tick(at: start.addingTimeInterval(3))
        XCTAssertEqual(running.remainingSeconds, 19, accuracy: 0.0001)

        var paused = makeEngine(durations: [10, 20])
        _ = paused.start(at: start)
        _ = paused.pause(at: start.addingTimeInterval(2))
        _ = paused.skip(at: start.addingTimeInterval(100))
        XCTAssertEqual(paused.state, .paused)
        XCTAssertEqual(paused.remainingSeconds, 20)
    }

    func testSkipLastPhaseFinishesAndRestartRestoresPhase() {
        var engine = makeEngine(durations: [4])
        _ = engine.start(at: start)
        _ = engine.tick(at: start.addingTimeInterval(2))

        XCTAssertEqual(engine.restartPhase(at: start.addingTimeInterval(2)), [.phaseRestarted(engine.timeline.phases[0])])
        XCTAssertEqual(engine.remainingSeconds, 4)
        XCTAssertEqual(engine.skip(at: start.addingTimeInterval(2)), [.workoutCompleted])
        XCTAssertEqual(engine.state, .finished)
    }

    func testBackwardsClockDoesNotAddTimeOrAdvance() {
        var engine = makeEngine(durations: [5])
        _ = engine.start(at: start)

        XCTAssertEqual(engine.tick(at: start.addingTimeInterval(-100)), [])
        XCTAssertEqual(engine.remainingSeconds, 5)
    }

    func testEmptyTimelineCompletesOnStart() {
        var engine = IntervalTimerEngine(
            timeline: WorkoutTimeline(planID: UUID(), planName: "Empty", phases: [])
        )

        XCTAssertEqual(engine.start(at: start), [.workoutCompleted])
        XCTAssertEqual(engine.state, .finished)
        XCTAssertEqual(engine.totalProgress, 1)
    }

    func testProgressAndNextPhaseExposeGlanceableState() {
        var engine = makeEngine(durations: [10, 5])

        XCTAssertEqual(engine.nextPhase, engine.timeline.phases[1])
        XCTAssertEqual(engine.phaseProgress, 0)
        _ = engine.start(at: start)
        _ = engine.tick(at: start.addingTimeInterval(2.5))
        XCTAssertEqual(engine.phaseProgress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(engine.totalElapsedSeconds, 2.5, accuracy: 0.0001)

        _ = engine.skip(at: start.addingTimeInterval(2.5))
        XCTAssertNil(engine.nextPhase)
    }

    func testInvalidStateActionsAreNoOps() {
        var engine = makeEngine(durations: [2])

        XCTAssertEqual(engine.tick(at: start), [])
        XCTAssertEqual(engine.pause(at: start), [])
        XCTAssertEqual(engine.resume(at: start), [])
        XCTAssertEqual(engine.skip(at: start), [])
        XCTAssertEqual(engine.restartPhase(at: start), [])

        _ = engine.start(at: start)
        XCTAssertEqual(engine.start(at: start), [])
        _ = engine.pause(at: start)
        XCTAssertEqual(engine.pause(at: start), [])
        _ = engine.resume(at: start)
        XCTAssertEqual(engine.resume(at: start), [])
    }

    func testPauseAndSkipPropagateCompletionReachedByClock() {
        var pausing = makeEngine(durations: [1])
        _ = pausing.start(at: start)
        XCTAssertEqual(pausing.pause(at: start.addingTimeInterval(2)), [.workoutCompleted])

        var skipping = makeEngine(durations: [1])
        _ = skipping.start(at: start)
        XCTAssertEqual(skipping.skip(at: start.addingTimeInterval(2)), [.workoutCompleted])
    }

    func testDelayedRestartAdvancesThenRestartsCurrentPhase() {
        var engine = makeEngine(durations: [2, 3])
        let secondPhase = engine.timeline.phases[1]
        _ = engine.start(at: start)

        let events = engine.restartPhase(at: start.addingTimeInterval(3))

        XCTAssertEqual(engine.currentPhaseIndex, 1)
        XCTAssertEqual(engine.remainingSeconds, 3)
        XCTAssertEqual(events, [.phaseStarted(secondPhase), .phaseRestarted(secondPhase)])
    }

    func testDelayedRestartPropagatesCompletionWithoutRestarting() {
        var engine = makeEngine(durations: [2, 3])
        _ = engine.start(at: start)

        let events = engine.restartPhase(at: start.addingTimeInterval(8))

        XCTAssertEqual(engine.state, .finished)
        XCTAssertEqual(events.last, .workoutCompleted)
        XCTAssertFalse(events.contains { event in
            if case .phaseRestarted = event { return true }
            return false
        })
    }

    private func makeEngine(durations: [Int]) -> IntervalTimerEngine {
        let phases = durations.enumerated().map { index, duration in
            WorkoutPhase(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                kind: index.isMultiple(of: 2) ? .work : .recovery,
                title: "Phase \(index)",
                durationSeconds: duration
            )
        }
        return IntervalTimerEngine(
            timeline: WorkoutTimeline(planID: UUID(), planName: "Test", phases: phases)
        )
    }
}
