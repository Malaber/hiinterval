import XCTest
@testable import HiIntervalCore

final class CompletionCelebrationTests: XCTestCase {
    func testCelebrationMovesFromForegroundToBackgroundAtBoundary() {
        let timeline = CompletionCelebrationTimeline(foregroundDurationSeconds: 1.2)

        XCTAssertEqual(timeline.stage(atElapsedSeconds: 0), .foreground)
        XCTAssertEqual(timeline.stage(atElapsedSeconds: 1.19), .foreground)
        XCTAssertEqual(timeline.stage(atElapsedSeconds: 1.2), .background)
        XCTAssertEqual(timeline.stage(atElapsedSeconds: 4), .background)
    }

    func testCelebrationClampsNegativeForegroundDuration() {
        let timeline = CompletionCelebrationTimeline(foregroundDurationSeconds: -1)

        XCTAssertEqual(timeline.foregroundDurationSeconds, 0)
        XCTAssertEqual(timeline.stage(atElapsedSeconds: 0), .background)
    }
}
