import XCTest

@MainActor
final class WorkoutShuffleUITests: HiIntervalUITestCase {
    func testShufflePreservesSettingsAndOptionsAndCanBeCancelled() {
        launch()
        selectTab("plans")
        tap(planActionButton(planID: FixtureID.quickStartPlan,
            identifier: "plan.edit.\(FixtureID.quickStartPlan)", fallbackLabel: "Edit"), scrolls: true)
        waitForValue("Quick Start", on: element("plan.editor.name"))
        tap(element("plan.editor.exercise.shuffle"), scrolls: true)
        waitForExistence(element("generator.screen"))
        setSwitch("generator.alternate", to: false)
        tapToolbarButton("generator.generate", label: "Preview")
        waitForExistence(element("shuffle.preview.screen"))
        // Both unused fixture exercises must be selected; order is intentionally random.
        let names = [element("shuffle.preview.exercise.0").label, element("shuffle.preview.exercise.1").label].joined()
        XCTAssertTrue(names.contains("Dead Bug"))
        XCTAssertTrue(names.contains("Side Plank"))
        tapToolbarButton("shuffle.preview.apply", label: "Replace exercises")
        waitForDisappearance(element("generator.screen"))
        tapToolbarButton("plan.editor.save", label: "Save")
        relaunchPreservingData()
        selectTab("plans")
        tap(planActionButton(planID: FixtureID.quickStartPlan,
            identifier: "plan.edit.\(FixtureID.quickStartPlan)", fallbackLabel: "Edit"), scrolls: true)
        waitForValue("Quick Start", on: element("plan.editor.name"))
        scrollToVisible(element("plan.editor.work.value"))
        waitForValue("5 seconds", on: element("plan.editor.work.value"))
        tap(element("plan.editor.exercise.shuffle"), scrolls: true)
        waitForValue("0", on: app.switches["generator.alternate"])
        tapToolbarButton("generator.generate", label: "Preview")
        tapToolbarButton("shuffle.preview.cancel", label: "Back")
        tapToolbarButton("generator.cancel", label: "Cancel")
        scrollToVisible(element("plan.editor.exercise.0"))
        let retained = element("plan.editor.exercise.0").label
        XCTAssertTrue(retained.contains("Dead Bug") || retained.contains("Side Plank"))
    }
}
