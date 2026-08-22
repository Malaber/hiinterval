import Foundation
import SwiftUI
import HiIntervalCore

enum PlanPalette {
    static let accent = Color(red: 0.18, green: 0.76, blue: 0.67)
    static let secondary = Color(red: 0.46, green: 0.38, blue: 0.96)
    static let warning = Color(red: 0.96, green: 0.55, blue: 0.20)
}

enum PlanFormatting {
    static func duration(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let hours = clampedSeconds / 3_600
        let minutes = (clampedSeconds % 3_600) / 60
        let remainingSeconds = clampedSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    static func compactDuration(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        if clampedSeconds == 0 { return "Off" }
        if clampedSeconds < 60 { return "\(clampedSeconds)s" }

        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60
        if remainingSeconds == 0 { return "\(minutes)m" }
        return "\(minutes)m \(remainingSeconds)s"
    }

    static func totalDuration(for plan: WorkoutPlan) -> Int? {
        guard validationMessage(for: plan) == nil else { return nil }
        return try? WorkoutTimeline(plan: plan).totalDurationSeconds
    }

    static func validationMessage(for plan: WorkoutPlan) -> String? {
        do {
            try plan.validate()
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        for roundOverride in plan.roundOverrides where roundOverride.sideConfiguration?.mode == .leftRight {
            let containsTooShortExercise = plan.exercises.contains { exercise in
                let workSeconds = roundOverride.workSeconds
                    ?? exercise.resolvedWorkSeconds(default: plan.defaultWorkSeconds)
                return workSeconds < 2
            }
            if containsTooShortExercise {
                return "Round \(roundOverride.roundNumber) needs at least two seconds per exercise for left/right mode."
            }
        }
        return nil
    }

    static func sideLabel(_ side: WorkoutSide) -> String {
        switch side {
        case .left: "Left"
        case .right: "Right"
        }
    }
}

struct PlanMetric: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(value, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

struct PlanDurationStepper: View {
    let title: String
    let subtitle: String?
    @Binding var seconds: Int
    var range: ClosedRange<Int> = 0...3_600
    var step: Int = 5
    var accessibilityID: String

    init(
        _ title: String,
        subtitle: String? = nil,
        seconds: Binding<Int>,
        range: ClosedRange<Int> = 0...3_600,
        step: Int = 5,
        accessibilityID: String
    ) {
        self.title = title
        self.subtitle = subtitle
        _seconds = seconds
        self.range = range
        self.step = step
        self.accessibilityID = accessibilityID
    }

    var body: some View {
        Stepper(value: $seconds, in: range, step: step) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(PlanFormatting.compactDuration(seconds))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(seconds == 0 ? Color.secondary : PlanPalette.accent)
            }
        }
        .accessibilityIdentifier(accessibilityID)
    }
}

struct ValidationBanner: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .font(.footnote)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(PlanPalette.warning)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PlanPalette.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("plan.validation.error")
    }
}
