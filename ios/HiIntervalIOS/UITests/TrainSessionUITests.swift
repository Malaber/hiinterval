import XCTest

@MainActor
final class TrainSessionUITests: HiIntervalUITestCase {
    func testDisabledHapticsApplyToEntireSession() {
        launchAtRealtimeSpeed(fixture: .glanceableSession)
        selectTab("settings")
        setSwitch("settings.haptics", to: false)
        selectTab("train")

        tap(element("train.start"))
        waitForExistence(element("session.screen"), timeout: 5)
        waitForValue("Haptics disabled", on: element("session.phase-kind"))
    }

    func testFreshFixtureStartsSelectedWorkout() {
        app = configuredApplication(resetFixture: .standard)
        app.launchEnvironment["HIINTERVAL_UI_TEST_MANUAL_CELEBRATION"] = "1"
        launchConfiguredApplication()

        waitForLabel("Quick Start", on: element("train.selected-plan-name"))
        XCTAssertTrue(element("train.free-status").exists)
        capture("01-fresh-train")

        tap(element("train.start"))
        // Required 60x clock finishes the 36-second fixture in about 0.6 real seconds.
        // Completion proves the selected plan started without racing transient phase UI.
        waitForExistence(element("completion.screen"), timeout: 15)
        waitForExistence(element("completion.extra-nudge"))
        XCTAssertTrue(element("completion.one-more-round").exists)
        let celebration = element("completion.screen")
        waitForValue("Foreground fireworks", on: celebration, timeout: 5)
        // Hosted iPad accessibility polling can delay its main actor beyond production's five-second
        // foreground interval. This test-only clock crosses same core timeline boundary on demand.
        tap(element("completion.advance-fireworks"))
        waitForValue("Background fireworks", on: celebration, timeout: 10)
        capture("02-fixture-started-and-complete")
    }

    func testOneMoreRoundCompletesAndCongratulatesExtraEffort() {
        app = configuredApplication(resetFixture: .glanceableSession)
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        app.launchEnvironment["HIINTERVAL_UI_TEST_CELEBRATION_DURATION"] = "0"
        launchConfiguredApplication()
        tap(element("train.start"))
        waitForExistence(element("session.screen"), timeout: 20)
        tap(element("session.pause"), scrolls: true)
        waitForLabel("Resume workout", on: element("session.pause"))
        finishBySkippingPausedPhases()
        waitForExistence(element("completion.screen"), timeout: 20)
        // Automatic task path still runs; zero-duration test configuration makes boundary exact.
        waitForValue("Background fireworks", on: element("completion.screen"), timeout: 20)

        tap(element("completion.one-more-round"), scrolls: true)
        waitForExistence(element("session.screen"), timeout: 20)
        tap(element("session.pause"), scrolls: true)
        waitForLabel("Resume workout", on: element("session.pause"))
        finishBySkippingPausedPhases()
        waitForExistence(element("completion.extra-congratulation"), timeout: 20)
        waitForLabel(
            "You did more than planned. Extra round complete!",
            on: element("completion.extra-congratulation")
        )
        capture("01-extra-round-complete")
    }

