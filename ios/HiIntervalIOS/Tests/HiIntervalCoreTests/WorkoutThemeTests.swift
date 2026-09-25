import XCTest
@testable import HiIntervalCore

final class WorkoutThemeTests: XCTestCase {
    func testPresetThemesHaveDistinctPhaseColors() {
        for preset in WorkoutThemePreset.allCases {
            XCTAssertFalse(preset.displayName.isEmpty)
            let theme = preset.theme
            XCTAssertTrue(theme.hasDistinctWorkAndRecovery)
            XCTAssertNotEqual(theme.workColor, theme.recoveryColor, "\(preset) needs distinct work and recovery colors")
            XCTAssertNotEqual(theme.recoveryColor, theme.transitionColor, "\(preset) needs distinct recovery and transition colors")
        }
    }

    func testLegacyPresetsGainDistinctColorsAndRemainSelected() throws {
        for preset in WorkoutThemePreset.allCases {
            let decoded = try decodeLegacy(preset.theme)
            XCTAssertEqual(decoded, preset.theme)
            XCTAssertNotEqual(decoded.roundRecoveryColor, decoded.recoveryColor)
            XCTAssertNotEqual(decoded.sideSwitchColor, decoded.recoveryColor)
        }
    }

    func testLegacyCustomThemePreservesColors() throws {
        let custom = WorkoutTheme(workColor: .white, recoveryColor: .defaultBackground,
                                  transitionColor: WorkoutLogoColor(red: 0.6, green: 0.3, blue: 0.2))
        let decoded = try decodeLegacy(custom)
        XCTAssertEqual(decoded, custom)
        XCTAssertEqual(decoded.roundRecoveryColor, custom.transitionColor)
        XCTAssertEqual(decoded.sideSwitchColor, WorkoutTheme.default.sideSwitchColor)
    }

    func testAllPhaseKindsUseTheirConfiguredColor() {
        let theme = WorkoutThemePreset.sunset.theme
        XCTAssertEqual(theme.color(for: .work), theme.workColor)
        XCTAssertEqual(theme.color(for: .recovery), theme.recoveryColor)
        XCTAssertEqual(theme.color(for: .roundRecovery), theme.roundRecoveryColor)
        XCTAssertEqual(theme.color(for: .sideSwitch), theme.sideSwitchColor)
        XCTAssertEqual(theme.color(for: .warmUp), theme.transitionColor)
        XCTAssertEqual(theme.color(for: .coolDown), theme.transitionColor)
    }

    private func decodeLegacy(_ theme: WorkoutTheme) throws -> WorkoutTheme {
        let encoded = try JSONEncoder().encode(theme)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "roundRecoveryColor")
        object.removeValue(forKey: "sideSwitchColor")
        return try JSONDecoder().decode(WorkoutTheme.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testGlobalPreferencesRoundTripAndLegacyDefault() throws {
        var preferences = UserPreferences()
        preferences.workoutTheme = WorkoutThemePreset.forest.theme
        let data = try AppDataCodec.encode(AppData(preferences: preferences))
        XCTAssertEqual(try AppDataCodec.decode(data).preferences.workoutTheme, preferences.workoutTheme)
        XCTAssertEqual(try JSONDecoder().decode(UserPreferences.self, from: Data("{}".utf8)).workoutTheme, .default)
        let identical = WorkoutTheme(workColor: .white, recoveryColor: .white, transitionColor: .defaultBackground)
        XCTAssertFalse(identical.hasDistinctWorkAndRecovery)
        XCTAssertFalse(identical.prefersDarkText(for: WorkoutLogoColor(red: 0, green: 0, blue: 0)))
    }

    func testThemeRoundTripsThroughJSON() throws {
        let theme = WorkoutThemePreset.sunset.theme

        let decoded = try JSONDecoder().decode(WorkoutTheme.self, from: JSONEncoder().encode(theme))

        XCTAssertEqual(decoded, theme)
    }

    func testThemeChoosesDarkTextForLightColorAndLightTextForDarkColor() {
        let theme = WorkoutTheme.default

        XCTAssertTrue(theme.prefersDarkText(for: WorkoutLogoColor(red: 1, green: 1, blue: 1)))
        XCTAssertFalse(theme.prefersDarkText(for: WorkoutLogoColor(red: 0.05, green: 0.05, blue: 0.05)))
    }
}
