import Foundation
import SwiftUI
import HiIntervalCore

enum PlanPalette {
    static let accent = Color(red: 0.18, green: 0.76, blue: 0.67)
    static let secondary = Color(red: 0.46, green: 0.38, blue: 0.96)
    static let warning = Color(red: 0.96, green: 0.55, blue: 0.20)

    /// UUID-based rather than `hashValue`, so a workout retains its hue after renaming/relaunch.
    static func workoutTint(for id: UUID) -> Color {
        let colors: [Color] = [.teal, .blue, .orange, .pink, .green, .indigo, .cyan, .brown]
        let index = id.uuidString.utf8.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1) }
        return colors[Int(index % UInt64(colors.count))]
    }

    static func cardSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.07, green: 0.085, blue: 0.10)
            : Color.white
    }

    static func cardText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : Color.black
    }
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
    @Environment(\.colorScheme) private var colorScheme

    let icon: String
    let value: String
    let label: String
    var showsIcon = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if showsIcon {
                    Image(systemName: icon)
                        .accessibilityHidden(true)
                }
                Text(value)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PlanPalette.cardText(for: colorScheme))
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PlanPalette.cardText(for: colorScheme))
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

    @State private var isPresentingDurationEntry = false

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
            Button {
                isPresentingDurationEntry = true
            } label: {
                Text(PlanFormatting.compactDuration(seconds))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(seconds == 0 ? Color.secondary : PlanPalette.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(title) duration")
            .accessibilityValue("\(seconds) seconds")
            .accessibilityIdentifier("\(accessibilityID).value")

            Stepper(title, value: $seconds, in: range, step: step)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier(accessibilityID)
        }
        .sheet(isPresented: $isPresentingDurationEntry) {
            PlanDurationEntrySheet(
                title: title,
                seconds: $seconds,
                range: range,
                accessibilityID: accessibilityID
            )
        }
    }
}

private struct PlanDurationEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var seconds: Int
    @State private var draftSeconds: String
    @FocusState private var isDurationFieldFocused: Bool

    let title: String
    let range: ClosedRange<Int>
    let accessibilityID: String

    init(title: String, seconds: Binding<Int>, range: ClosedRange<Int>, accessibilityID: String) {
        self.title = title
        _seconds = seconds
        _draftSeconds = State(initialValue: String(seconds.wrappedValue))
        self.range = range
        self.accessibilityID = accessibilityID
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Seconds", text: $draftSeconds)
                        .keyboardType(.numberPad)
                        .focused($isDurationFieldFocused)
                        .accessibilityIdentifier("\(accessibilityID).entry.seconds")
                        .task {
                            // Request focus after the presented field joins its own view tree.
                            await Task.yield()
                            isDurationFieldFocused = true
                        }
                } header: {
                    Text("Duration")
                } footer: {
                    Text("Enter \(range.lowerBound)–\(range.upperBound) seconds.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("\(accessibilityID).entry.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard let enteredSeconds else { return }
                        seconds = enteredSeconds
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(enteredSeconds == nil)
                    .accessibilityIdentifier("\(accessibilityID).entry.done")
                }
            }
        }
        .tint(PlanPalette.accent)
        .accessibilityIdentifier("\(accessibilityID).entry.screen")
    }

    private var enteredSeconds: Int? {
        guard let value = Int(draftSeconds), range.contains(value) else { return nil }
        return value
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
