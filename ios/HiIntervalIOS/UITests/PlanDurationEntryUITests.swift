import XCTest

@MainActor
final class PlanDurationEntryUITests: HiIntervalUITestCase {
    func testDirectDurationEntryRejectsOutOfRangeInputCancelsAndPersistsExactSeconds() {
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

        let workValue = element("plan.editor.work.value")
        tap(workValue, scrolls: true)
        waitForExistence(element("plan.editor.work.entry.screen"))
        let secondsField = element("plan.editor.work.entry.seconds")
        waitForExistence(secondsField)
        waitForExistence(app.keyboards.firstMatch, timeout: 3)

        replaceText(in: secondsField, with: "0")
        XCTAssertFalse(app.buttons["plan.editor.work.entry.done"].isEnabled)
        tapToolbarButton("plan.editor.work.entry.cancel", label: "Cancel")
        waitForDisappearance(element("plan.editor.work.entry.screen"))
        waitForValue("5 seconds", on: workValue)

        tap(workValue, scrolls: true)
        waitForExistence(secondsField)
        replaceText(in: secondsField, with: "17")
        tapToolbarButton("plan.editor.work.entry.done", label: "Done")
        waitForDisappearance(element("plan.editor.work.entry.screen"))
        waitForValue("17 seconds", on: workValue)

        tapToolbarButton("plan.editor.save", label: "Save")
        waitForDisappearance(element("plan.editor.screen"), timeout: 8)
        relaunchPreservingData()
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
        waitForValue("17 seconds", on: element("plan.editor.work.value"))
    }
}
