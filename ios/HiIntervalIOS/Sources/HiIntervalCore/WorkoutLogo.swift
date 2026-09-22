import Foundation

/// Portable description of a workout's visual mark.
///
/// Photo bytes deliberately live outside persisted JSON. `photoFilename` is an opaque,
/// app-managed filename resolved by the iOS app when rendering the logo.
public struct WorkoutLogo: Codable, Equatable, Sendable {
    public var symbolName: String
    public var symbolColor: WorkoutLogoColor
    public var backgroundColor: WorkoutLogoColor
    public var photoFilename: String?

    public init(
        symbolName: String = "waveform.path.ecg",
        symbolColor: WorkoutLogoColor = .white,
        backgroundColor: WorkoutLogoColor = .defaultBackground,
        photoFilename: String? = nil
    ) {
        self.symbolName = symbolName
        self.symbolColor = symbolColor
        self.backgroundColor = backgroundColor
        self.photoFilename = photoFilename
    }

    public static let `default` = WorkoutLogo()

    public mutating func reset() {
        self = .default
    }
}

public struct WorkoutLogoColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var opacity: Double

    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.opacity = Self.clamp(opacity)
    }

    public static let white = WorkoutLogoColor(red: 1, green: 1, blue: 1)
    public static let defaultBackground = WorkoutLogoColor(red: 0.18, green: 0.76, blue: 0.67)

    private enum CodingKeys: String, CodingKey { case red, green, blue, opacity }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try values.decode(Double.self, forKey: .red),
            green: try values.decode(Double.self, forKey: .green),
            blue: try values.decode(Double.self, forKey: .blue),
            opacity: try values.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        )
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(red, forKey: .red)
        try values.encode(green, forKey: .green)
        try values.encode(blue, forKey: .blue)
        try values.encode(opacity, forKey: .opacity)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}
