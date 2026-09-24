import XCTest

@MainActor
final class LibraryManagementUITests: HiIntervalUITestCase {
    func testPlanCardDurationRefreshesAfterTimingEdit() {
        launch()
        selectTab("plans")

        let card = element("plan.card.\(FixtureID.quickStartPlan)")
        let duration = card.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Duration, '"))
            .firstMatch
        waitForExistence(duration)
        let originalDuration = duration.label

        tap(
            planActionButton(
                planID: FixtureID.quickStartPlan,
                identifier: "plan.edit.\(FixtureID.quickStartPlan)",
                fallbackLabel: "Edit"
            ),
            scrolls: true
        )
        waitForExistence(element("plan.editor.screen"))
        tap(element("plan.editor.warmup.value"), scrolls: true)
        waitForExistence(element("plan.editor.warmup.entry.screen"))
        replaceText(in: element("plan.editor.warmup.entry.seconds"), with: "13")
        tapToolbarButton("plan.editor.warmup.entry.done", label: "Done")
        waitForDisappearance(element("plan.editor.warmup.entry.screen"))
        tapToolbarButton("plan.editor.save", label: "Save")
        waitForDisappearance(element("plan.editor.screen"), timeout: 8)

        waitForLabelToChange(from: originalDuration, on: duration, timeout: 5)
        let editedDuration = duration.label

        relaunchPreservingData()
        selectTab("plans")
        let restoredDuration = element("plan.card.\(FixtureID.quickStartPlan)")
            .descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Duration, '"))
            .firstMatch
        waitForLabel(editedDuration, on: restoredDuration)
    }

    func testSelectsDuplicatesAndDeletesPlanThenPersistsResult() {
        launch()
        selectTab("plans")

        tap(
            planActionButton(
                planID: FixtureID.coreFocusPlan,
                identifier: "plan.select.\(FixtureID.coreFocusPlan)",
                fallbackLabel: "Use this plan"
            ),
            scrolls: true
        )
        selectTab("train")
        waitForLabel("Core Focus", on: element("train.selected-plan-name"))

        selectTab("plans")
        tap(
            planActionButton(
                planID: FixtureID.coreFocusPlan,
                identifier: "plan.menu.\(FixtureID.coreFocusPlan)",
                fallbackLabel: "Options for Core Focus"
            ),
            scrolls: true
        )
        tapVisibleButton("Duplicate")
        scrollToHittable(app.staticTexts["Core Focus Copy"])

        selectTab("train")
        waitForLabel("Core Focus Copy", on: element("train.selected-plan-name"))

        selectTab("plans")
        tap(
            planActionButton(
                planID: FixtureID.coreFocusPlan,
                identifier: "plan.menu.\(FixtureID.coreFocusPlan)",
                fallbackLabel: "Options for Core Focus"
            ),
            scrolls: true
        )
        tapVisibleButton("Delete")
        tapVisibleButton("Delete plan")
        waitForDisappearance(app.staticTexts["Core Focus"])

        relaunchPreservingData()
        waitForLabel("Core Focus Copy", on: element("train.selected-plan-name"))
        selectTab("plans")
        scrollToHittable(app.staticTexts["Core Focus Copy"])
        XCTAssertFalse(app.staticTexts["Core Focus"].exists)
        capture("plan-copy-selected-original-deleted")
    }

    func testHistoryDetailReusesRenamesAndDeletesSession() {
        launch()
        selectTab("history")
        tap(element("history.entry.\(FixtureID.coreFocusHistory)"))
        waitForExistence(element("history.detail.screen"))

        tap(element("history.reuse"))
        waitForLabel("Plan copied and selected", on: element("history.reuse.status"))

        tap(element("history.rename"), scrolls: true)
        replaceText(in: app.alerts.textFields.firstMatch, with: "Recovery Session")
        tapVisibleButton("Save")
        waitForLabel("Recovery Session", on: element("history.detail.title"))

        tap(element("history.delete"), scrolls: true)
        tapVisibleButton("Delete session")
        waitForExistence(app.staticTexts["No sessions yet"])

        selectTab("train")
        waitForLabel("Core Focus Copy", on: element("train.selected-plan-name"))
        capture("history-reused-renamed-deleted")
    }

    func testClearHistoryKeepsWorkoutPlans() {
        launch()
        selectTab("history")
        tapToolbarButton("history.clear", label: "Clear history")
        tapVisibleButton("Clear history")
        waitForExistence(app.staticTexts["No sessions yet"])

        selectTab("plans")
        waitForExistence(element("plan.card.\(FixtureID.quickStartPlan)"))
        scrollToHittable(
            planActionButton(
                planID: FixtureID.coreFocusPlan,
                identifier: "plan.select.\(FixtureID.coreFocusPlan)",
                fallbackLabel: "Use this plan"
            )
        )
        capture("history-cleared-plans-preserved")
    }
}
