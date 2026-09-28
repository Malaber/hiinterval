import XCTest

@MainActor
final class SettingsUITests: HiIntervalUITestCase {
    func testSettingsFormUsesFullAvailableHeight() {
        launch()
        selectTab("settings")

        let screen = element("settings.screen")
        let form = element("settings.form")
        waitForExistence(form)

        // Native tab-bar/safe-area space only; an extra fixed strip must not shorten the Form.
        let maximumReservedHeight: CGFloat = 100

        XCTAssertLessThanOrEqual(
            screen.frame.maxY - form.frame.maxY,
            maximumReservedHeight,
            "Settings should not reserve an oversized bar below the form"
        )
        capture("01-settings-full-height")

        openCustomization()
        waitForLabel(
            "Audio cues play in Silent Mode. Spoken cues can follow device language or use English or German.",
            on: element("settings.cues-note")
        )
    }

    func testPreferencesPersistAcrossNavigationAndRelaunch() {
        launch()
        selectTab("settings")

        XCTAssertTrue(element("settings.free-status").exists)
        openCustomization()
        setSwitch("settings.haptics", to: false)
        setSwitch("settings.duck-audio", to: true)
        setSwitch("settings.halfway-cue", to: false)
        leaveCustomization()
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
        openCustomization()

        let theme = element("settings.workout-theme")
        scrollToHittable(theme)
        tap(theme)
        waitForExistence(element("settings.workout-theme.preview"))

        for identifier in ["round-recovery", "side-switch"] {
            let picker = element("settings.workout-theme.\(identifier)")
            scrollToHittable(picker)
            XCTAssertTrue(picker.isHittable)
        }
        tap(element("settings.workout-theme.preset.ocean"), scrolls: true)
        tapToolbarButton("settings.workout-theme.save", label: "Save")
        waitForExistence(theme)
        relaunchPreservingData()
        selectTab("settings")
        openCustomization()
        tap(theme, scrolls: true)
        let ocean = element("settings.workout-theme.preset.ocean")
        let preview = element("settings.workout-theme.preview")
        waitForExistence(preview)
        XCTAssertGreaterThan(preview.frame.height, 300)
        scrollToHittable(ocean)
        waitForValue("Selected", on: ocean)
        tap(element("settings.workout-theme.preset.forest"), scrolls: true)
        tapToolbarButton("settings.workout-theme.cancel", label: "Cancel")
        tap(theme, scrolls: true)
        scrollToHittable(ocean)
        waitForValue("Selected", on: ocean)
        tap(app.buttons["settings.workout-theme.reset"])
        tapToolbarButton("settings.workout-theme.save", label: "Save")
    }

    func testToneCustomizationSavesCancelsAndResets() {
        launch()
        selectTab("settings")
        openCustomization()

        tap(element("settings.tone-customization"), scrolls: true)
        waitForExistence(element("settings.tone.preset.work"))
        let workoutPreview = element("settings.tone.workout-preview")
        waitForExistence(workoutPreview)
        XCTAssertGreaterThan(workoutPreview.frame.height, 300)
        for event in ["work", "transition", "countdown", "halfway", "pause", "resume", "completion"] {
            let preset = element("settings.tone.preset.\(event)")
            let preview = element("settings.tone.preview.\(event)")
            scrollToHittable(preset)
            XCTAssertTrue(preset.isHittable)
            scrollToHittable(preview)
            XCTAssertTrue(preview.isHittable)
        }
        tap(element("settings.tone.preview.completion"), scrolls: true)
        waitForExistence(workoutPreview)

        chooseTone("Bright", for: "work")
        waitForValue("Bright", on: element("settings.tone.preset.work"))
        tapToolbarButton("settings.tone.cancel", label: "Cancel")
        waitForDisappearance(element("settings.tone.save"))
        tap(element("settings.tone-customization"), scrolls: true)
        waitForValue("Classic", on: element("settings.tone.preset.work"))

        chooseTone("Mellow", for: "completion")
        waitForValue("Mellow", on: element("settings.tone.preset.completion"))
        tapToolbarButton("settings.tone.save", label: "Save")
        waitForDisappearance(element("settings.tone.save"))
        relaunchPreservingData()
        selectTab("settings")
        openCustomization()
        tap(element("settings.tone-customization"), scrolls: true)
        let completionPreset = element("settings.tone.preset.completion")
        scrollToHittable(completionPreset)
        waitForValue("Mellow", on: completionPreset)

        tap(app.buttons["settings.tone.reset"])
        waitForValue("Classic", on: element("settings.tone.preset.completion"))
        tapToolbarButton("settings.tone.save", label: "Save")
        waitForDisappearance(element("settings.tone.save"))
        tap(element("settings.tone-customization"), scrolls: true)
        scrollToHittable(completionPreset)
        waitForValue("Classic", on: completionPreset)
    }

    private func assertPersistedPreferences() {
        openCustomization()
        assertSwitch("settings.haptics", value: "0")
        assertSwitch("settings.duck-audio", value: "1")
        assertSwitch("settings.halfway-cue", value: "0")
        leaveCustomization()
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

    private func openCustomization() {
        tap(element("settings.customization"), scrolls: true)
        waitForExistence(element("settings.customization.screen"))
    }

    private func leaveCustomization() {
        tap(app.navigationBars.buttons["Settings"])
        waitForExistence(element("settings.form"))
    }

    private func chooseTone(_ name: String, for event: String) {
        tap(element("settings.tone.preset.\(event)"), scrolls: true)
        tapVisibleButton(name)
    }
}
