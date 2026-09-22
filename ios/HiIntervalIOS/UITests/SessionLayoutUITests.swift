import XCTest

@MainActor
final class SessionLayoutUITests: HiIntervalUITestCase {
    func testPausedOverlayDoesNotMoveContentAndStandardWorkoutFitsScreen() {
        app = configuredApplication(resetFixture: .glanceableSession)
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        launchConfiguredApplication()
        tap(element("train.start"))
        waitForExistence(element("session.screen"))
        let heading = element("session.exercise")
        let timer = element("session.remaining")
        let pause = element("session.pause")
        let before = [heading.frame, timer.frame, pause.frame]
        XCTAssertTrue(pause.isHittable)
        XCTAssertTrue(element("session.skip").isHittable)
        waitForValue("Fits screen", on: element("session.content"))
        tap(pause)
        waitForExistence(element("session.paused"))
        let after = [heading.frame, timer.frame, pause.frame]
        for (original, paused) in zip(before, after) {
            XCTAssertEqual(original.minY, paused.minY, accuracy: 1)
            XCTAssertEqual(original.height, paused.height, accuracy: 1)
        }
        tap(pause)
        waitForDisappearance(element("session.paused"))
        XCTAssertEqual(heading.frame.minY, before[0].minY, accuracy: 1)
        capture("session-pause-overlay-stable")
    }
}
