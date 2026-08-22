import XCTest

@MainActor
final class LibraryManagementUITests: HiIntervalUITestCase {
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
