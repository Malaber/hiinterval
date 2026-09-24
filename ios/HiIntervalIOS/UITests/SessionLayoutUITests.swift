import XCTest

@MainActor
final class SessionLayoutUITests: HiIntervalUITestCase {
    func testPausedOverlayDoesNotMoveContentAndStandardWorkoutFitsScreen() {
        app = configuredApplication(resetFixture: .glanceableSession)
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        app.launchEnvironment["HIINTERVAL_UI_TEST_LAYOUT_NAMES"] = "1"
        launchConfiguredApplication()
        tap(element("train.start"))
        waitForExistence(element("session.screen"))
        let heading = element("session.exercise")
        let timer = element("session.remaining")
        let pause = element("session.pause")
        let before = [heading.frame, timer.frame, pause.frame]
        XCTAssertTrue(pause.isHittable)
        XCTAssertTrue(element("session.skip").isHittable)
        waitForValue("Fits screen", on: app.scrollViews["session.screen"])
        tap(pause)
        waitForExistence(element("session.paused"))
        let after = [heading.frame, timer.frame, pause.frame]
        for (original, paused) in zip(before, after) {
            XCTAssertEqual(original.minY, paused.minY, accuracy: 1)
            XCTAssertEqual(original.height, paused.height, accuracy: 1)
        }
        let viewport = app.scrollViews["session.screen"].frame
        // XCTest scroll frames include the status bar/home-indicator safe areas.
        XCTAssertLessThan(element("session.close").frame.minY - viewport.minY, viewport.height * 0.15)
        XCTAssertLessThan(viewport.maxY - pause.frame.maxY, viewport.height * 0.12)
        XCTAssertFalse(element("session.paused").frame.intersects(pause.frame))
        capture("session-readable-pause-splash")

        for expected in [
            "Long exercise heading\nwith a second line",
            "Recovery",
            "Reverse Lunges · Left",
        ] {
            tap(element("session.skip"))
            waitForLabel(expected, on: heading)
            XCTAssertEqual(timer.frame.minY, before[1].minY, accuracy: 1)
            XCTAssertEqual(pause.frame.minY, before[2].minY, accuracy: 1)
        }
        capture("session-stable-phase-slots")
        tap(pause)
        waitForDisappearance(element("session.paused"))
        XCTAssertEqual(heading.frame.minY, before[0].minY, accuracy: 1)
        capture("session-pause-overlay-stable")
    }
}
