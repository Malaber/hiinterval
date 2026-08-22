import Foundation

/// Accumulates only time spent actively running, excluding every paused interval.
public struct ActiveDurationTracker: Equatable, Sendable {
    public private(set) var accumulatedSeconds: TimeInterval = 0
    private var runningSince: Date?

    public init() {}

    public var isRunning: Bool { runningSince != nil }

    public mutating func start(at date: Date) {
        guard runningSince == nil else { return }
        runningSince = date
    }

    public mutating func pause(at date: Date) {
        guard let runningSince else { return }
        accumulatedSeconds += max(0, date.timeIntervalSince(runningSince))
        self.runningSince = nil
    }

    public func elapsed(at date: Date) -> TimeInterval {
        guard let runningSince else { return accumulatedSeconds }
        return accumulatedSeconds + max(0, date.timeIntervalSince(runningSince))
    }
}
