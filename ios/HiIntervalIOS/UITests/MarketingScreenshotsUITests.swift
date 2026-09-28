import Foundation
import XCTest

@MainActor
final class MarketingScreenshotsUITests: HiIntervalUITestCase {
    func testCaptureCataloguePlanningAndHistory() {
        launch()
        waitForLabel("Quick Start", on: element("train.selected-plan-name"))
        saveMarketingScreenshot("01-train")

        selectTab("plans")
        waitForExistence(element("plan.card.\(FixtureID.quickStartPlan)"))
        waitForExistence(element("plan.card.\(FixtureID.coreFocusPlan)"))
        saveMarketingScreenshot("02-plans")

        tap(element("catalogue.open"))
        waitForExistence(element("catalogue.screen"))
        waitForExistence(element("catalogue.row.00000000-0000-0000-0000-00000000000B"))
        saveMarketingScreenshot("03-exercise-catalogue")

        tapToolbarButton("catalogue.done", label: "Done")
        waitForDisappearance(element("catalogue.screen"), timeout: 8)
        selectTab("history")
        waitForExistence(element("history.entry.\(FixtureID.coreFocusHistory)"))
        saveMarketingScreenshot("04-history")
    }

    func testCaptureActiveWorkout() {
        app = configuredApplication(resetFixture: .glanceableSession)
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        launchConfiguredApplication()

        tap(element("train.start"))
        waitForExistence(element("session.screen"))
        tap(element("session.skip")) // Long fixture warm-up ends; first work interval stays visible.
        waitForLabel("High Knees", on: element("session.exercise"))
        waitForLabel("WORK", on: element("session.phase-kind"))
        XCTAssertFalse(element("session.paused").exists)
        saveMarketingScreenshot("05-active-workout")
    }

    private func saveMarketingScreenshot(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let artifactDirectory = ProcessInfo.processInfo.environment["HIINTERVAL_UI_TEST_ARTIFACT_DIR"],
              !artifactDirectory.isEmpty else {
            return
        }
        let directory = URL(fileURLWithPath: artifactDirectory, isDirectory: true)
            .appendingPathComponent("marketing/en-US", isDirectory: true)
        let destination = directory.appendingPathComponent("\(name).png")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: destination, options: .atomic)
        } catch {
            XCTFail("Could not write marketing screenshot at \(destination.path): \(error)",
                    file: file, line: line)
        }
    }
}
