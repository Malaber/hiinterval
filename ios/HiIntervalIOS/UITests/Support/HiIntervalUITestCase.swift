import XCTest

@MainActor
class HiIntervalUITestCase: XCTestCase {
    enum Fixture {
        case standard
        case empty
        case glanceableSession
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
        launchConfiguredApplication()
        return app
    }

    /// Relaunches without the fixture-reset argument so disk persistence can be verified.
    /// Every test's first launch still uses `--ui-testing` and an isolated fixture.
    func relaunchPreservingData() {
        app.terminate()
        app = configuredApplication(resetFixture: nil)
        launchConfiguredApplication()
    }

    func launchConfiguredApplication(
        timeout: TimeInterval = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        app.launch()
        waitForExistence(element("train.screen"), timeout: timeout, file: file, line: line)
    }

    func configuredApplication(resetFixture: Fixture?) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US_POSIX",
        ]
        if let resetFixture {
            application.launchArguments.insert("--ui-testing", at: 0)
            switch resetFixture {
            case .standard:
                break
            case .empty:
                application.launchArguments.insert("--ui-testing-empty", at: 1)
            case .glanceableSession:
                application.launchEnvironment["HIINTERVAL_UI_TEST_FIXTURE"] = "glanceable-session"
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
        // Settings has a direct Form root. Wait for that concrete scroll container,
        // rather than the NavigationStack's synthesized accessibility wrapper.
        let destination = element(name == "settings" ? "settings.form" : "\(name).screen")
        guard let tab = hittableTab(name) else {
            XCTFail("Could not find hittable tab labeled '\(name.capitalized)'", file: file, line: line)
            return
        }
        tab.tap()
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == true"), object: tab
        )
        guard XCTWaiter.wait(for: [selected], timeout: 8) == .completed else {
            captureFailedTabTransition(name)
            XCTFail("Tab was not selected after one tap: \(name)", file: file, line: line)
            return
        }
        guard destination.waitForExistence(timeout: 8) else {
            captureFailedTabTransition(name)
            XCTFail("Element did not appear: \(destination)", file: file, line: line)
            return
        }
    }

    private func captureFailedTabTransition(_ name: String) {
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Failed tab transition to \(name)"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        capture("failed-tab-\(name)")
    }

    private func hittableTab(_ name: String) -> XCUIElement? {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", name.capitalized))
        guard matches.firstMatch.waitForExistence(timeout: 3) else {
            return nil
        }
        for index in 0..<matches.count {
            let candidate = matches.element(boundBy: index)
            // iPadOS exposes a wrapper Button containing the actual tab Button.
            // Target the leaf, not whichever duplicate appears first in the tree.
            if candidate.buttons.count == 0 && candidate.isHittable {
                return candidate
            }
        }
        return nil
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
            // Some hosted iOS 26 simulators bridge SwiftUI accessibility values through an
            // Optional description. Treat that OS representation as the same semantic value.
            for: NSPredicate(
                format: "exists == true AND (value == %@ OR value == %@)",
                expected,
                "Optional(\(expected))"
            ),
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
            if target.exists && target.isHittable { return }
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

    /// Bring a Form control fully inside its sheet viewport before tapping. iPadOS can report
    /// a control behind the floating navigation bar as hittable, yet its tap only moves the sheet.
    func revealFormControl(
        _ target: XCUIElement,
        identifier: String,
        usesLeadingGutter: Bool,
        obscuringBottomControlID: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let form = app.collectionViews[identifier]
        guard waitForExistence(form, file: file, line: line) else { return }
        for _ in 0..<12 {
            let viewport = formViewport(form, obscuringBottomControlID: obscuringBottomControlID)
            if target.exists, viewport.contains(target.frame) { return }
            let up = !target.exists || target.frame.midY > viewport.midY
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: (usesLeadingGutter ? viewport.minX + 4 : viewport.midX) - app.frame.minX,
                dy: viewport.minY - app.frame.minY + viewport.height * (up ? 0.8 : 0.2)
            ))
            let end = start.withOffset(CGVector(dx: 0, dy: viewport.height * (up ? -0.5 : 0.5)))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        XCTAssertTrue(
            target.exists && formViewport(form, obscuringBottomControlID: obscuringBottomControlID)
                .contains(target.frame),
            "Form control remains clipped: \(target)",
            file: file,
            line: line
        )
    }

    private func formViewport(
        _ form: XCUIElement,
        obscuringBottomControlID: String?
    ) -> CGRect {
        var viewport = form.frame.intersection(app.frame)
        for bar in app.navigationBars.allElementsBoundByIndex where bar.isHittable {
            if bar.frame.intersects(viewport), bar.frame.maxY < viewport.midY {
                let bottom = viewport.maxY
                viewport.origin.y = max(viewport.minY, bar.frame.maxY)
                viewport.size.height = bottom - viewport.minY
            }
        }
        // Floating tab bars overlay scroll content without reducing the Form's frame.
        for bar in app.tabBars.allElementsBoundByIndex where bar.isHittable {
            if bar.frame.intersects(viewport), bar.frame.minY > viewport.midY {
                viewport.size.height = max(0, bar.frame.minY - viewport.minY)
            }
        }
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists, keyboard.frame.intersects(viewport) {
            viewport.size.height = max(0, keyboard.frame.minY - viewport.minY)
        }
        if let obscuringBottomControlID {
            let control = app.buttons[obscuringBottomControlID]
            if control.exists, control.frame.intersects(viewport), control.frame.minY > viewport.midY {
                viewport.size.height = control.frame.minY - viewport.minY
            }
        }
        return viewport.insetBy(dx: 4, dy: 8)
    }

    /// Scrolls semantic, noninteractive content into the viewport without asking XCTest for an
    /// activation point. Hosted iPad simulators can fail `isHittable` for visible static text and
    /// accessibility containers even though their frames are valid and displayed.
    func scrollToVisible(
        _ target: XCUIElement,
        maxSwipes: Int = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if !target.exists {
            _ = materialize(target, swipingUp: true, attempts: maxSwipes)
        }

        let viewport = app.frame
        for _ in 0..<maxSwipes {
            guard target.exists else {
                app.swipeUp()
                continue
            }
            let frame = target.frame
            if isVisible(frame, in: viewport) {
                return
            }
            dragScroll(up: frame.isNull || frame.isInfinite || frame.midY >= viewport.midY)
        }

        XCTAssertTrue(
            target.exists && isVisible(target.frame, in: viewport),
            "Could not scroll element into view: \(target)",
            file: file,
            line: line
        )
    }

    func scrollToTop(
        _ anchor: XCUIElement,
        maxSwipes: Int = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        scrollToHittable(anchor, file: file, line: line)
        for _ in 0..<maxSwipes {
            let previousY = anchor.frame.minY
            app.swipeDown()
            if anchor.exists, abs(anchor.frame.minY - previousY) < 1 {
                break
            }
        }
        wait(
            for: NSPredicate(format: "exists == true AND hittable == true"),
            on: anchor,
            timeout: 3,
            message: "Could not restore scroll view to its top anchor: \(anchor)",
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
        // Stay in the central content region. Starting at 72% lands inside the iPhone keyboard,
        // so the gesture can be consumed without moving the underlying Form.
        let startY: CGFloat = up ? 0.58 : 0.38
        let endY: CGFloat = up ? 0.38 : 0.58
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(forDuration: 0.01, thenDragTo: end)
    }

    private func isVisible(_ frame: CGRect, in viewport: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite && !frame.isEmpty && frame.intersects(viewport)
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
        // Hardware-key shortcuts and delete events are ignored intermittently by iOS 26 when a
        // SwiftUI TextField has just become first responder. Triple-tap uses the real touch
        // selection path and selects the complete value.
        field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        typeText(text, intoFocusedField: field, file: file, line: line)
        let keyboardDone = app.keyboards.buttons["Done"]
        if keyboardDone.exists && keyboardDone.isHittable {
            keyboardDone.tap()
        }
    }

    /// Keeps the initial focus assertion meaningful: type without tapping or refocusing the
    /// field, then finish any prefix interrupted by SwiftUI rebuilding the text input.
    func typeText(
        _ text: String,
        intoFocusedField field: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        field.typeText(text)

        // A SwiftUI TextField can be recreated after its first characters on hosted iPhone
        // and iPad simulators, cutting the in-flight typing event short. Resume the observed
        // prefix until the complete value is present; normal fields finish on the first event.
        var observed = field.value as? String ?? ""
        var attempts = 0
        while observed != text && attempts < max(3, text.count) {
            if text.hasPrefix(observed) {
                field.typeText(String(text.dropFirst(observed.count)))
            } else {
                field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
                field.typeText(text)
            }
            observed = field.value as? String ?? ""
            attempts += 1
        }
        XCTAssertEqual(
            observed,
            text,
            "Text replacement did not produce the requested value",
            file: file,
            line: line
        )
    }

    func selectSegment(
        control identifier: String,
        option: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let control = app.segmentedControls[identifier]
        let optionButton = control.buttons[option]
        tap(optionButton, scrolls: true, file: file, line: line)
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
            revealSwitch(toggle, identifier: identifier, file: file, line: line)
            // SwiftUI exposes the full Form row as the switch element. Its center can land on
            // the label without toggling. Use a fixed trailing inset: a percentage misses the
            // actual switch by roughly 100 points on a full-width iPad Form row.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                .withOffset(CGVector(dx: -28, dy: 0))
                .tap()
        }
        waitForValue(expected, on: toggle, file: file, line: line)
    }

    private func revealSwitch(
        _ target: XCUIElement,
        identifier: String,
        maxSwipes: Int = 8,
        file: StaticString,
        line: UInt
    ) {
        // `isHittable` can be true for a Form row whose trailing switch is clipped. Use the
        // containing scroll view's bounds, not an arbitrary band of the application window:
        // a short sheet may have no scroll range with which to reach that band.
        let collection = app.collectionViews.containing(.switch, identifier: identifier).firstMatch
        let scrollView = collection.exists
            ? collection
            : app.scrollViews.containing(.switch, identifier: identifier).firstMatch
        guard waitForExistence(scrollView, file: file, line: line) else { return }

        let applicationFrame = app.frame
        var viewport = scrollView.frame.intersection(applicationFrame)
        for bar in app.navigationBars.allElementsBoundByIndex where bar.isHittable {
            let overlap = viewport.intersection(bar.frame)
            if !overlap.isNull && overlap.maxY < viewport.midY {
                let bottom = viewport.maxY
                viewport.origin.y = overlap.maxY
                viewport.size.height = bottom - overlap.maxY
            }
        }
        // Floating tab bars overlay scroll content without reducing the Form's frame.
        for bar in app.tabBars.allElementsBoundByIndex where bar.isHittable {
            if bar.frame.intersects(viewport), bar.frame.minY > viewport.midY {
                viewport.size.height = max(0, bar.frame.minY - viewport.minY)
            }
        }
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists, keyboard.frame.intersects(viewport) {
            viewport.size.height = max(0, keyboard.frame.minY - viewport.minY)
        }
        viewport = viewport.insetBy(dx: 0, dy: 8)

        for _ in 0..<maxSwipes {
            let frame = target.frame
            if viewport.contains(frame) { return }
            let scrollsUp = frame.midY > viewport.midY
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: viewport.midX - applicationFrame.minX,
                dy: viewport.minY - applicationFrame.minY + viewport.height * (scrollsUp ? 0.75 : 0.25)
            ))
            let end = start.withOffset(CGVector(dx: 0, dy: viewport.height * (scrollsUp ? -0.4 : 0.4)))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        let frame = target.frame
        XCTAssertTrue(
            viewport.contains(frame),
            "Switch \(identifier) at \(frame) is clipped by its scroll viewport \(viewport)",
            file: file,
            line: line
        )
    }

    func capture(_ name: String) {
        // Capture the tested application, not the simulator display shared with SpringBoard.
        // Global display capture can stall after background/foreground and sheet transitions.
        let screenshot = app.screenshot()
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
        message: @autoclosure () -> String,
        file: StaticString,
        line: UInt
    ) -> Bool {
        // A hosted accessibility snapshot can itself take longer than a short waiter timeout.
        // Accept an already-satisfied predicate before starting the asynchronous waiter, and
        // avoid fetching another snapshot solely to format a successful assertion's message.
        if predicate.evaluate(with: object) { return true }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: object)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail(message(), file: file, line: line)
        }
        return result == .completed
    }
}
