import XCTest

@MainActor
final class SettingsUITests: HiIntervalUITestCase {
    func testSettingsFormUsesFullAvailableHeight() {
        launch()
        selectTab("settings")

        let screen = element("settings.screen")
        let form = element("settings.form")
        waitForExistence(form)
        waitForLabel(
            "Audio cues play in Silent Mode. Spoken cues can follow device language or use English or German.",
            on: element("settings.cues-note")
        )

        let maximumReservedHeight: CGFloat
        if #available(iOS 26.0, *) {
            // The floating tab bar needs its safe-area footprint plus a clear scroll boundary.
            maximumReservedHeight = 160
        } else {
            maximumReservedHeight = 80
        }

        XCTAssertLessThanOrEqual(
            screen.frame.maxY - form.frame.maxY,
            maximumReservedHeight,
            "Settings should not reserve an oversized bar below the form"
        )
        capture("01-settings-full-height")
    }

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

    func testWorkoutThemePresetSavesGlobally() {
        launch()
        selectTab("settings")

        let theme = element("settings.workout-theme")
        scrollToHittable(theme)
        tap(theme)
        waitForExistence(element("settings.workout-theme.preview"))

        tap(element("settings.workout-theme.preset.ocean"))
        tap(element("settings.workout-theme.save"))
        waitForExistence(theme)
        relaunchPreservingData()
        selectTab("settings")
        tap(theme, scrolls: true)
        let ocean = element("settings.workout-theme.preset.ocean")
        scrollToHittable(ocean)
        waitForValue("Selected", on: ocean)
        tap(element("settings.workout-theme.preset.forest"), scrolls: true)
        tap(element("settings.workout-theme.cancel"))
        tap(theme, scrolls: true)
        waitForValue("Selected", on: ocean)
        tap(element("settings.workout-theme.reset"))
        tap(element("settings.workout-theme.save"))
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
