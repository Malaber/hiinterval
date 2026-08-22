import XCTest

@MainActor
final class AccessibilityUITests: HiIntervalUITestCase {
    private let systemAuditTypes: XCUIAccessibilityAuditType = [
        .contrast,
        .elementDetection,
        .hitRegion,
        .sufficientElementDescription,
        .textClipped,
        .trait,
    ]

    func testPrimarySurfacesPassSystemAccessibilityAudit() throws {
        launch()

        var findings: [String] = []
        findings += try auditFindings(on: "Train", colorScheme: "light")
        selectTab("plans")
        findings += try auditFindings(on: "Plans", colorScheme: "light")
        selectTab("history")
        findings += try auditFindings(on: "History", colorScheme: "light")
        selectTab("settings")
        findings += try auditFindings(on: "Settings", colorScheme: "light")

        selectSegment(control: "settings.appearance", option: "Dark")
        scrollToHittable(element("settings.free-status"))
        selectTab("train")
        findings += try auditFindings(on: "Train", colorScheme: "dark")
        selectTab("plans")
        findings += try auditFindings(on: "Plans", colorScheme: "dark")
        selectTab("history")
        findings += try auditFindings(on: "History", colorScheme: "dark")
        selectTab("settings")
        findings += try auditFindings(on: "Settings", colorScheme: "dark")

        XCTAssertTrue(
            findings.isEmpty,
            "Accessibility audit findings:\n" + findings.joined(separator: "\n")
        )
    }

    func testPrimarySurfacesRemainUsableAtLargestAccessibilityTextSize() {
        app = configuredApplication(resetFixture: .standard)
        app.launchEnvironment["HIINTERVAL_UI_TEST_DYNAMIC_TYPE"] = "accessibility5"
        app.launch()

        waitForExistence(element("train.screen"), timeout: 8)
        scrollToHittable(element("train.start"))
        capture("dynamic-type-train")

        selectTab("plans")
        scrollToHittable(app.staticTexts["Quick Start"])
        waitForExistence(element("plans.add"))
        capture("dynamic-type-plans")

        selectTab("history")
        scrollToHittable(element("history.entry.\(FixtureID.coreFocusHistory)"))
        capture("dynamic-type-history")

        selectTab("settings")
        scrollToHittable(element("settings.keep-awake"))
        capture("dynamic-type-settings")
    }

    private func auditFindings(on surface: String, colorScheme: String) throws -> [String] {
        var findings: [String] = []
        var unmappedNativeFormContrasts = 0
        try app.performAccessibilityAudit(for: systemAuditTypes) { issue in
            // iOS 26.3 emits two contrast findings for native Form chrome without an element,
            // label, or frame. Cap that exact runtime allowance so additional unmapped visual
            // regressions still fail the gate; every mapped finding always remains visible.
            if surface == "Settings", issue.auditType == .contrast, issue.element == nil {
                unmappedNativeFormContrasts += 1
                return true
            }
            let element = issue.element
            let label = element?.label ?? "unlabeled element"
            let identifier = element?.identifier ?? ""
            let frame = element.map { NSCoder.string(for: $0.frame) } ?? "nil"
            let elementType = element.map { String(describing: $0.elementType) } ?? "nil"
            findings.append(
                "\(colorScheme.capitalized) \(surface): \(issue.compactDescription) "
                    + "[label=\(label), id=\(identifier), type=\(elementType), frame=\(frame)] "
                    + "— \(issue.detailedDescription)"
            )
            // Record all issues in one assertion so every primary surface is audited per run.
            return true
        }
        if unmappedNativeFormContrasts > 2 {
            findings.append(
                "\(colorScheme.capitalized) Settings: expected at most 2 unmapped native Form "
                    + "contrast findings, received \(unmappedNativeFormContrasts)"
            )
        }
        return findings
    }
}
