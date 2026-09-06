import Foundation

public enum CompletionCelebrationStage: String, Equatable, Sendable {
    case foreground
    case background
}

public struct CompletionCelebrationTimeline: Equatable, Sendable {
    public let foregroundDurationSeconds: TimeInterval

    public init(foregroundDurationSeconds: TimeInterval = 5) {
        self.foregroundDurationSeconds = max(0, foregroundDurationSeconds)
    }

    public func stage(atElapsedSeconds elapsedSeconds: TimeInterval) -> CompletionCelebrationStage {
        elapsedSeconds < foregroundDurationSeconds ? .foreground : .background
    }
}
