import Foundation

public struct IntervalTimerEngine: Equatable, Sendable {
    public private(set) var timeline: WorkoutTimeline
    public private(set) var state: TimerState
    public private(set) var currentPhaseIndex: Int
    public private(set) var remainingSeconds: TimeInterval
    private var anchorDate: Date?
    private var remainingAtAnchor: TimeInterval

    public init(timeline: WorkoutTimeline) {
        self.timeline = timeline
        state = .ready
        currentPhaseIndex = 0
        remainingSeconds = TimeInterval(timeline.phases.first?.durationSeconds ?? 0)
        remainingAtAnchor = remainingSeconds
    }

    public var currentPhase: WorkoutPhase? {
        guard timeline.phases.indices.contains(currentPhaseIndex), state != .finished else {
            return nil
        }
        return timeline.phases[currentPhaseIndex]
    }

    public var nextPhase: WorkoutPhase? {
        let index = currentPhaseIndex + 1
        return timeline.phases.indices.contains(index) ? timeline.phases[index] : nil
    }

    /// Next exercise the athlete needs to prepare for, skipping recovery and transition phases.
    /// Cool down remains useful as the final upcoming activity when no work phase remains.
    public var nextExercisePhase: WorkoutPhase? {
        let index = currentPhaseIndex + 1
        guard timeline.phases.indices.contains(index), state != .finished else { return nil }
        return timeline.phases[index...].first { phase in
            phase.kind == .work || phase.kind == .coolDown
        }
    }

    public var canReturnToPreviousExercise: Bool {
        guard state == .running || state == .paused, currentPhaseIndex > 0 else { return false }
        return timeline.phases[..<currentPhaseIndex].contains { $0.kind == .work }
    }

    public var displayedRemainingSeconds: Int {
        max(0, Int(ceil(remainingSeconds - 0.000_001)))
    }

    public var phaseProgress: Double {
        guard let currentPhase, currentPhase.durationSeconds > 0 else {
            return state == .finished ? 1 : 0
        }
        return min(1, max(0, 1 - remainingSeconds / Double(currentPhase.durationSeconds)))
    }

    public var totalElapsedSeconds: TimeInterval {
        if state == .finished { return TimeInterval(timeline.totalDurationSeconds) }
        let completed = timeline.phases.prefix(currentPhaseIndex).reduce(0) {
            $0 + $1.durationSeconds
        }
        guard let currentPhase else { return TimeInterval(completed) }
        return TimeInterval(completed) + Double(currentPhase.durationSeconds) - remainingSeconds
    }

    public var totalProgress: Double {
        guard timeline.totalDurationSeconds > 0 else { return 1 }
        return min(1, max(0, totalElapsedSeconds / Double(timeline.totalDurationSeconds)))
    }

    public mutating func start(at date: Date) -> [TimerEvent] {
        guard state == .ready else { return [] }
        guard !timeline.phases.isEmpty else {
            state = .finished
            remainingSeconds = 0
            return [.workoutCompleted]
        }
        state = .running
        anchorDate = date
        remainingAtAnchor = remainingSeconds
        return [.workoutStarted, .phaseStarted(timeline.phases[currentPhaseIndex])]
    }

    public mutating func tick(at date: Date) -> [TimerEvent] {
        guard state == .running, let anchorDate else { return [] }
        let elapsed = max(0, date.timeIntervalSince(anchorDate))
        var remainder = remainingAtAnchor - elapsed
        var events: [TimerEvent] = []
        var crossedPhaseBoundary = false

        while remainder <= 0, state == .running {
            let overflow = -remainder
            if currentPhaseIndex + 1 >= timeline.phases.count {
                state = .finished
                self.anchorDate = nil
                remainingAtAnchor = 0
                remainingSeconds = 0
                events.append(.workoutCompleted)
                break
            }
            currentPhaseIndex += 1
            let phase = timeline.phases[currentPhaseIndex]
            remainder = Double(phase.durationSeconds) - overflow
            events.append(.phaseStarted(phase))
            crossedPhaseBoundary = true
        }

        if state == .running {
            remainingSeconds = max(0, remainder)
            if crossedPhaseBoundary {
                self.anchorDate = date
                remainingAtAnchor = remainingSeconds
            }
        }
        return events
    }

    public mutating func pause(at date: Date) -> [TimerEvent] {
        guard state == .running else { return [] }
        var events = tick(at: date)
        guard state == .running else { return events }
        state = .paused
        anchorDate = nil
        remainingAtAnchor = remainingSeconds
        events.append(.paused)
        return events
    }

    public mutating func resume(at date: Date) -> [TimerEvent] {
        guard state == .paused else { return [] }
        state = .running
        anchorDate = date
        remainingAtAnchor = remainingSeconds
        return [.resumed]
    }

    public mutating func skip(at date: Date) -> [TimerEvent] {
        guard state == .running || state == .paused else { return [] }
        if state == .running {
            _ = tick(at: date)
            guard state == .running else { return [.workoutCompleted] }
        }
        guard currentPhaseIndex + 1 < timeline.phases.count else {
            state = .finished
            anchorDate = nil
            remainingAtAnchor = 0
            remainingSeconds = 0
            return [.workoutCompleted]
        }
        currentPhaseIndex += 1
        let phase = timeline.phases[currentPhaseIndex]
        remainingSeconds = Double(phase.durationSeconds)
        remainingAtAnchor = remainingSeconds
        if state == .running { anchorDate = date }
        return [.phaseStarted(phase)]
    }

    public mutating func restartPhase(at date: Date) -> [TimerEvent] {
        guard state == .running || state == .paused else { return [] }
        var events: [TimerEvent] = []
        if state == .running {
            events = tick(at: date)
            guard state == .running else { return events }
        }
        guard let currentPhase else { return events }
        remainingSeconds = Double(currentPhase.durationSeconds)
        remainingAtAnchor = remainingSeconds
        if state == .running { anchorDate = date }
        events.append(.phaseRestarted(currentPhase))
        return events
    }

    /// Returns to the most recent work phase and restores its full duration.
    /// Recovery and side-switch phases are intentionally skipped because this action repairs an
    /// accidentally skipped exercise rather than navigating the expanded phase timeline.
    public mutating func returnToPreviousExercise(at date: Date) -> [TimerEvent] {
        guard state == .running || state == .paused else { return [] }
        var events: [TimerEvent] = []
        if state == .running {
            events = tick(at: date)
            guard state == .running else { return events }
        }
        guard currentPhaseIndex > 0,
              let previousIndex = timeline.phases[..<currentPhaseIndex].lastIndex(where: {
                  $0.kind == .work
              }) else {
            return events
        }

        currentPhaseIndex = previousIndex
        let previousPhase = timeline.phases[previousIndex]
        remainingSeconds = Double(previousPhase.durationSeconds)
        remainingAtAnchor = remainingSeconds
        if state == .running { anchorDate = date }
        events.append(.phaseStarted(previousPhase))
        return events
    }
}

public enum TimerState: String, Codable, Equatable, Sendable {
    case ready
    case running
    case paused
    case finished
}

public enum TimerEvent: Equatable, Sendable {
    case workoutStarted
    case phaseStarted(WorkoutPhase)
    case phaseRestarted(WorkoutPhase)
    case paused
    case resumed
    case workoutCompleted
}
