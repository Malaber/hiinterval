import XCTest

@MainActor
final class PlanEditorUITests: HiIntervalUITestCase {
    func testCreatesCustomSplitPlanSavesSelectsAndPersists() {
        launch()
        selectTab("plans")
        tap(element("plans.add"))
        waitForExistence(element("plan.editor.screen"))

        replaceText(in: element("plan.editor.name"), with: "Bilateral Builder")
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
        waitForExistence(element("plan.editor.screen"))

        tap(element("plan.editor.roundOverrides"), scrolls: true)
        waitForExistence(element("roundOverrides.screen"))
        setSwitch("roundOverride.enabled.2", to: true)
        setSwitch("roundOverride.side.enabled.2", to: true)
        selectSegment(control: "roundOverride.side.mode.2", option: "Left + right")
        capture("02-round-two-split-override")
        tapToolbarButton("roundOverrides.save", label: "Done")
        waitForExistence(element("plan.editor.screen"))

        tapToolbarButton("plan.editor.save", label: "Save")
        waitForExistence(element("plans.screen"))
        scrollToHittable(app.staticTexts["Bilateral Builder"])
        scrollToHittable(app.staticTexts["Split Squat"])
        capture("03-saved-selected-plan")

        selectTab("train")
        waitForLabel("Bilateral Builder", on: element("train.selected-plan-name"))

        relaunchPreservingData()
        waitForLabel("Bilateral Builder", on: element("train.selected-plan-name"))
        capture("04-plan-persists-after-relaunch")
    }
}
