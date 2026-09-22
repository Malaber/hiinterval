import XCTest

@MainActor
final class AccessibilityUITests: HiIntervalUITestCase {
    func testPrimarySurfacesExposeAccessibleControls() {
        launch()

        assertAccessibleControl("train.start")
        assertAccessibleControl("generator.open", checksFrame: false)
        capture("accessibility-light-train")

        selectTab("plans")
        assertAccessibleControl("plan.menu.\(FixtureID.quickStartPlan)")
        assertAccessibleControl("plan.select.\(FixtureID.quickStartPlan)", scrolls: true)
        capture("accessibility-light-plans")

        selectTab("history")
        assertAccessibleControl("history.entry.\(FixtureID.coreFocusHistory)", scrolls: true)
        assertAccessibleControl(
            app.buttons["Export history"],
            named: "history.export",
            checksFrame: false
        )
        capture("accessibility-light-history")

        selectTab("settings")
        assertAccessibleControl("settings.cues", scrolls: true)
        assertAccessibleControl("settings.haptics", scrolls: true)
        selectSegment(control: "settings.appearance", option: "Dark")
        capture("accessibility-dark-settings")

        selectTab("train")
        assertAccessibleControl("train.start", scrolls: true)
        capture("accessibility-dark-train")
        selectTab("plans")
        assertAccessibleControl("plan.menu.\(FixtureID.quickStartPlan)", scrolls: true)
        capture("accessibility-dark-plans")
        selectTab("history")
        assertAccessibleControl("history.entry.\(FixtureID.coreFocusHistory)", scrolls: true)
        capture("accessibility-dark-history")
    }

    func testActiveWorkoutExposesAccessibleControls() {
        app = configuredApplication(resetFixture: .glanceableSession)
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        launchConfiguredApplication()

        tap(element("train.start"), scrolls: true)
        waitForExistence(element("session.screen"), timeout: 20)
        tap(element("session.pause"), scrolls: true)
        waitForLabel("Resume workout", on: element("session.pause"))

        waitForLabel("Get ready", on: element("session.exercise"), timeout: 20)
        assertSessionAccessibility(phase: "WARM UP", exercise: "Get ready")
        capture("accessibility-session-warmup")

        tap(element("session.skip"), scrolls: true)
        waitForLabel("High Knees", on: element("session.exercise"))
        assertSessionAccessibility(phase: "WORK", exercise: "High Knees")
        capture("accessibility-session-work")

        tap(element("session.skip"), scrolls: true)
        waitForLabel("Recover", on: element("session.exercise"))
        assertSessionAccessibility(phase: "RECOVER", exercise: "Recover")
        capture("accessibility-session-recovery")
    }

    func testPrimarySurfacesRemainUsableAtLargestAccessibilityTextSize() {
        app = configuredApplication(resetFixture: .standard)
        app.launchEnvironment["HIINTERVAL_UI_TEST_DYNAMIC_TYPE"] = "accessibility5"
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        launchConfiguredApplication()
        scrollToHittable(element("train.start"))
        capture("dynamic-type-train")

        selectTab("plans")
        scrollToVisible(app.staticTexts["Quick Start"])
        waitForExistence(element("plans.add"))
        capture("dynamic-type-plans")

        selectTab("history")
        scrollToHittable(element("history.entry.\(FixtureID.coreFocusHistory)"))
        capture("dynamic-type-history")

        selectTab("settings")
        scrollToHittable(element("settings.keep-awake"))
        capture("dynamic-type-settings")

        // Accessibility snapshots at the largest size can outlast the entire short fixture.
        // Primary screens above retain their standard plans/history; use the existing long
        // session fixture for the workout layout so its pause controls stay available.
        app = configuredApplication(resetFixture: .glanceableSession)
        app.launchEnvironment["HIINTERVAL_UI_TEST_DYNAMIC_TYPE"] = "accessibility5"
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        launchConfiguredApplication()
        scrollToHittable(element("train.start"))
        tap(element("train.start"))
        waitForExistence(element("session.screen"), timeout: 5)
        tap(element("session.pause"), scrolls: true)
        waitForLabel("Resume workout", on: element("session.pause"))
        scrollToVisible(element("session.next"))
        capture("dynamic-type-session")
    }

    private func assertSessionAccessibility(phase: String, exercise: String) {
        let phaseElement = element("session.phase-kind")
        waitForLabel(phase, on: phaseElement)
        XCTAssertNotNil(phaseElement.value as? String, "Phase must expose haptic state")

        let exerciseElement = element("session.exercise")
        waitForLabel(exercise, on: exerciseElement)
        XCTAssertEqual(exerciseElement.value as? String, "Primary focus")

        assertLabeledElement("session.remaining")
        assertLabeledElement("session.total-remaining")
        for identifier in [
            "session.close",
            "session.mute",
            "session.restart",
            "session.pause",
            "session.skip",
        ] {
            assertAccessibleControl(identifier)
        }
    }

    private func assertLabeledElement(
        _ identifier: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element(identifier)
        waitForExistence(target, file: file, line: line)
        XCTAssertFalse(
            target.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "Element '\(identifier)' must expose an accessibility label",
            file: file,
            line: line
        )
    }

    private func assertAccessibleControl(
        _ identifier: String,
        scrolls: Bool = false,
        checksFrame: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertAccessibleControl(
            element(identifier),
            named: identifier,
            scrolls: scrolls,
            checksFrame: checksFrame,
            file: file,
            line: line
        )
    }

    private func assertAccessibleControl(
        _ control: XCUIElement,
        named identifier: String,
        scrolls: Bool = false,
        checksFrame: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if scrolls {
            scrollToHittable(control, file: file, line: line)
        } else {
            waitForExistence(control, file: file, line: line)
        }
        XCTAssertTrue(control.isHittable, "Control '\(identifier)' must be hittable", file: file, line: line)
        XCTAssertTrue(control.isEnabled, "Control '\(identifier)' must be enabled", file: file, line: line)
        XCTAssertFalse(
            control.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "Control '\(identifier)' must expose an accessibility label",
            file: file,
            line: line
        )
        if checksFrame {
            XCTAssertGreaterThanOrEqual(
                control.frame.width,
                44,
                "Control '\(identifier)' must provide a 44-point-wide hit target",
                file: file,
                line: line
            )
            XCTAssertGreaterThanOrEqual(
                control.frame.height,
                44,
                "Control '\(identifier)' must provide a 44-point-high hit target",
                file: file,
                line: line
            )
        }
    }
}
