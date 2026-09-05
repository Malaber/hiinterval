public enum HapticCueEvent: CaseIterable, Equatable, Sendable {
    case phase
    case countdown
    case pause
    case resume
    case completion
}

public enum HapticFeedback: Equatable, Sendable {
    case lightImpact
    case softImpact
    case mediumImpact
    case success
}

public enum HapticCuePolicy {
    public static func feedback(
        for event: HapticCueEvent,
        hapticsEnabled: Bool
    ) -> HapticFeedback? {
        guard hapticsEnabled else { return nil }
        switch event {
        case .phase:
            .mediumImpact
        case .countdown:
            .lightImpact
        case .pause, .resume:
            .softImpact
        case .completion:
            .success
        }
    }
}
