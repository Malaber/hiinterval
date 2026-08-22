import Combine
import HiIntervalCore
import SwiftUI
import UIKit

struct WorkoutSessionFlow: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: WorkoutSessionController
    @State private var didPersistCompletion = false

    init(plan: WorkoutPlan) {
        _controller = StateObject(wrappedValue: WorkoutSessionController(plan: plan))
    }

    var body: some View {
        Group {
            if let completion = controller.completion {
                WorkoutCompletionView(entry: completion) {
                    dismiss()
                }
            } else {
                ActiveWorkoutView(controller: controller)
            }
        }
        .environmentObject(store)
        .onChange(of: controller.completion) { _, completion in
            guard let completion, !didPersistCompletion else { return }
            didPersistCompletion = true
            store.addHistory(completion)
        }
    }
}

private struct ActiveWorkoutView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var controller: WorkoutSessionController
    @State private var confirmExit = false
    @State private var timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var phase: WorkoutPhase? { controller.engine.currentPhase }
    private var phaseColor: Color { PhaseStyle.color(for: phase?.kind) }

    var body: some View {
        ZStack(alignment: .leading) {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            Rectangle()
                .fill(phaseColor)
                .frame(width: 5)
                .ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        phaseRibbon
                        Spacer(minLength: 24)
                        timerBody
                        Spacer(minLength: 24)
                        controls
                    }
                    .frame(minHeight: max(0, geometry.size.height - 32))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .overlay {
            if controller.engine.state == .paused {
                pausedBadge
            }
        }
        .onAppear {
            timer = Timer.publish(every: controller.tickInterval, on: .main, in: .common).autoconnect()
            controller.start(preferences: store.data.preferences)
            if store.data.preferences.keepScreenAwake {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(timer) { _ in
            controller.tick(preferences: store.data.preferences)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                controller.pauseForBackground(preferences: store.data.preferences)
            }
        }
        .confirmationDialog("End this workout?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("End workout", role: .destructive) { dismiss() }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("Current progress will not be added to history.")
        }
        .accessibilityIdentifier("session.screen")
    }

    private var header: some View {
        HStack {
            Button {
                confirmExit = true
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
            .accessibilityLabel("End workout")
            .accessibilityIdentifier("session.close")

            Spacer()
            VStack(spacing: 2) {
                Text(controller.plan.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(Int(controller.engine.totalProgress * 100))% complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()

            Button {
                controller.toggleMute()
            } label: {
                Image(systemName: controller.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
            .accessibilityLabel(controller.isMuted ? "Unmute cues" : "Mute cues")
            .accessibilityIdentifier("session.mute")
        }
    }

    private var phaseRibbon: some View {
        HStack(spacing: 6) {
            ForEach(ribbonPhases, id: \.id) { item in
                Capsule()
                    .fill(item.id == phase?.id ? phaseColor : Color.secondary.opacity(0.18))
                    .frame(height: item.id == phase?.id ? 8 : 5)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private var ribbonPhases: [WorkoutPhase] {
        let phases = controller.engine.timeline.phases
        guard !phases.isEmpty else { return [] }
        let start = max(0, controller.engine.currentPhaseIndex - 2)
        let end = min(phases.count, controller.engine.currentPhaseIndex + 5)
        return Array(phases[start..<end])
    }

    private var timerBody: some View {
        VStack(spacing: 18) {
            Label(PhaseStyle.label(for: phase?.kind), systemImage: PhaseStyle.icon(for: phase?.kind))
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(phaseColor)
                .accessibilityIdentifier("session.phase-kind")

            Text(phase?.title ?? "Complete")
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("session.exercise")

            if let side = phase?.side {
                Text(side == .left ? "LEFT SIDE" : "RIGHT SIDE")
                    .font(.subheadline.weight(.bold))
                    .tracking(1.2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(phaseColor.opacity(0.13), in: Capsule())
                    .accessibilityIdentifier("session.side")
            }

            Text(SessionFormat.duration(controller.engine.displayedRemainingSeconds))
                .font(.system(size: 92, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .accessibilityLabel(timerAccessibilityLabel)
                .accessibilityIdentifier("session.remaining")

            ProgressView(value: controller.engine.phaseProgress)
                .tint(phaseColor)
                .scaleEffect(y: 2)
                .accessibilityLabel("Phase progress")
                .accessibilityValue("\(Int(controller.engine.phaseProgress * 100)) percent")

            HStack(spacing: 6) {
                Image(systemName: "stopwatch")
                Text("\(SessionFormat.duration(totalRemainingSeconds)) remaining")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(totalRemainingSeconds) seconds remaining in workout")
            .accessibilityIdentifier("session.total-remaining")

            HStack {
                if let position = phase?.position {
                    Label(
                        "Exercise \(position.exerciseIndex) of \(position.exerciseCount)",
                        systemImage: "figure.strengthtraining.traditional"
                    )
                    Spacer()
                    Label(
                        "Round \(position.roundIndex) of \(position.roundCount)",
                        systemImage: "repeat"
                    )
                } else {
                    Label("Preparing session", systemImage: "hourglass")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let next = controller.engine.nextPhase {
                HStack(spacing: 8) {
                    Text("NEXT")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                    Text(next.title + sideSuffix(next.side))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("session.next")
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            controlButton(
                icon: "arrow.counterclockwise",
                label: "Restart phase",
                identifier: "session.restart"
            ) {
                controller.restart(preferences: store.data.preferences)
            }

            Button {
                controller.togglePause(preferences: store.data.preferences)
            } label: {
                Image(systemName: controller.engine.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(width: 82, height: 82)
                    .background(phaseColor, in: Circle())
                    .shadow(color: phaseColor.opacity(0.3), radius: 18, y: 8)
            }
            .accessibilityLabel(controller.engine.state == .paused ? "Resume workout" : "Pause workout")
            .accessibilityIdentifier("session.pause")

            controlButton(
                icon: "forward.end.fill",
                label: "Skip phase",
                identifier: "session.skip"
            ) {
                controller.skip(preferences: store.data.preferences)
            }
        }
        .padding(.bottom, 10)
    }

    private func controlButton(
        icon: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .frame(width: 58, height: 58)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var pausedBadge: some View {
        VStack(spacing: 10) {
            Image(systemName: "pause.fill")
                .font(.title2)
            Text("PAUSED")
                .font(.headline)
                .tracking(1.2)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("session.paused")
    }

    private var timerAccessibilityLabel: String {
        let remaining = controller.engine.displayedRemainingSeconds
        let kind = PhaseStyle.label(for: phase?.kind)
        let side = phase?.side.map { $0 == .left ? "left side" : "right side" } ?? ""
        return "\(remaining) seconds remaining, \(kind), \(side)"
    }

    private var totalRemainingSeconds: Int {
        max(
            0,
            Int(ceil(
                Double(controller.engine.timeline.totalDurationSeconds)
                    - controller.engine.totalElapsedSeconds
            ))
        )
    }

    private func sideSuffix(_ side: WorkoutSide?) -> String {
        guard let side else { return "" }
        return side == .left ? " · Left" : " · Right"
    }
}

private enum PhaseStyle {
    static func color(for kind: WorkoutPhaseKind?) -> Color {
        switch kind {
        case .work: return Color(red: 0.16, green: 0.72, blue: 0.65)
        case .recovery: return Color(red: 0.52, green: 0.47, blue: 0.95)
        case .roundRecovery: return Color(red: 0.94, green: 0.62, blue: 0.18)
        case .warmUp, .sideSwitch: return Color(red: 0.25, green: 0.58, blue: 0.91)
        case .coolDown: return Color(red: 0.24, green: 0.75, blue: 0.48)
        case nil: return .accentColor
        }
    }

    static func label(for kind: WorkoutPhaseKind?) -> String {
        switch kind {
        case .warmUp: return "WARM UP"
        case .work: return "WORK"
        case .sideSwitch: return "SWITCH"
        case .recovery: return "RECOVER"
        case .roundRecovery: return "ROUND RECOVERY"
        case .coolDown: return "COOL DOWN"
        case nil: return "SESSION"
        }
    }

    static func icon(for kind: WorkoutPhaseKind?) -> String {
        switch kind {
        case .warmUp: return "flame"
        case .work: return "bolt.fill"
        case .sideSwitch: return "arrow.left.arrow.right"
        case .recovery: return "wind"
        case .roundRecovery: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .coolDown: return "leaf.fill"
        case nil: return "timer"
        }
    }
}

private struct WorkoutCompletionView: View {
    let entry: WorkoutHistoryEntry
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 36)
                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(width: 104, height: 104)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 30))
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Session complete")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(entry.planName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    completionMetric("Duration", SessionFormat.duration(entry.elapsedDurationSeconds), "stopwatch")
                    completionMetric("Rounds", "\(entry.roundCount)", "repeat")
                    completionMetric("Moves", "\(entry.exerciseCount)", "figure.run")
                }

                Text("Workout saved to History.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(action: done) {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("completion.done")
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .accessibilityIdentifier("completion.screen")
    }

    private func completionMetric(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
