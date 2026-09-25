import Foundation

/// Global phase colors used while a workout is running.
///
/// Themes deliberately live in user preferences instead of a workout plan. A plan's
/// timing and exercises are stable, while its presentation follows the owner's current choice.
public struct WorkoutTheme: Codable, Equatable, Sendable {
    public var workColor: WorkoutLogoColor
    public var recoveryColor: WorkoutLogoColor
    public var transitionColor: WorkoutLogoColor
    public var roundRecoveryColor: WorkoutLogoColor
    public var sideSwitchColor: WorkoutLogoColor

    public init(
        workColor: WorkoutLogoColor,
        recoveryColor: WorkoutLogoColor,
        transitionColor: WorkoutLogoColor,
        roundRecoveryColor: WorkoutLogoColor? = nil,
        sideSwitchColor: WorkoutLogoColor? = nil
    ) {
        self.workColor = workColor
        self.recoveryColor = recoveryColor
        self.transitionColor = transitionColor
        self.roundRecoveryColor = roundRecoveryColor ?? transitionColor
        self.sideSwitchColor = sideSwitchColor ?? Self.defaultSideSwitchColor
    }

    private static let defaultSideSwitchColor = WorkoutLogoColor(red: 0.25, green: 0.58, blue: 0.91)

    private enum CodingKeys: String, CodingKey {
        case workColor, recoveryColor, transitionColor, roundRecoveryColor, sideSwitchColor
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let work = try values.decode(WorkoutLogoColor.self, forKey: .workColor)
        let recovery = try values.decode(WorkoutLogoColor.self, forKey: .recoveryColor)
        let transition = try values.decode(WorkoutLogoColor.self, forKey: .transitionColor)
        // Restore the complete palette when an older saved theme matches a preset.
        // Unknown custom themes keep their transition color for round breaks.
        let oldPreset = WorkoutThemePreset.allCases.map(\.theme).first {
            $0.workColor == work && $0.recoveryColor == recovery && $0.transitionColor == transition
        }
        workColor = work
        recoveryColor = recovery
        transitionColor = transition
        roundRecoveryColor = try values.decodeIfPresent(WorkoutLogoColor.self, forKey: .roundRecoveryColor)
            ?? oldPreset?.roundRecoveryColor ?? transition
        sideSwitchColor = try values.decodeIfPresent(WorkoutLogoColor.self, forKey: .sideSwitchColor)
            ?? oldPreset?.sideSwitchColor ?? Self.defaultSideSwitchColor
    }

    public func color(for kind: WorkoutPhaseKind) -> WorkoutLogoColor {
        switch kind {
        case .work: workColor
        case .recovery: recoveryColor
        case .roundRecovery: roundRecoveryColor
        case .sideSwitch: sideSwitchColor
        case .warmUp, .coolDown: transitionColor
        }
    }

    public static let `default` = WorkoutTheme(
        workColor: WorkoutLogoColor(red: 0.10, green: 0.78, blue: 0.69),
        recoveryColor: WorkoutLogoColor(red: 0.45, green: 0.42, blue: 0.98),
        transitionColor: WorkoutLogoColor(red: 1.00, green: 0.66, blue: 0.18),
        roundRecoveryColor: WorkoutLogoColor(red: 0.94, green: 0.62, blue: 0.18)
    )

    public var hasDistinctWorkAndRecovery: Bool {
        let differences = [workColor.red - recoveryColor.red, workColor.green - recoveryColor.green,
                           workColor.blue - recoveryColor.blue]
        return differences.reduce(0) { $0 + $1 * $1 } >= 0.0225
    }

    /// Use dark text for light backgrounds and light text for dark backgrounds.
    public func prefersDarkText(for color: WorkoutLogoColor) -> Bool {
        // This is crossover where black and white have equal contrast against a color.
        color.relativeLuminance > 0.179
    }
}

public enum WorkoutThemePreset: String, CaseIterable, Codable, Sendable {
    case vibrant
    case ocean
    case sunset
    case forest

    public var theme: WorkoutTheme {
        switch self {
        case .vibrant:
            return .default
        case .ocean:
            return WorkoutTheme(
                workColor: WorkoutLogoColor(red: 0.08, green: 0.56, blue: 0.86),
                recoveryColor: WorkoutLogoColor(red: 0.30, green: 0.29, blue: 0.70),
                transitionColor: WorkoutLogoColor(red: 0.12, green: 0.70, blue: 0.72),
                roundRecoveryColor: WorkoutLogoColor(red: 0.96, green: 0.67, blue: 0.22),
                sideSwitchColor: WorkoutLogoColor(red: 0.32, green: 0.67, blue: 0.94)
            )
        case .sunset:
            return WorkoutTheme(
                workColor: WorkoutLogoColor(red: 0.92, green: 0.31, blue: 0.31),
                recoveryColor: WorkoutLogoColor(red: 0.56, green: 0.24, blue: 0.72),
                transitionColor: WorkoutLogoColor(red: 0.96, green: 0.58, blue: 0.12),
                roundRecoveryColor: WorkoutLogoColor(red: 1.00, green: 0.72, blue: 0.24),
                sideSwitchColor: WorkoutLogoColor(red: 0.31, green: 0.59, blue: 0.92)
            )
        case .forest:
            return WorkoutTheme(
                workColor: WorkoutLogoColor(red: 0.10, green: 0.48, blue: 0.30),
                recoveryColor: WorkoutLogoColor(red: 0.29, green: 0.37, blue: 0.65),
                transitionColor: WorkoutLogoColor(red: 0.73, green: 0.54, blue: 0.13),
                roundRecoveryColor: WorkoutLogoColor(red: 0.90, green: 0.66, blue: 0.23),
                sideSwitchColor: WorkoutLogoColor(red: 0.26, green: 0.56, blue: 0.82)
            )
        }
    }

    public var displayName: String {
        switch self {
        case .vibrant: return "Vibrant"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        }
    }
}

public extension WorkoutLogoColor {
    var relativeLuminance: Double {
        0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
    }

    private func linearized(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}
