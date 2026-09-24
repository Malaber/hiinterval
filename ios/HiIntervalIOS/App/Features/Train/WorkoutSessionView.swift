import Combine
import HiIntervalCore
import SwiftUI
import UIKit

struct WorkoutSessionFlow: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: WorkoutSessionController

    init(plan: WorkoutPlan) {
        _controller = StateObject(wrappedValue: WorkoutSessionController(plan: plan))
    }

    var body: some View {
        Group {
            if let completion = controller.completion {
                WorkoutCompletionView(
                    entry: completion,
                    didExceedPlan: controller.didExceedPlan,
                    oneMoreRound: {
                        controller.startOneMoreRound(preferences: store.data.preferences)
                    },
                    done: { dismiss() }
                )
            } else {
                ActiveWorkoutView(controller: controller)
            }
        }
        .environmentObject(store)
        .onChange(of: controller.completion) { _, completion in
            guard let completion else { return }
            store.addHistory(completion)
        }
    }
}

/// Native button tracking gives immediate pressed feedback without competing tap gestures.
private struct SessionControlStyle: ViewModifier {
    let foreground: Color
    var prominent = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent).tint(foreground)
                    .buttonBorderShape(.circle)
            } else {
                content.buttonStyle(.glass).tint(foreground)
                    .buttonBorderShape(.circle)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent).tint(foreground)
                    .buttonBorderShape(.circle)
            } else {
                content.buttonStyle(.bordered).tint(foreground)
                    .buttonBorderShape(.circle)
            }
        }
    }
}

