import XCTest
@testable import HiIntervalCore

final class HapticCuePolicyTests: XCTestCase {
    func testDisabledHapticsSuppressEveryCueEvent() {
        for event in HapticCueEvent.allCases {
            XCTAssertNil(HapticCuePolicy.feedback(for: event, hapticsEnabled: false))
        }
    }

    func testEnabledHapticsMapEveryCueToFeedback() {
        XCTAssertEqual(
            HapticCuePolicy.feedback(for: .phase, hapticsEnabled: true),
            .mediumImpact
        )
        XCTAssertEqual(
            HapticCuePolicy.feedback(for: .countdown, hapticsEnabled: true),
            .lightImpact
        )
        XCTAssertEqual(
            HapticCuePolicy.feedback(for: .pause, hapticsEnabled: true),
            .softImpact
        )
        XCTAssertEqual(
            HapticCuePolicy.feedback(for: .resume, hapticsEnabled: true),
            .softImpact
        )
        XCTAssertEqual(
            HapticCuePolicy.feedback(for: .completion, hapticsEnabled: true),
            .success
        )
    }
}