    func testPauseResumeSplitTransitionsSkipCompletionAndHistory() {
        launch()
        stretchQuickStartForDeterministicClockControl()
        relaunchAtRealtimeSpeedPreservingData()

        selectTab("train")
        waitForLabel("Quick Start", on: element("train.selected-plan-name"))
        tap(element("train.start"))
        waitForExistence(element("session.screen"), timeout: 5)
        tap(element("session.pause"))
        waitForLabel("Resume workout", on: element("session.pause"))

        let remaining = element("session.remaining")
        let pausedLabel = remaining.label
        assertLabelRemainsStable(on: remaining)
        capture("01-session-paused")

        tap(element("session.pause"))
        waitForLabel("Pause workout", on: element("session.pause"))
        waitForLabelToChange(from: pausedLabel, on: remaining)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        let homeIcon = XCUIApplication(bundleIdentifier: "com.apple.springboard").icons["HiInterval"]
        let foreground = NSPredicate { [app] _, _ in
            app!.state == .runningForeground && app!.windows.firstMatch.isHittable
                && (!homeIcon.exists || !homeIcon.isHittable)
        }
        if !foreground.evaluate(with: app) {
            let ready = XCTNSPredicateExpectation(predicate: foreground, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed,
                           "Workout must be visibly foreground before tapping its controls")
        }
        waitForLabel("Resume workout", on: element("session.pause"))

        tap(element("session.mute"))
        waitForLabel("Unmute cues", on: element("session.mute"))
        tap(element("session.restart"))
        assertLabelRemainsStable(on: remaining)
        tap(element("session.mute"))
        waitForLabel("Mute cues", on: element("session.mute"))

        seekPausedPhase(exercise: "Reverse Lunges · Left", phase: "WORK")
        capture("02-left-side")

        skipPausedPhase(expectingExercise: "Switch sides · Right")
        waitForLabel("SWITCH", on: element("session.phase-kind"))

        skipPausedPhase(expectingExercise: "Reverse Lunges · Right")
        waitForLabel("WORK", on: element("session.phase-kind"))
        capture("03-right-side")

        skipPausedPhase(expectingExercise: "Round recovery")
        waitForLabel("ROUND RECOVERY", on: element("session.phase-kind"))
        waitForDisappearance(element("session.side"))

        finishBySkippingPausedPhases()
        waitForExistence(element("completion.screen"), timeout: 5)
        capture("04-session-complete")
        tap(element("completion.done"))
        waitForExistence(element("train.screen"))

        selectTab("history")
        waitForExistence(app.staticTexts["Quick Start"], timeout: 5)
        XCTAssertTrue(element("history.entry.\(FixtureID.coreFocusHistory)").exists)
        capture("05-completion-in-history")
    }

    func testExerciseProgressNextUpAndRestartNavigation() {
        launchAtRealtimeSpeed(fixture: .glanceableSession)
        tap(element("train.start"))
        waitForExistence(element("session.screen"), timeout: 5)

        waitForLabel("Get ready", on: element("session.exercise"))
        waitForLabel("Notes, Move at 60% effort", on: element("session.notes"))
        tap(element("session.pause"))
        waitForLabel("Resume workout", on: element("session.pause"))
        skipPausedPhase(expectingExercise: "High Knees")
        waitForLabel("High Knees", on: element("session.exercise"))
        waitForLabel("Notes, Keep knees soft", on: element("session.notes"))
        waitForLabel("WORK", on: element("session.phase-kind"))
        waitForLabel("Exercise 1 of 8", on: element("session.exercise-progress"))
        waitForLabel("Next up, Reverse Lunges · Left", on: element("session.next"))
        waitForValue("Primary focus", on: element("session.exercise"))
        waitForValue("Secondary preview", on: element("session.next"))
        XCTAssertFalse(app.staticTexts["WORK"].exists)
        XCTAssertFalse(app.staticTexts["RECOVER"].exists)
        capture("01-running-eight-exercise-work")

        waitForLabel("Resume workout", on: element("session.pause"))

        // Let time elapse, then prove one restart press restores this phase's full duration.
        let remaining = element("session.remaining")
        let fullDuration = remaining.label
        tap(element("session.pause"))
        waitForLabelToChange(from: fullDuration, on: remaining)
        tap(element("session.pause"))
        waitForLabel("Resume workout", on: element("session.pause"))
        XCTAssertLessThan(remainingSeconds(from: remaining), 600)
        tap(element("session.restart"))
        waitForRemainingSeconds(600, on: remaining)
        capture("02-single-reset-restored-time")

        // Recovery has its own heading; next-up points to the next work phase.
        skipPausedPhase(expectingExercise: "Recovery")
        waitForLabel("Notes, Breathe and reset", on: element("session.notes"))
        waitForLabel("Exercise 1 of 8", on: element("session.exercise-progress"))
        waitForLabel("Next up, Reverse Lunges · Left", on: element("session.next"))
        tap(element("session.pause"))
        waitForLabel("Pause workout", on: element("session.pause"))
        capture("03-running-recovery-background")
        tap(element("session.pause"))
        waitForLabel("Resume workout", on: element("session.pause"))

        // Two quick presses repair the accidental skip and restore the previous exercise.
        element("session.restart").doubleTap()
        waitForLabel("High Knees", on: element("session.exercise"))
        waitForLabel("WORK", on: element("session.phase-kind"))
        waitForRemainingSeconds(600, on: remaining)
        waitForLabel("Exercise 1 of 8", on: element("session.exercise-progress"))
        capture("04-double-back-restored-exercise")

        // The first exercise can return to warm-up, not just earlier work phases.
        element("session.restart").doubleTap()
        waitForLabel("Get ready", on: element("session.exercise"))
        waitForLabel("WARM UP", on: element("session.phase-kind"))
        waitForRemainingSeconds(600, on: remaining)
        waitForValue("Restart available", on: element("session.restart"))
        skipPausedPhase(expectingExercise: "High Knees")

        skipPausedPhase(expectingExercise: "Recovery")
        skipPausedPhase(expectingExercise: "Reverse Lunges · Left")
        waitForLabel("Exercise 2 of 8", on: element("session.exercise-progress"))
        waitForLabel("Next up, Reverse Lunges · Right", on: element("session.next"))
        capture("05-second-exercise-selected")

        seekPausedPhase(exercise: "Cool down", phase: "COOL DOWN", attempts: 24)
        waitForLabel("Notes, Slow nasal breathing", on: element("session.notes"))
        waitForDisappearance(element("session.next"))
        tap(element("session.pause"))
        waitForLabel("Pause workout", on: element("session.pause"))
        capture("06-running-cool-down-background")
    }

