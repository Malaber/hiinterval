import Foundation

public struct ExerciseLabel: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case bodyArea
        case tag
    }

    public var id: UUID
    public var name: String
    public var kind: Kind

    public init(id: UUID = UUID(), name: String, kind: Kind) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    public func normalized() -> ExerciseLabel {
        var value = self
        value.name = Self.displayName(name)
        return value
    }

    public static func normalizedName(_ value: String) -> String {
        displayName(value).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    static func displayName(_ value: String) -> String {
        value.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
