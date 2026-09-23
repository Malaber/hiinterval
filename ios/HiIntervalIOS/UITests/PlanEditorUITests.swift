import XCTest

@MainActor
final class PlanEditorUITests: HiIntervalUITestCase {
    func testLogoSymbolCancelSaveRelaunchAndReset() {
        launch()
        selectTab("plans")

        openQuickStartEditor()
        chooseLogoSymbol("flame.fill")
        scrollToVisible(element("plan.editor.logo.reset"))
        XCTAssertTrue(element("plan.editor.logo.reset").isEnabled)
        tapToolbarButton("plan.editor.cancel", label: "Cancel")
        waitForDisappearance(element("plan.editor.screen"), timeout: 8)

        // Cancel never writes an edited symbol into plan JSON.
        openQuickStartEditor()
        scrollToVisible(element("plan.editor.logo.reset"))
        XCTAssertFalse(element("plan.editor.logo.reset").isEnabled)
        chooseLogoSymbol("flame.fill")
        tapToolbarButton("plan.editor.save", label: "Save")
        waitForDisappearance(element("plan.editor.screen"), timeout: 8)

        relaunchPreservingData()
        selectTab("plans")
        openQuickStartEditor()
        scrollToVisible(element("plan.editor.logo.reset"))
        XCTAssertTrue(element("plan.editor.logo.reset").isEnabled)

        tap(element("plan.editor.logo.reset"), scrolls: true)
        scrollToVisible(element("plan.editor.logo.reset"))
        XCTAssertFalse(element("plan.editor.logo.reset").isEnabled)
        tapToolbarButton("plan.editor.save", label: "Save")
        waitForDisappearance(element("plan.editor.screen"), timeout: 8)

        relaunchPreservingData()
        selectTab("plans")
        openQuickStartEditor()
        scrollToVisible(element("plan.editor.logo.reset"))
        XCTAssertFalse(element("plan.editor.logo.reset").isEnabled)
    }

    func testNaturalLanguageEditorStartsEmptyWithVisualPlaceholder() {
        launch()
        selectTab("plans")
        tap(element("plans.add-intelligently"))
        waitForExistence(element("plan.ai.screen"), timeout: 8)

        let prompt = element("plan.ai.prompt")
        waitForExistence(prompt)
        waitForExistence(element("plan.ai.placeholder"))
        XCTAssertEqual(prompt.value as? String, "")
        XCTAssertFalse(element("plan.ai.generate").isEnabled)
        capture("01-natural-language-placeholder")
    }

    func testAddingExerciseFocusesNameField() {
        launch()
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

        tap(element("plan.editor.exercise.add"), scrolls: true)
        tap(element("exercise.choice.create"))
        waitForExistence(element("exercise.editor.screen"))

        let name = element("exercise.editor.name")
        waitForExistence(name)
        waitForExistence(app.keyboards.firstMatch, timeout: 3)
        typeText("Burpees", intoFocusedField: name)
        XCTAssertEqual(name.value as? String, "Burpees")
        capture("01-new-exercise-name-focused")
    }

    func testCreatesCustomSplitPlanSavesSelectsAndPersists() {
        launch()
        selectTab("plans")
        tap(element("plans.add"))
        waitForExistence(element("plan.editor.screen"))

        replaceText(in: element("plan.editor.name"), with: "Bilateral Builder")
        replaceText(
            in: element("plan.editor.warmup.notes"),
            with: "Mobilize at 60%"
        )
        if app.keyboards.firstMatch.exists {
            app.keyboards.firstMatch.swipeDown()
        }
        tap(element("plan.editor.exercise.0"), scrolls: true)
        waitForExistence(element("exercise.editor.screen"))

        replaceText(in: element("exercise.editor.name"), with: "Split Squat")
        selectSegment(control: "exercise.editor.duration.mode", option: "Custom")
        incrementStepper("exercise.editor.duration.custom", times: 1)
        selectSegment(control: "exercise.editor.side.mode", option: "Left + right")
        incrementStepper("exercise.editor.side.switch", times: 2)
        replaceText(in: element("exercise.editor.notes"), with: "Switch stance under control")

        waitForExistence(element("exercise.editor.side.preview"))
        capture("01-custom-split-exercise")
        tapToolbarButton("exercise.editor.save", label: "Done")
        waitForDisappearance(element("exercise.editor.screen"), timeout: 8)
        waitForExistence(element("plan.editor.screen"))

        tap(element("plan.editor.roundOverrides"), scrolls: true)
        waitForExistence(element("roundOverrides.screen"))
        setSwitch("roundOverride.enabled.2", to: true)
        setSwitch("roundOverride.side.enabled.2", to: true)
        selectSegment(control: "roundOverride.side.mode.2", option: "Left + right")
        capture("02-round-two-split-override")
        tapToolbarButton("roundOverrides.save", label: "Done")
        waitForDisappearance(element("roundOverrides.screen"), timeout: 8)
        waitForExistence(element("plan.editor.screen"))

        tapToolbarButton("plan.editor.save", label: "Save")
        waitForDisappearance(element("plan.editor.screen"), timeout: 8)
        waitForExistence(element("plans.screen"))

        selectTab("train")
        waitForLabel("Bilateral Builder", on: element("train.selected-plan-name"))
        capture("03-saved-selected-plan")

        relaunchPreservingData()
        waitForLabel("Bilateral Builder", on: element("train.selected-plan-name"))
        capture("04-plan-persists-after-relaunch")
    }

    private func openQuickStartEditor() {
        tap(
            planActionButton(
                planID: FixtureID.quickStartPlan,
                identifier: "plan.edit.\(FixtureID.quickStartPlan)",
                fallbackLabel: "Edit"
            ),
            scrolls: true
        )
        waitForExistence(element("plan.editor.screen"))
    }

    private func chooseLogoSymbol(_ symbol: String) {
        tap(element("plan.editor.logo.symbol"), scrolls: true)
        tap(element("plan.editor.logo.symbol.option.\(symbol)"))
        waitForExistence(element("plan.editor.logo"))
    }
}
