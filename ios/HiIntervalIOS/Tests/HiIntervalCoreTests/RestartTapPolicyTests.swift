import XCTest
@testable import HiIntervalCore

final class RestartTapPolicyTests: XCTestCase {
    func testFirstTapRestartsAndSecondWithinInclusiveWindowGoesBack() {
        var policy = RestartTapPolicy()
        XCTAssertEqual(policy.tap(at: 100, canGoBack: true), .restart)
        XCTAssertTrue(policy.isArmed(at: 100))
        XCTAssertTrue(policy.isArmed(at: 100 + RestartTapPolicy.windowDuration))
        XCTAssertEqual(
            policy.tap(at: 100 + RestartTapPolicy.windowDuration, canGoBack: true),
            .previous
        )
        XCTAssertFalse(policy.isArmed(at: 101))
    }

    func testExpiredSecondTapRestartsAndRearms() {
        var policy = RestartTapPolicy()
        XCTAssertEqual(policy.tap(at: 0, canGoBack: true), .restart)
        XCTAssertFalse(policy.isArmed(at: RestartTapPolicy.windowDuration + 0.001))
        XCTAssertEqual(policy.tap(at: 1, canGoBack: true), .restart)
        XCTAssertTrue(policy.isArmed(at: 1))
        XCTAssertEqual(policy.tap(at: 1.1, canGoBack: true), .previous)
    }

    func testMissingPreviousTargetNeverArms() {
        var policy = RestartTapPolicy()
        XCTAssertEqual(policy.tap(at: 0, canGoBack: false), .restart)
        XCTAssertFalse(policy.isArmed(at: 0.1))
        XCTAssertEqual(policy.tap(at: 0.1, canGoBack: false), .restart)
        XCTAssertFalse(policy.isArmed(at: 0.2))
        XCTAssertEqual(policy.tap(at: 0.2, canGoBack: true), .restart)
    }

    func testResetAndRepeatedPairs() {
        var policy = RestartTapPolicy()
        XCTAssertEqual(policy.tap(at: 0, canGoBack: true), .restart)
        policy.reset()
        XCTAssertFalse(policy.isArmed(at: 0.1))
        XCTAssertEqual(policy.tap(at: 0.1, canGoBack: true), .restart)
        XCTAssertEqual(policy.tap(at: 0.2, canGoBack: true), .previous)
        XCTAssertEqual(policy.tap(at: 0.3, canGoBack: true), .restart)
        XCTAssertEqual(policy.tap(at: 0.4, canGoBack: true), .previous)
    }

    func testClockGoingBackwardsDoesNotTriggerPrevious() {
        var policy = RestartTapPolicy()
        XCTAssertEqual(policy.tap(at: 1, canGoBack: true), .restart)
        XCTAssertFalse(policy.isArmed(at: 0.9))
        XCTAssertEqual(policy.tap(at: 0.9, canGoBack: true), .restart)
    }
}
