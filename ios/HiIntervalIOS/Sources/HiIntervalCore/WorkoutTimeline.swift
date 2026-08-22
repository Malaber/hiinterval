import Foundation

public struct WorkoutTimeline: Codable, Equatable, Sendable {
    public var planID: UUID
    public var planName: String
    public var phases: [WorkoutPhase]

    public init(planID: UUID, planName: String, phases: [WorkoutPhase]) {
        self.planID = planID
        self.planName = planName
        self.phases = phases
    }

    public init(plan: WorkoutPlan) throws {
        try plan.validate()
        var result: [WorkoutPhase] = []

        if plan.warmUpSeconds > 0 {
            result.append(
                WorkoutPhase(
                    kind: .warmUp,
                    title: "Get ready",
                    durationSeconds: plan.warmUpSeconds
                )
            )
        }

        for roundIndex in 1...plan.roundCount {
            let roundOverride = plan.roundOverrides.last { $0.roundNumber == roundIndex }
            for (stepOffset, exercise) in plan.exercises.enumerated() {
                let stepIndex = stepOffset + 1
                let workSeconds = roundOverride?.workSeconds
                    ?? exercise.resolvedWorkSeconds(default: plan.defaultWorkSeconds)
                let sideConfiguration = roundOverride?.sideConfiguration
                    ?? exercise.sideConfiguration
                let common = PhasePosition(
                    roundIndex: roundIndex,
                    roundCount: plan.roundCount,
                    exerciseIndex: stepIndex,
                    exerciseCount: plan.exercises.count
                )

                switch sideConfiguration.mode {
                case .together:
                    result.append(
                        WorkoutPhase(
                            kind: .work,
                            title: exercise.name,
                            durationSeconds: workSeconds,
                            position: common
                        )
                    )
                case .leftRight:
                    let firstDuration = (workSeconds + 1) / 2
                    let secondDuration = workSeconds / 2
                    let first = sideConfiguration.firstSide
                    result.append(
                        WorkoutPhase(
                            kind: .work,
                            title: exercise.name,
                            durationSeconds: firstDuration,
                            side: first,
                            position: common
                        )
                    )
                    if sideConfiguration.switchSeconds > 0 {
                        result.append(
                            WorkoutPhase(
                                kind: .sideSwitch,
                                title: "Switch sides",
                                durationSeconds: sideConfiguration.switchSeconds,
                                side: first.opposite,
                                position: common
                            )
                        )
                    }
                    result.append(
                        WorkoutPhase(
                            kind: .work,
                            title: exercise.name,
                            durationSeconds: secondDuration,
                            side: first.opposite,
                            position: common
                        )
                    )
                }

                let recoverySeconds = exercise.resolvedRecoverySeconds(
                    default: plan.defaultRecoverySeconds
                )
                if recoverySeconds > 0 {
                    result.append(
                        WorkoutPhase(
                            kind: .recovery,
                            title: "Recover",
                            durationSeconds: recoverySeconds,
                            position: common
                        )
                    )
                }
            }

            if roundIndex < plan.roundCount, plan.roundRecoverySeconds > 0 {
                result.append(
                    WorkoutPhase(
                        kind: .roundRecovery,
                        title: "Round recovery",
                        durationSeconds: plan.roundRecoverySeconds,
                        position: PhasePosition(
                            roundIndex: roundIndex,
                            roundCount: plan.roundCount,
                            exerciseIndex: plan.exercises.count,
                            exerciseCount: plan.exercises.count
                        )
                    )
                )
            }
        }

        if plan.coolDownSeconds > 0 {
            result.append(
                WorkoutPhase(
                    kind: .coolDown,
                    title: "Cool down",
                    durationSeconds: plan.coolDownSeconds,
                    position: PhasePosition(
                        roundIndex: plan.roundCount,
                        roundCount: plan.roundCount,
                        exerciseIndex: plan.exercises.count,
                        exerciseCount: plan.exercises.count
                    )
                )
            )
        }

        self.init(planID: plan.id, planName: plan.name, phases: result)
    }

    public var totalDurationSeconds: Int {
        phases.reduce(0) { $0 + $1.durationSeconds }
    }
}

public struct WorkoutPhase: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: WorkoutPhaseKind
    public var title: String
    public var durationSeconds: Int
    public var side: WorkoutSide?
    public var position: PhasePosition?

    public init(
        id: UUID = UUID(),
        kind: WorkoutPhaseKind,
        title: String,
        durationSeconds: Int,
        side: WorkoutSide? = nil,
        position: PhasePosition? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.durationSeconds = durationSeconds
        self.side = side
        self.position = position
    }
}

public enum WorkoutPhaseKind: String, Codable, CaseIterable, Equatable, Sendable {
    case warmUp
    case work
    case sideSwitch
    case recovery
    case roundRecovery
    case coolDown
}

public struct PhasePosition: Codable, Equatable, Sendable {
    public var roundIndex: Int
    public var roundCount: Int
    public var exerciseIndex: Int
    public var exerciseCount: Int

    public init(roundIndex: Int, roundCount: Int, exerciseIndex: Int, exerciseCount: Int) {
        self.roundIndex = roundIndex
        self.roundCount = roundCount
        self.exerciseIndex = exerciseIndex
        self.exerciseCount = exerciseCount
    }
}
