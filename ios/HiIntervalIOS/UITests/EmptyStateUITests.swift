import XCTest

@MainActor
final class EmptyStateUITests: HiIntervalUITestCase {
    func testEmptyFixtureShowsActionableTrainPlansAndHistoryStates() {
        launch(fixture: .empty)

        waitForExistence(app.staticTexts["Create your first plan"])
        XCTAssertFalse(element("train.start").exists)
        XCTAssertTrue(element("train.free-status").exists)
        capture("01-empty-train")

        selectTab("plans")
        waitForExistence(element("plans.empty.create"))
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'plan.card.'"))
                .count,
            0
        )
        capture("02-empty-plans")

        selectTab("history")
        waitForExistence(app.staticTexts["No sessions yet"])
        XCTAssertFalse(element("history.export").exists)
        capture("03-empty-history")
    }
}