private struct ActiveWorkoutView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var controller: WorkoutSessionController
    @State private var confirmExit = false
    @State private var contentHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var notesLineHeight: CGFloat = 22
    @State private var timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var phase: WorkoutPhase? { controller.engine.currentPhase }
    private var workoutTheme: WorkoutTheme { store.data.preferences.workoutTheme }
    private var phaseColor: Color {
        guard let kind = phase?.kind else { return Color.accentColor }
        return HITheme.phaseColor(kind, in: workoutTheme)
    }
    private var usesDarkForeground: Bool {
        guard let kind = phase?.kind else { return true }
        let color: WorkoutLogoColor
        switch kind {
        case .work:
            color = workoutTheme.workColor
        case .recovery, .roundRecovery:
            color = workoutTheme.recoveryColor
        case .warmUp, .sideSwitch, .coolDown:
            color = workoutTheme.transitionColor
        }
        return workoutTheme.prefersDarkText(for: color)
    }
    private var sessionForeground: Color {
        usesDarkForeground ? Color.black : Color.white
    }
    private var sessionSecondary: Color {
        sessionForeground
    }
    private var controlSurface: Color {
        sessionForeground.opacity(0.12)
    }
    private let headingHierarchy = SessionHeadingHierarchy()

    var body: some View {
        ZStack {
            phaseColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: phase?.kind)
                .accessibilityHidden(true)

            GeometryReader { geometry in
                ScrollView {
                    sessionContent(
                        compact: geometry.size.height < 850,
                        availableHeight: geometry.size.height
                    )
                        .background {
                            GeometryReader { content in
                                Color.clear.preference(key: SessionContentHeightKey.self, value: content.size.height)
                            }
                        }
                }
                .scrollDisabled(contentHeight <= geometry.size.height + 1)
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .onPreferenceChange(SessionContentHeightKey.self) { contentHeight = $0 }
                .accessibilityIdentifier("session.screen")
                .accessibilityValue(contentHeight <= geometry.size.height + 1 ? "Fits screen" : "Scrollable content")
            }
        }
        .foregroundStyle(sessionForeground)
        .preferredColorScheme(.light)
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
    }

    private func sessionContent(compact: Bool, availableHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: compact ? 16 : 32)
            phaseRibbon
                .padding(.bottom, compact ? 10 : 18)
            timerBody(compact: compact)
                .overlay {
                    if controller.engine.state == .paused {
                        Text("PAUSED")
                            .font(.system(.title, design: .rounded, weight: .black))
                            .tracking(2)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 16)
                            .foregroundStyle(phaseColor)
                            .background(sessionForeground, in: Capsule())
                            .overlay { Capsule().stroke(phaseColor.opacity(0.6), lineWidth: 2) }
                            .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("session.paused")
                    }
                }
            Spacer(minLength: compact ? 16 : 32)
            controls
        }
        .padding(.horizontal, compact ? 18 : 24)
        .padding(.vertical, compact ? 8 : 16)
        .frame(maxWidth: .infinity)
        .frame(minHeight: availableHeight)
    }

    private var header: some View {
        HStack {
            Button {
                confirmExit = true
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .modifier(SessionControlStyle(foreground: sessionForeground))
            .accessibilityLabel("End workout")
            .accessibilityIdentifier("session.close")

            Spacer()
            VStack(spacing: 2) {
                Text(controller.plan.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(Int(controller.engine.totalProgress * 100))% complete")
                    .font(.caption)
                    .foregroundStyle(sessionSecondary)
                    .monospacedDigit()
            }
            Spacer()

            Button {
                controller.toggleMute()
            } label: {
                Image(systemName: controller.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 44, height: 44)
            }
            .modifier(SessionControlStyle(foreground: sessionForeground))
            .accessibilityLabel(controller.isMuted ? "Unmute cues" : "Mute cues")
            .accessibilityIdentifier("session.mute")
        }
    }

    private var phaseRibbon: some View {
        HStack(spacing: 6) {
            ForEach(0..<controller.plan.exercises.count, id: \.self) { offset in
                let isCurrent = offset + 1 == currentExerciseIndex
                Capsule()
                    .fill(isCurrent ? sessionForeground : sessionForeground.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: isCurrent ? 8 : 6)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PhaseStyle.label(for: phase?.kind))
        .accessibilityValue(store.data.preferences.hapticsEnabled ? "Haptics enabled" : "Haptics disabled")
        .accessibilityIdentifier("session.phase-kind")
    }

    private var currentHeading: String {
        switch phase?.kind {
        case .recovery: return "Recovery"
        case .roundRecovery: return "Round recovery"
        default: return (phase?.title ?? "Complete") + sideSuffix(phase?.side)
        }
    }

    private func timerBody(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 18) {
            stableTitle(
                currentHeading,
                size: compact ? 34 : CGFloat(headingHierarchy.currentNamePointSize),
                weight: .heavy,
                minimumScale: 0.62
            )
                .accessibilityLabel(currentHeading)
                .accessibilityIdentifier("session.exercise")
                .accessibilityValue("Primary focus")

            if sessionHasNotes {
                ScrollView {
                    if let notes = phase?.notes {
                        notesCard(notes, compact: compact)
                    }
                }
                .frame(height: notesLineHeight * 3 + (compact ? 16 : 24))
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityHidden(phase?.notes == nil)
            }

            Text(SessionFormat.duration(controller.engine.displayedRemainingSeconds))
                .font(.system(size: compact ? 70 : 92, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .accessibilityLabel(timerAccessibilityLabel)
                .accessibilityIdentifier("session.remaining")

            ProgressView(value: controller.engine.phaseProgress)
                .tint(sessionForeground)
                .background(sessionForeground.opacity(0.18), in: Capsule())
                .scaleEffect(y: 2)
                .accessibilityHidden(true)

            HStack(spacing: 6) {
                Image(systemName: "stopwatch")
                Text("\(SessionFormat.duration(totalRemainingSeconds)) remaining")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(sessionSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(totalRemainingSeconds) seconds remaining in workout")
            .accessibilityIdentifier("session.total-remaining")

            HStack {
                if let position = phase?.position {
                    Label(
                        "Exercise \(position.exerciseIndex) of \(position.exerciseCount)",
                        systemImage: "figure.strengthtraining.traditional"
                    )
                    .accessibilityIdentifier("session.exercise-progress")
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
            .foregroundStyle(sessionSecondary)

            if let next = controller.engine.nextExercisePhase {
                nextPreview(next.title + sideSuffix(next.side), compact: compact)
            } else {
                nextPreview("Next exercise", compact: compact)
                    .hidden()
                    .accessibilityHidden(true)
            }
        }
    }

    private var sessionHasNotes: Bool {
        let plan = controller.plan
        return [plan.warmUpNotes, plan.recoveryNotes, plan.coolDownNotes, plan.roundRecoveryNotes]
            .contains { !($0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
            || plan.exercises.contains { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Measure an unscaled two-line slot so shorter or scaled names cannot shift other views.
    private func stableTitle(
        _ title: String, size: CGFloat, weight: Font.Weight, minimumScale: CGFloat
    ) -> some View {
        Text("Ag\nAg")
            .font(.system(size: size, weight: weight, design: .rounded))
            .hidden()
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity)
            .overlay {
                Text(title)
                    .font(.system(size: size, weight: weight, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(minimumScale)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityHidden(false)
            .accessibilityLabel(title)
    }

    private func notesCard(_ notes: String, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .accessibilityHidden(true)
            Text(notes)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(sessionForeground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, compact ? 8 : 12)
        .background(controlSurface, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Notes, \(notes)")
        .accessibilityIdentifier("session.notes")
    }

    private func nextPreview(_ title: String, compact: Bool) -> some View {
        VStack(spacing: 6) {
            Label("NEXT UP", systemImage: "forward.fill")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(sessionForeground)
            stableTitle(
                title,
                size: CGFloat(headingHierarchy.nextNamePointSize),
                weight: .semibold,
                minimumScale: 0.75
            )
        }
        .foregroundStyle(sessionForeground)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, compact ? 6 : 12)
        .background(
            Color.black.opacity(headingHierarchy.nextSurfaceOpacity),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(sessionForeground.opacity(headingHierarchy.nextStrokeOpacity), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next up, \(title)")
        .accessibilityValue("Secondary preview")
        .accessibilityIdentifier("session.next")
    }

    private var controls: some View {
        HStack(spacing: 28) {
            restartControl

            Button {
                controller.togglePause(preferences: store.data.preferences)
            } label: {
                Image(systemName: controller.engine.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(phaseColor)
                    .frame(width: 82, height: 82)
            }
            .modifier(SessionControlStyle(foreground: sessionForeground, prominent: true))
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

    private var restartControl: some View {
        Button {
            controller.restartTapped(preferences: store.data.preferences)
        } label: {
            Image(systemName: controller.isPreviousTapArmed ? "arrow.backward" : "arrow.counterclockwise")
                .font(.title3.weight(.semibold))
                .frame(width: 58, height: 58)
                .contentShape(Circle())
        }
        .modifier(SessionControlStyle(foreground: sessionForeground))
        .accessibilityLabel(controller.isPreviousTapArmed ? "Previous exercise" : "Restart phase")
        .accessibilityValue(controller.isPreviousTapArmed ? "Back available" : "Restart available")
        .accessibilityHint(
            controller.engine.canReturnToPreviousExercise
                ? "Restarts this phase. Use the Previous exercise action to go back with VoiceOver."
                : "Restarts this phase."
        )
        .accessibilityIdentifier("session.restart")
        .accessibilityActions {
            if controller.engine.canReturnToPreviousExercise {
                Button("Previous exercise") {
                    controller.returnToPreviousExercise(preferences: store.data.preferences)
                }
            }
        }
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
        }
        .modifier(SessionControlStyle(foreground: sessionForeground))
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var currentExerciseIndex: Int? {
        phase?.position?.exerciseIndex
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
    let didExceedPlan: Bool
    let oneMoreRound: () -> Void
    let done: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrationStage: CompletionCelebrationStage = .foreground

    private var celebrationTimeline: CompletionCelebrationTimeline {
        let process = ProcessInfo.processInfo
        guard process.arguments.contains("--ui-testing"),
              let rawDuration = process.environment["HIINTERVAL_UI_TEST_CELEBRATION_DURATION"],
              let duration = TimeInterval(rawDuration) else {
            return CompletionCelebrationTimeline()
        }
        return CompletionCelebrationTimeline(foregroundDurationSeconds: duration)
    }
    private let usesManualCelebrationClock = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        && ProcessInfo.processInfo.environment["HIINTERVAL_UI_TEST_MANUAL_CELEBRATION"] == "1"

    var body: some View {
        ZStack {
            if celebrationStage == .background {
                CompletionFireworksView(
                    prominence: .background,
                    isAnimationPaused: usesManualCelebrationClock
                )
                    .transition(.opacity)
            }

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
                        Text(didExceedPlan ? "Above and beyond" : "Session complete")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .accessibilityValue(
                                celebrationStage == .foreground
                                    ? "Foreground fireworks"
                                    : "Background fireworks"
                            )
                            .accessibilityIdentifier("completion.screen")
                        Text(entry.planName)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    if usesManualCelebrationClock {
                        Button("Advance fireworks", action: advanceCelebration)
                            .accessibilityIdentifier("completion.advance-fireworks")
                    }

                    HStack(spacing: 12) {
                        completionMetric("Duration", SessionFormat.duration(entry.elapsedDurationSeconds), "stopwatch")
                        completionMetric("Rounds", "\(entry.roundCount)", "repeat")
                        completionMetric("Moves", "\(entry.exerciseCount)", "figure.run")
                    }

                    Text("Workout saved to History.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        Text(
                            didExceedPlan
                                ? "You did more than planned. Extra round complete!"
                                : "Still feeling strong? Your round recovery is already ticking."
                        )
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(
                            didExceedPlan ? "completion.extra-congratulation" : "completion.extra-nudge"
                        )

                        Button(action: oneMoreRound) {
                            Label("One More Round", systemImage: "repeat.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityHint("Starts with at least 10 seconds of round recovery")
                        .accessibilityIdentifier("completion.one-more-round")
                    }

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

            if celebrationStage == .foreground {
                CompletionFireworksView(
                    prominence: .foreground,
                    isAnimationPaused: usesManualCelebrationClock
                )
                    .transition(.opacity)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            guard celebrationStage == .foreground else { return }
            guard !usesManualCelebrationClock else { return }
            try? await Task.sleep(for: .seconds(celebrationTimeline.foregroundDurationSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                advanceCelebration()
            }
        }
    }

    private func advanceCelebration() {
        celebrationStage = celebrationTimeline.stage(
            atElapsedSeconds: celebrationTimeline.foregroundDurationSeconds
        )
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

private struct CompletionFireworksView: View {
    enum Prominence {
        case foreground
        case background
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let prominence: Prominence
    let isAnimationPaused: Bool

    private let colors: [Color] = [.yellow, .orange, .pink, HITheme.accent, .blue]
    private let centers: [UnitPoint] = [
        UnitPoint(x: 0.18, y: 0.22),
        UnitPoint(x: 0.78, y: 0.18),
        UnitPoint(x: 0.52, y: 0.42),
        UnitPoint(x: 0.24, y: 0.68),
        UnitPoint(x: 0.82, y: 0.64),
    ]

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: reduceMotion || isAnimationPaused
            )
        ) { timeline in
            Canvas { context, size in
                for (burstIndex, center) in centers.enumerated() {
                    drawBurst(
                        in: &context,
                        size: size,
                        center: center,
                        burstIndex: burstIndex,
                        date: timeline.date
                    )
                }
            }
        }
        .opacity(prominence == .foreground ? 0.95 : 0.32)
        .scaleEffect(prominence == .foreground ? 1.08 : 0.82)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawBurst(
        in context: inout GraphicsContext,
        size: CGSize,
        center: UnitPoint,
        burstIndex: Int,
        date: Date
    ) {
        let rawPhase: CGFloat = reduceMotion
            ? 0.48
            : CGFloat(
                (date.timeIntervalSinceReferenceDate + Double(burstIndex) * 0.31)
                    .truncatingRemainder(dividingBy: 1.25) / 1.25
            )
        let radiusScale: CGFloat = prominence == .foreground ? 1 : 0.7
        let radius = (18 + rawPhase * 104) * radiusScale
        let particleSize: CGFloat = prominence == .foreground ? 6 : 4
        let origin = CGPoint(x: size.width * center.x, y: size.height * center.y)

        for particleIndex in 0..<14 {
            let angle = Double(particleIndex) / 14 * .pi * 2 + Double(burstIndex) * 0.4
            let point = CGPoint(
                x: origin.x + CGFloat(cos(angle)) * radius,
                y: origin.y + CGFloat(sin(angle)) * radius
            )
            let particle = Path(
                ellipseIn: CGRect(
                    x: point.x - particleSize / 2,
                    y: point.y - particleSize / 2,
                    width: particleSize,
                    height: particleSize
                )
            )
            context.fill(
                particle,
                with: .color(
                    colors[(particleIndex + burstIndex) % colors.count]
                        .opacity(Double(1 - rawPhase))
                )
            )
        }
    }
}

private struct SessionContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
