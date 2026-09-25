import Foundation

/// Tracks the one spoken halfway cue for each exercise occurrence in a timeline.
///
/// An occurrence is identified by its round and exercise position. A left/right exercise is one
/// occurrence: its midpoint is calculated from both work phases and does not count its side switch.
public struct HalfwayExerciseCueTracker: Equatable, Sendable {
    private var announcedOccurrences: Set<Occurrence> = []

    public init() {}

    /// Returns the next halfway cue when the current timeline position has reached its active-work
    /// midpoint. Callers may defer calling this while another cue is playing; this does not consume
    /// the cue until one is returned.
    public mutating func nextCue(
        in timeline: WorkoutTimeline,
        currentPhaseIndex: Int,
        elapsedSeconds: TimeInterval
    ) -> HalfwayExerciseCue? {
        guard timeline.phases.indices.contains(currentPhaseIndex) else { return nil }
        let phase = timeline.phases[currentPhaseIndex]
        guard phase.kind == .work || phase.kind == .sideSwitch,
              let position = phase.position else { return nil }

        let occurrence = Occurrence(position: position)
        guard !announcedOccurrences.contains(occurrence),
              let midpoint = midpoint(for: occurrence, in: timeline),
              elapsedSeconds + Self.timeEpsilon >= midpoint.offsetSeconds else { return nil }

        announcedOccurrences.insert(occurrence)
        return HalfwayExerciseCue(
            exerciseName: midpoint.exerciseName,
            position: position,
            offsetSeconds: midpoint.offsetSeconds
        )
    }

    /// Skipped work is not active training time; suppress a misleading cue later in the split.
    public mutating func suppressCue(for position: PhasePosition?) {
        guard let position else { return }
        announcedOccurrences.insert(Occurrence(position: position))
    }

    private static let timeEpsilon: TimeInterval = 0.000_001

    private func midpoint(
        for occurrence: Occurrence,
        in timeline: WorkoutTimeline
    ) -> Midpoint? {
        let matchingIndices = timeline.phases.indices.filter {
            Occurrence(position: timeline.phases[$0].position) == occurrence
        }
        let workIndices = matchingIndices.filter { timeline.phases[$0].kind == .work }
        guard let firstWorkIndex = workIndices.first else { return nil }

        let totalActiveWork = workIndices.reduce(0) { partial, index in
            partial + timeline.phases[index].durationSeconds
        }
        guard totalActiveWork > 0 else { return nil }

        let halfwayActiveWork = Double(totalActiveWork) / 2
        var accumulatedActiveWork = 0.0
        let phaseOffsets = offsets(for: timeline)

        for index in workIndices {
            let phase = timeline.phases[index]
            let duration = Double(phase.durationSeconds)
            if accumulatedActiveWork + duration >= halfwayActiveWork {
                return Midpoint(
                    exerciseName: timeline.phases[firstWorkIndex].title,
                    offsetSeconds: phaseOffsets[index] + halfwayActiveWork - accumulatedActiveWork
                )
            }
            accumulatedActiveWork += duration
        }
        return nil
    }

    private func offsets(for timeline: WorkoutTimeline) -> [TimeInterval] {
        var total = 0.0
        return timeline.phases.map { phase in
            defer { total += Double(phase.durationSeconds) }
            return total
        }
    }

    private struct Occurrence: Hashable, Sendable {
        let roundIndex: Int
        let exerciseIndex: Int

        init(position: PhasePosition?) {
            roundIndex = position?.roundIndex ?? -1
            exerciseIndex = position?.exerciseIndex ?? -1
        }

        init(position: PhasePosition) {
            roundIndex = position.roundIndex
            exerciseIndex = position.exerciseIndex
        }
    }

    private struct Midpoint {
        let exerciseName: String
        let offsetSeconds: TimeInterval
    }
}

public struct HalfwayExerciseCue: Equatable, Sendable {
    public let exerciseName: String
    public let position: PhasePosition
    /// Absolute elapsed timeline time at which this occurrence reaches half active work.
    public let offsetSeconds: TimeInterval

    public init(exerciseName: String, position: PhasePosition, offsetSeconds: TimeInterval) {
        self.exerciseName = exerciseName
        self.position = position
        self.offsetSeconds = offsetSeconds
    }
}