    private func launchAtRealtimeSpeed(fixture: Fixture = .standard) {
        app = configuredApplication(resetFixture: fixture)
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        launchConfiguredApplication()
    }

    private func relaunchAtRealtimeSpeedPreservingData() {
        app.terminate()
        app = configuredApplication(resetFixture: nil)
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        launchConfiguredApplication()
    }

    private func stretchQuickStartForDeterministicClockControl() {
        selectTab("plans")
        tap(
            planActionButton(
                planID: FixtureID.quickStartPlan,
                identifier: "plan.edit.\(FixtureID.quickStartPlan)",
                fallbackLabel: "Edit"
            ),
            scrolls: true
        )
        waitForExistence(element("plan.editor.screen"))

        // 5s -> 105s, then relaunch at real time before starting this state-heavy session.
        incrementStepper("plan.editor.work", times: 20)
        // Ten rounds keep session alive while UI assertions and screenshots are collected.
        incrementStepper("plan.editor.rounds", times: 8)
        tapToolbarButton("plan.editor.save", label: "Save")
        waitForExistence(element("plans.screen"))
    }

    private func seekPausedPhase(exercise: String, phase: String, attempts: Int = 12) {
        let exerciseElement = element("session.exercise")
        let phaseElement = element("session.phase-kind")

        for _ in 0..<attempts {
            if exerciseElement.label == exercise, phaseElement.label == phase {
                return
            }
            let previous = exerciseElement.label
            tap(element("session.skip"))
            waitForLabelToChange(from: previous, on: exerciseElement)
        }
        XCTFail(
            "Could not reach paused phase \(phase) / \(exercise). "
                + "Current: \(phaseElement.label) / \(exerciseElement.label)"
        )
    }

    private func skipPausedPhase(expectingExercise expected: String) {
        tap(element("session.skip"))
        waitForLabel(expected, on: element("session.exercise"))
    }

    private func finishBySkippingPausedPhases() {
        for _ in 0..<80 {
            if element("completion.screen").exists { return }
            let skip = element("session.skip")
            guard skip.exists else { break }
            skip.tap()
        }
    }

    private func remainingSeconds(from element: XCUIElement) -> Int {
        Int(element.label.split(separator: " ").first ?? "") ?? -1
    }

    private func waitForRemainingSeconds(
        _ seconds: Int,
        on element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", "\(seconds) seconds remaining")
        // A synchronous snapshot may outlast the waiter on hosted iPad simulators.
        // Check the current state first and only fetch diagnostic text on actual failure.
        if predicate.evaluate(with: element) { return }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        if XCTWaiter.wait(for: [expectation], timeout: timeout) != .completed {
            XCTFail("Expected \(seconds) seconds remaining, got '\(element.label)'", file: file, line: line)
        }
    }
}
