import XCTest

@MainActor
class HiIntervalUITestCase: XCTestCase {
    enum Fixture {
        case standard
        case empty
    }

    enum FixtureID {
        static let quickStartPlan = "00000000-0000-0000-0000-000000000001"
        static let coreFocusPlan = "00000000-0000-0000-0000-000000000002"
        static let coreFocusHistory = "00000000-0000-0000-0000-00000000001F"
    }

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
    }

    @discardableResult
    func launch(fixture: Fixture = .standard) -> XCUIApplication {
        app = configuredApplication(resetFixture: fixture)
        app.launch()
        waitForExistence(element("train.screen"), timeout: 8)
        return app
    }

    /// Relaunches without the fixture-reset argument so disk persistence can be verified.
    /// Every test's first launch still uses `--ui-testing` and an isolated fixture.
    func relaunchPreservingData() {
        app.terminate()
        app = configuredApplication(resetFixture: nil)
        app.launch()
        waitForExistence(element("train.screen"), timeout: 8)
    }

    func configuredApplication(resetFixture: Fixture?) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US_POSIX",
        ]
        if let resetFixture {
            application.launchArguments.insert("--ui-testing", at: 0)
            if resetFixture == .empty {
                application.launchArguments.insert("--ui-testing-empty", at: 1)
            }
        }
        application.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "60"
        application.launchEnvironment["TZ"] = "UTC"
        return application
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func selectTab(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let identified = element("tab.\(name)")
        let tabBarButton = app.tabBars.buttons[name.capitalized]
        let visibleButton = app.buttons[name.capitalized]
        let target = identified.exists
            ? identified
            : (tabBarButton.exists ? tabBarButton : visibleButton)
        tap(target, file: file, line: line)
        waitForExistence(element("\(name).screen"), file: file, line: line)
    }

    @discardableResult
    func waitForExistence(
        _ target: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        wait(
            for: NSPredicate(format: "exists == true"),
            on: target,
            timeout: timeout,
            message: "Element did not appear: \(target)",
            file: file,
            line: line
        )
    }

    @discardableResult
    func waitForDisappearance(
        _ target: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        wait(
            for: NSPredicate(format: "exists == false"),
            on: target,
            timeout: timeout,
            message: "Element remained visible: \(target)",
            file: file,
            line: line
        )
    }

    @discardableResult
    func waitForLabel(
        _ expected: String,
        on target: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        wait(
            for: NSPredicate(format: "exists == true AND label == %@", expected),
            on: target,
            timeout: timeout,
            message: "Expected label '\(expected)', got '\(target.label)'",
            file: file,
            line: line
        )
    }

    @discardableResult
    func waitForLabelToChange(
        from oldLabel: String,
        on target: XCUIElement,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        wait(
            for: NSPredicate(format: "exists == true AND label != %@", oldLabel),
            on: target,
            timeout: timeout,
            message: "Label stayed '\(oldLabel)'",
            file: file,
            line: line
        )
    }

    @discardableResult
    func waitForValue(
        _ expected: String,
        on target: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        wait(
            for: NSPredicate(format: "exists == true AND value == %@", expected),
            on: target,
            timeout: timeout,
            message: "Expected value '\(expected)', got '\(String(describing: target.value))'",
            file: file,
            line: line
        )
    }

    func assertLabelRemainsStable(
        on target: XCUIElement,
        for duration: TimeInterval = 0.45,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let original = target.label
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", original),
            object: target
        )
        changed.isInverted = true
        let result = XCTWaiter.wait(for: [changed], timeout: duration)
        XCTAssertEqual(
            result,
            .completed,
            "Label changed while timer should be frozen: '\(original)' -> '\(target.label)'",
            file: file,
            line: line
        )
    }

    func tap(
        _ target: XCUIElement,
        scrolls: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if scrolls {
            scrollToHittable(target, file: file, line: line)
        } else {
            waitForExistence(target, file: file, line: line)
            wait(
                for: NSPredicate(format: "exists == true AND hittable == true"),
                on: target,
                timeout: 3,
                message: "Element is not hittable: \(target)",
                file: file,
                line: line
            )
        }
        target.tap()
    }

    /// SwiftUI toolbar identifiers can temporarily resolve to a non-hittable proxy while a
    /// sheet's keyboard is presented. Prefer the stable ID, then use the visible toolbar label.
    func tapToolbarButton(
        _ identifier: String,
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let identified = app.buttons[identifier]
        let labeled = app.navigationBars.buttons[label]
        let target = identified.exists && identified.isHittable ? identified : labeled
        tap(target, file: file, line: line)
    }

    /// Keeps the query scoped to one lazy plan card, so semantic-label fallback cannot select
    /// the same action from another card while either normal or accessibility layout is active.
    func planActionButton(
        planID: String,
        identifier: String,
        fallbackLabel: String
    ) -> XCUIElement {
        element("plan.card.\(planID)")
            .descendants(matching: .button)
            .matching(
                NSPredicate(
                    format: "identifier == %@ OR label == %@",
                    identifier,
                    fallbackLabel
                )
            )
            .firstMatch
    }

    /// Selects the visible action when a dialog and its obscured source button share a label.
    func tapVisibleButton(
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
        waitForExistence(matches.firstMatch, file: file, line: line)
        for index in 0..<matches.count {
            let candidate = matches.element(boundBy: index)
            if candidate.isHittable {
                candidate.tap()
                return
            }
        }
        XCTFail("No visible button labeled '\(label)'", file: file, line: line)
    }

    func scrollToHittable(
        _ target: XCUIElement,
        maxSwipes: Int = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // SwiftUI creates LazyVStack/List/Form rows only near the current viewport. Probe the
        // common downward direction first, then deterministically sweep from bottom to top and
        // back down so callers also recover when a relaunch preserves a low scroll position.
        if !target.exists {
            let probeCount = min(4, maxSwipes)
            _ = materialize(target, swipingUp: true, attempts: probeCount)
            if !target.exists {
                _ = materialize(target, swipingUp: false, attempts: maxSwipes)
            }
            if !target.exists {
                _ = materialize(target, swipingUp: true, attempts: maxSwipes)
            }
        }

        // Once materialized, short drags avoid jumping an almost-visible control past the
        // opposite edge of the viewport.
        let viewport = app.frame
        for _ in 0..<maxSwipes {
            if target.exists && target.isHittable { break }
            guard target.exists else { break }
            let scrollsUp = target.frame.midY >= viewport.midY
            dragScroll(up: scrollsUp)
        }
        wait(
            for: NSPredicate(format: "exists == true AND hittable == true"),
            on: target,
            timeout: 3,
            message: "Could not scroll element into view: \(target)",
            file: file,
            line: line
        )
    }

    @discardableResult
    private func materialize(
        _ target: XCUIElement,
        swipingUp: Bool,
        attempts: Int
    ) -> Bool {
        for _ in 0..<attempts {
            if target.exists { return true }
            if swipingUp {
                app.swipeUp()
            } else {
                app.swipeDown()
            }
        }
        return target.exists
    }

    private func dragScroll(up: Bool) {
        let startY: CGFloat = up ? 0.72 : 0.28
        let endY: CGFloat = up ? 0.52 : 0.48
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(forDuration: 0.01, thenDragTo: end)
    }

    func replaceText(
        in field: XCUIElement,
        with text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if field.exists && field.isHittable {
            tap(field, file: file, line: line)
        } else {
            tap(field, scrolls: true, file: file, line: line)
        }
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
        let keyboardDone = app.keyboards.buttons["Done"]
        if keyboardDone.exists && keyboardDone.isHittable {
            keyboardDone.tap()
        }
    }

    func selectSegment(
        control identifier: String,
        option: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let control = app.segmentedControls[identifier]
        scrollToHittable(control, file: file, line: line)
        let optionButton = control.buttons[option]
        tap(optionButton, file: file, line: line)
        XCTAssertTrue(optionButton.isSelected, "Segment was not selected: \(option)", file: file, line: line)
    }

    func incrementStepper(
        _ identifier: String,
        times: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // The Stepper group itself is sometimes reported non-hittable even while its controls
        // are visible. SwiftUI deterministically derives this child ID from the stable row ID.
        let increment = app.buttons["\(identifier)-Increment"]
        scrollToHittable(increment, file: file, line: line)
        for _ in 0..<times {
            increment.tap()
        }
    }

    func setSwitch(
        _ identifier: String,
        to enabled: Bool,
        scrolls: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let toggle = app.switches[identifier]
        if scrolls {
            scrollToHittable(toggle, file: file, line: line)
        } else {
            waitForExistence(toggle, file: file, line: line)
        }
        let expected = enabled ? "1" : "0"
        if String(describing: toggle.value ?? "") != expected {
            // SwiftUI exposes the full Form row as the switch element. Its center can land on
            // the label without toggling on some runtimes; the trailing point is the switch.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        waitForValue(expected, on: toggle, file: file, line: line)
    }

    func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let artifactDirectory = ProcessInfo.processInfo.environment["HIINTERVAL_UI_TEST_ARTIFACT_DIR"],
              !artifactDirectory.isEmpty else {
            return
        }

        let testClass = String(describing: type(of: self))
        let rawName = "\(testClass)-\(name)"
        let safeName = rawName.map { character in
            character.isLetter || character.isNumber || character == "-" ? character : "-"
        }
        let directory = URL(fileURLWithPath: artifactDirectory, isDirectory: true)
        let destination = directory.appendingPathComponent(String(safeName) + ".png")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: destination, options: .atomic)
        } catch {
            XCTFail("Could not write screenshot artifact at \(destination.path): \(error)")
        }
    }

    @discardableResult
    private func wait(
        for predicate: NSPredicate,
        on object: Any,
        timeout: TimeInterval,
        message: String,
        file: StaticString,
        line: UInt
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: object)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, message, file: file, line: line)
        return result == .completed
    }
}
