import XCTest
@testable import HiIntervalCore

final class ActiveDurationTrackerTests: XCTestCase {
    func testPausedTimeIsExcludedAcrossMultipleRunningSegments() {
        let origin = Date(timeIntervalSince1970: 1_000)
        var tracker = ActiveDurationTracker()

        tracker.start(at: origin)
        tracker.start(at: origin.addingTimeInterval(1))
        XCTAssertEqual(tracker.elapsed(at: origin.addingTimeInterval(5)), 5)

        tracker.pause(at: origin.addingTimeInterval(5))
        tracker.pause(at: origin.addingTimeInterval(8))
        XCTAssertEqual(tracker.elapsed(at: origin.addingTimeInterval(20)), 5)

        tracker.start(at: origin.addingTimeInterval(20))
        tracker.pause(at: origin.addingTimeInterval(23))

        XCTAssertEqual(tracker.accumulatedSeconds, 8)
        XCTAssertFalse(tracker.isRunning)
    }

    func testBackwardsClockNeverSubtractsActiveTime() {
        let origin = Date(timeIntervalSince1970: 1_000)
        var tracker = ActiveDurationTracker()

        tracker.start(at: origin)
        XCTAssertEqual(tracker.elapsed(at: origin.addingTimeInterval(-5)), 0)
        tracker.pause(at: origin.addingTimeInterval(-5))

        XCTAssertEqual(tracker.accumulatedSeconds, 0)
    }
}
