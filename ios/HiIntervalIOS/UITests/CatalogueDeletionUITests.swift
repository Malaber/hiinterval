import XCTest

@MainActor
final class CatalogueDeletionUITests: HiIntervalUITestCase {
    private enum CatalogueID {
        static let deadBug = "00000000-0000-0000-0000-000000000015"
    }

    func testCancellingCatalogueDeletionKeepsExerciseAvailable() {
        launch()
        openCatalogue()

        tap(element("catalogue.row.\(CatalogueID.deadBug)"), scrolls: true)
        waitForExistence(element("catalogue.editor.screen"))
        tapToolbarButton("catalogue.editor.delete", label: "Delete exercise")
        waitForExistence(element("catalogue.delete.warning"))
        tapVisibleButton("Cancel")

        waitForExistence(element("catalogue.row.\(CatalogueID.deadBug)"))
    }

    func testCancellingSwipeDeletionKeepsExerciseAcrossReload() {
        launch()
        openCatalogue()

        requestSwipeDeletion(of: CatalogueID.deadBug)
        waitForExistence(element("catalogue.delete.warning"))
        tapToolbarButton("catalogue.delete.cancel", label: "Cancel")
        waitForExistence(element("catalogue.row.\(CatalogueID.deadBug)"))

        relaunchPreservingData()
        openCatalogue()
        waitForExistence(element("catalogue.row.\(CatalogueID.deadBug)"))
    }

    func testDeletingUsedCatalogueExerciseRetainsPlansAndHistoryAcrossReload() {
        launch()
        openCatalogue()

        requestSwipeDeletion(of: CatalogueID.deadBug)
        waitForLabel("Used in Core Focus. Its steps keep their timing, sides, notes, and name. Completed workout history stays unchanged.", on: element("catalogue.delete.warning"))
        tap(element("catalogue.delete.confirm"))
        waitForDisappearance(element("catalogue.row.\(CatalogueID.deadBug)"))

        closeCatalogue()
        selectTab("plans")
        let coreFocus = element("plan.card.\(FixtureID.coreFocusPlan)")
        scrollToVisible(coreFocus)
        XCTAssertTrue(coreFocus.staticTexts["Exercise: Dead Bug"].exists)

        // A completed snapshot must remain available even after its catalogue source was removed.
        selectTab("history")
        tap(element("history.entry.\(FixtureID.coreFocusHistory)"), scrolls: true)
        waitForExistence(element("history.detail.screen"))
        tap(element("history.reuse"), scrolls: true)
        waitForLabel("Plan copied and selected", on: element("history.reuse.status"))

        relaunchPreservingData()
        openCatalogue()
        XCTAssertFalse(element("catalogue.row.\(CatalogueID.deadBug)").exists)
        closeCatalogue()
        selectTab("plans")
        let retainedPlan = element("plan.card.\(FixtureID.coreFocusPlan)")
        scrollToVisible(retainedPlan)
        XCTAssertTrue(retainedPlan.staticTexts["Exercise: Dead Bug"].exists)
    }

    private func openCatalogue() {
        selectTab("plans")
        tap(element("catalogue.open"))
        waitForExistence(element("catalogue.screen"))
    }

    private func requestSwipeDeletion(of id: String) {
        let row = element("catalogue.row.\(id)")
        scrollToHittable(row)
        row.swipeLeft()
        tap(element("catalogue.delete.\(id)"))
    }

    private func closeCatalogue() {
        tapToolbarButton("catalogue.done", label: "Done")
        waitForDisappearance(element("catalogue.screen"), timeout: 8)
    }
}
