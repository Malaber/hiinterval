import HiIntervalCore
import SwiftUI
import UIKit

@MainActor
enum HITheme {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let hero: CGFloat = 48
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 20
        static let large: CGFloat = 28
    }

    static let canvas = adaptive(
        light: UIColor(red: 0.95, green: 0.97, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.055, blue: 0.075, alpha: 1)
    )
    static let canvasRaised = adaptive(
        light: UIColor(red: 0.985, green: 0.99, blue: 1, alpha: 1),
        dark: UIColor(red: 0.055, green: 0.08, blue: 0.105, alpha: 1)
    )
    static let surface = adaptive(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.94),
        dark: UIColor(red: 0.085, green: 0.115, blue: 0.145, alpha: 0.96)
    )
    static let surfaceStrong = adaptive(
        light: UIColor(red: 0.89, green: 0.93, blue: 0.95, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.155, blue: 0.19, alpha: 1)
    )
    static let textPrimary = adaptive(
        light: UIColor(red: 0.04, green: 0.09, blue: 0.12, alpha: 1),
        dark: UIColor(red: 0.95, green: 0.98, blue: 1, alpha: 1)
    )
    static let textSecondary = adaptive(
        light: UIColor(red: 0.30, green: 0.37, blue: 0.41, alpha: 1),
        dark: UIColor(red: 0.64, green: 0.72, blue: 0.77, alpha: 1)
    )
    static let stroke = adaptive(
        light: UIColor(red: 0.78, green: 0.84, blue: 0.87, alpha: 0.8),
        dark: UIColor(red: 0.23, green: 0.30, blue: 0.35, alpha: 0.75)
    )

    static let accent = Color(red: 0.10, green: 0.78, blue: 0.69)
    static let accentStrong = Color(red: 0.03, green: 0.56, blue: 0.52)
    static let work = Color(red: 0.10, green: 0.78, blue: 0.69)
    static let recovery = Color(red: 0.45, green: 0.42, blue: 0.98)
    static let transition = Color(red: 1.00, green: 0.66, blue: 0.18)
    static let danger = Color(red: 0.96, green: 0.30, blue: 0.36)

    static let heroGradient = LinearGradient(
        colors: [accent, Color(red: 0.26, green: 0.55, blue: 0.98)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func phaseColor(_ kind: WorkoutPhaseKind) -> Color {
        switch kind {
        case .work:
            return work
        case .recovery, .roundRecovery:
            return recovery
        case .warmUp, .sideSwitch, .coolDown:
            return transition
        }
    }

    static func phaseIcon(_ kind: WorkoutPhaseKind) -> String {
        switch kind {
        case .warmUp:
            return "figure.walk.motion"
        case .work:
            return "bolt.fill"
        case .sideSwitch:
            return "arrow.left.arrow.right"
        case .recovery:
            return "wind"
        case .roundRecovery:
            return "arrow.triangle.2.circlepath"
        case .coolDown:
            return "heart.fill"
        }
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

typealias HiIntervalTheme = HITheme

extension AppearancePreference {
    @MainActor
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
