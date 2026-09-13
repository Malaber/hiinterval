import Foundation

public struct OneMoreRoundRecovery: Equatable, Sendable {
    public var minimumSeconds: Int

    public init(minimumSeconds: Int = 10) {
        self.minimumSeconds = max(0, minimumSeconds)
    }

    public func remainingSeconds(
        configuredSeconds: Int,
        elapsedSeconds: TimeInterval
    ) -> Int {
        let elapsed = Int(max(0, elapsedSeconds).rounded(.down))
        return max(minimumSeconds, max(0, configuredSeconds) - elapsed)
    }
}

public extension WorkoutTimeline {
    /// Builds a continuation containing round recovery followed by one complete exercise round.
    /// Warm-up and cool-down are omitted because both already ran in the completed workout.
    static func oneMoreRound(
        for plan: WorkoutPlan,
        recoverySeconds: Int,
        roundNumber: Int
    ) throws -> WorkoutTimeline {
        try plan.validate()

        let resolvedRoundNumber = max(plan.roundCount + 1, roundNumber)
        var singleRoundPlan = plan
        singleRoundPlan.warmUpSeconds = 0
        singleRoundPlan.warmUpNotes = nil
        singleRoundPlan.roundCount = 1
        singleRoundPlan.roundRecoverySeconds = 0
        singleRoundPlan.coolDownSeconds = 0
        singleRoundPlan.coolDownNotes = nil
        singleRoundPlan.roundOverrides = []

        var phases = try WorkoutTimeline(plan: singleRoundPlan).phases
        for index in phases.indices {
            guard var position = phases[index].position else { continue }
            position.roundIndex = resolvedRoundNumber
            position.roundCount = resolvedRoundNumber
            phases[index].position = position
        }

        phases.insert(
            WorkoutPhase(
                kind: .roundRecovery,
                title: "Round recovery",
                durationSeconds: max(0, recoverySeconds),
                notes: visibleOneMoreRoundNotes(plan.roundRecoveryNotes),
                position: PhasePosition(
                    roundIndex: resolvedRoundNumber,
                    roundCount: resolvedRoundNumber,
                    exerciseIndex: plan.exercises.count,
                    exerciseCount: plan.exercises.count
                )
            ),
            at: 0
        )

        return WorkoutTimeline(planID: plan.id, planName: plan.name, phases: phases)
    }
}

private func visibleOneMoreRoundNotes(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
