import XCTest

@MainActor
final class TrainSessionUITests: HiIntervalUITestCase {
    func testFreshFixtureStartsSelectedWorkout() {
        launch()

        waitForLabel("Quick Start", on: element("train.selected-plan-name"))
        XCTAssertTrue(element("train.free-status").exists)
        capture("01-fresh-train")

        tap(element("train.start"))
        // Required 60x clock finishes the 36-second fixture in about 0.6 real seconds.
        // Completion proves the selected plan started without racing transient phase UI.
        waitForExistence(element("completion.screen"), timeout: 5)
        capture("02-fixture-started-and-complete")
    }

    func testPauseResumeSplitTransitionsSkipCompletionAndHistory() {
        launch()
        stretchQuickStartForDeterministicClockControl()

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
        waitForLabel("Resume workout", on: element("session.pause"))

        tap(element("session.mute"))
        waitForLabel("Unmute cues", on: element("session.mute"))
        tap(element("session.restart"))
        assertLabelRemainsStable(on: remaining)
        tap(element("session.mute"))
        waitForLabel("Mute cues", on: element("session.mute"))

        seekPausedPhase(exercise: "Reverse Lunges", phase: "WORK", side: "LEFT SIDE")
        capture("02-left-side")

        skipPausedPhase(expectingExercise: "Switch sides")
        waitForLabel("SWITCH", on: element("session.phase-kind"))
        waitForLabel("RIGHT SIDE", on: element("session.side"))

        skipPausedPhase(expectingExercise: "Reverse Lunges")
        waitForLabel("WORK", on: element("session.phase-kind"))
        waitForLabel("RIGHT SIDE", on: element("session.side"))
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

        waitForLabel("High Knees", on: element("session.exercise"))
        waitForLabel("WORK", on: element("session.phase-kind"))
        waitForLabel("Exercise 1 of 8", on: element("session.exercise-progress"))
        waitForLabel("Next up, Reverse Lunges · Left", on: element("session.next"))
        capture("01-running-eight-exercise-work")

        tap(element("session.pause"))
        waitForLabel("Resume workout", on: element("session.pause"))

        // Let time elapse, then prove one restart press restores this phase's full duration.
        let remaining = element("session.remaining")
        let fullDuration = remaining.label
        tap(element("session.pause"))
        waitForLabelToChange(from: fullDuration, on: remaining)
        tap(element("session.pause"))
        waitForLabel("Resume workout", on: element("session.pause"))
        XCTAssertLessThan(remainingSeconds(from: remaining), 105)
        tap(element("session.restart"))
        waitForRemainingSeconds(105, on: remaining)
        capture("02-single-reset-restored-time")

        // Recovery stays visually current for exercise one; next-up skips it entirely.
        skipPausedPhase(expectingExercise: "Recover")
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
        waitForRemainingSeconds(105, on: remaining)
        waitForLabel("Exercise 1 of 8", on: element("session.exercise-progress"))
        capture("04-double-back-restored-exercise")

        skipPausedPhase(expectingExercise: "Recover")
        skipPausedPhase(expectingExercise: "Reverse Lunges")
        waitForLabel("Exercise 2 of 8", on: element("session.exercise-progress"))
        waitForLabel("Next up, Reverse Lunges · Right", on: element("session.next"))
        capture("05-second-exercise-selected")

        seekPausedPhase(exercise: "Cool down", phase: "COOL DOWN", attempts: 24)
        waitForDisappearance(element("session.next"))
        tap(element("session.pause"))
        waitForLabel("Pause workout", on: element("session.pause"))
        capture("06-running-cool-down-background")
    }

    private func launchAtRealtimeSpeed(fixture: Fixture = .standard) {
        app = configuredApplication(resetFixture: fixture)
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        app.launch()
        waitForExistence(element("train.screen"), timeout: 8)
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

        // 5s -> 105s. At required 60x speed, each High Knees phase remains visible for 1.75s.
        incrementStepper("plan.editor.work", times: 20)
        // Ten rounds keep session alive while UI assertions and screenshots are collected.
        incrementStepper("plan.editor.rounds", times: 8)
        tapToolbarButton("plan.editor.save", label: "Save")
        waitForExistence(element("plans.screen"))
    }

    private func seekPausedPhase(exercise: String, phase: String, side: String) {
        let exerciseElement = element("session.exercise")
        let phaseElement = element("session.phase-kind")
        let sideElement = element("session.side")

        for _ in 0..<12 {
            if exerciseElement.label == exercise,
               phaseElement.label == phase,
               sideElement.exists,
               sideElement.label == side {
                return
            }
            let previous = exerciseElement.label
            tap(element("session.skip"))
            waitForLabelToChange(from: previous, on: exerciseElement)
        }
        XCTFail(
            "Could not reach paused phase \(phase) / \(exercise) / \(side). "
                + "Current: \(phaseElement.label) / \(exerciseElement.label) / \(sideElement.label)"
        )
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
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@", "\(seconds) seconds remaining"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(seconds) seconds remaining, got '\(element.label)'",
            file: file,
            line: line
        )
    }
}
