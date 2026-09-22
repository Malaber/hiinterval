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
