import XCTest

@MainActor
final class SettingsUITests: HiIntervalUITestCase {
    func testPreferencesPersistAcrossNavigationAndRelaunch() {
        launch()
        selectTab("settings")

        XCTAssertTrue(element("settings.free-status").exists)
        setSwitch("settings.haptics", to: false)
        setSwitch("settings.duck-audio", to: true)
        setSwitch("settings.pause-background", to: true)
        setSwitch("settings.keep-awake", to: false)
        setSwitch("settings.reminders", to: true)
        let sunday = element("settings.weekday.1")
        scrollToHittable(sunday)
        tap(sunday)
        waitForValue("Selected", on: sunday)
        selectSegment(control: "settings.appearance", option: "Dark")
        capture("01-custom-settings")

        selectTab("train")
        selectTab("settings")
        assertPersistedPreferences()

        relaunchPreservingData()
        selectTab("settings")
        assertPersistedPreferences()
        capture("02-settings-after-relaunch")
    }

    private func assertPersistedPreferences() {
        assertSwitch("settings.haptics", value: "0")
        assertSwitch("settings.duck-audio", value: "1")
        assertSwitch("settings.pause-background", value: "1")
        assertSwitch("settings.keep-awake", value: "0")
        assertSwitch("settings.reminders", value: "1")

        let sunday = element("settings.weekday.1")
        scrollToHittable(sunday)
        waitForValue("Selected", on: sunday)

        let appearance = app.segmentedControls["settings.appearance"]
        scrollToHittable(appearance)
        XCTAssertTrue(appearance.buttons["Dark"].isSelected)
    }

    private func assertSwitch(_ identifier: String, value: String) {
        let toggle = app.switches[identifier]
        scrollToHittable(toggle)
        waitForValue(value, on: toggle)
    }
}
