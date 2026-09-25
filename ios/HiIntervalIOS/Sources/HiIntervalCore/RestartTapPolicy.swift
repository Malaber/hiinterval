import Foundation

/// Interprets consecutive restart taps using a monotonic time source supplied by the caller.
/// The first tap always restarts the current phase immediately. A second tap inside the
/// window returns to the previous exercise, when one exists.
public struct RestartTapPolicy: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case restart
        case previous
    }

    public static let windowDuration: TimeInterval = 0.45

    private var firstTapTime: TimeInterval?

    public init() {}

    public mutating func tap(at time: TimeInterval, canGoBack: Bool) -> Action {
        if canGoBack, isArmed(at: time) {
            reset()
            return .previous
        }

        firstTapTime = canGoBack ? time : nil
        return .restart
    }

    public func isArmed(at time: TimeInterval) -> Bool {
        guard let firstTapTime else { return false }
        return time >= firstTapTime && time <= firstTapTime + Self.windowDuration
    }

    public mutating func reset() {
        firstTapTime = nil
    }
}
