import AVFoundation
import HiIntervalCore
import SwiftUI
import UIKit

@MainActor
final class WorkoutSessionController: ObservableObject {
    @Published private(set) var engine: IntervalTimerEngine
    @Published private(set) var completion: WorkoutHistoryEntry?
    @Published private(set) var extraRoundCount = 0
    @Published var isMuted = false
    @Published private(set) var isPreviousTapArmed = false
    private var restartTapPolicy = RestartTapPolicy()
    private var restartIndicatorTask: Task<Void, Never>?

    let plan: WorkoutPlan
    private let plannedTimeline: WorkoutTimeline
    private let cuePlayer = SessionCuePlayer()
    private let historyEntryID = UUID()
    private let speedMultiplier: Double
    private let monotonicAnchor: ContinuousClock.Instant
    private let virtualAnchor: Date
    private var startedAt: Date?
    private var activeDuration = ActiveDurationTracker()
    private var lastCountdownSecond: Int?
    private var recoveryStartedAt: Date?
    private var halfwayCueTracker = HalfwayExerciseCueTracker()

    init(plan: WorkoutPlan) {
        self.plan = plan
        plannedTimeline = (try? WorkoutTimeline(plan: plan))
            ?? WorkoutTimeline(planID: plan.id, planName: plan.name, phases: [])
        engine = IntervalTimerEngine(timeline: plannedTimeline)
        speedMultiplier = max(
            1,
            Double(ProcessInfo.processInfo.environment["HIINTERVAL_UI_TEST_SPEED"] ?? "1") ?? 1
        )
        monotonicAnchor = ContinuousClock().now
        virtualAnchor = Date()
    }

    var tickInterval: TimeInterval { speedMultiplier > 1 ? 0.05 : 0.2 }
    var didExceedPlan: Bool { extraRoundCount > 0 }

    func start(preferences: UserPreferences) {
        guard engine.state == .ready else { return }
        let wallDate = Date()
        let clockDate = virtualNow()
        startedAt = wallDate
        handle(
            engine.start(at: clockDate),
            preferences: preferences,
            clockDate: clockDate,
            wallDate: wallDate
        )
    }

    func tick(preferences: UserPreferences) {
        refreshRestartTapState()
        let wallDate = Date()
        let clockDate = virtualNow()
        let priorSecond = engine.displayedRemainingSeconds
        let events = engine.tick(at: clockDate)
        handle(events, preferences: preferences, clockDate: clockDate, wallDate: wallDate)

        let second = engine.displayedRemainingSeconds
        let shouldPlayCountdown = events.isEmpty
            && engine.state == .running
            && preferences.countdownEnabled
            && second > 0
            && second <= 3
            && second != priorSecond
            && second != lastCountdownSecond

        let halfwayCue = events.isEmpty && engine.state == .running
            && preferences.halfwayCueEnabled && !cuePlayer.isSpeaking
            ? halfwayCueTracker.nextCue(
                in: engine.timeline,
                currentPhaseIndex: engine.currentPhaseIndex,
                elapsedSeconds: engine.totalElapsedSeconds
            )
            : nil

        if let halfwayCue {
            cuePlayer.halfway(
                exerciseName: halfwayCue.exerciseName,
                preferences: preferences,
                muted: isMuted
            )
        } else if shouldPlayCountdown {
            lastCountdownSecond = second
            cuePlayer.countdown(second, preferences: preferences, muted: isMuted)
        }
    }

    func togglePause(preferences: UserPreferences) {
        clearRestartTapState()
        let wallDate = Date()
        let clockDate = virtualNow()
        switch engine.state {
        case .running:
            handle(
                engine.pause(at: clockDate),
                preferences: preferences,
                clockDate: clockDate,
                wallDate: wallDate
            )
        case .paused:
            handle(
                engine.resume(at: clockDate),
                preferences: preferences,
                clockDate: clockDate,
                wallDate: wallDate
            )
        case .ready, .finished:
            break
        }
    }

    func pauseForBackground(preferences: UserPreferences) {
        clearRestartTapState()
        guard preferences.pauseWhenInactive else { return }
        let wallDate = Date()
        let clockDate = virtualNow()
        handle(
            engine.pause(at: clockDate),
            preferences: preferences,
            clockDate: clockDate,
            wallDate: wallDate
        )
    }

    func skip(preferences: UserPreferences) {
        clearRestartTapState()
        let wallDate = Date()
        let clockDate = virtualNow()
        handle(engine.tick(at: clockDate), preferences: preferences, clockDate: clockDate, wallDate: wallDate)
        halfwayCueTracker.suppressCue(for: engine.currentPhase?.position)
        handle(
            engine.skip(at: clockDate),
            preferences: preferences,
            clockDate: clockDate,
            wallDate: wallDate
        )
    }

    func restartTapped(preferences: UserPreferences) {
        let action = restartTapPolicy.tap(
            at: ProcessInfo.processInfo.systemUptime,
            canGoBack: engine.canReturnToPreviousExercise
        )
        switch action {
        case .restart: restart(preferences: preferences)
        case .previous: returnToPreviousExercise(preferences: preferences)
        }
        refreshRestartTapState()
        restartIndicatorTask?.cancel()
        if isPreviousTapArmed {
            restartIndicatorTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(RestartTapPolicy.windowDuration))
                guard !Task.isCancelled else { return }
                self?.refreshRestartTapState()
            }
        }
    }

    private func refreshRestartTapState() {
        let armed = restartTapPolicy.isArmed(at: ProcessInfo.processInfo.systemUptime)
            && engine.canReturnToPreviousExercise
        if isPreviousTapArmed != armed { isPreviousTapArmed = armed }
    }

    private func clearRestartTapState() {
        restartIndicatorTask?.cancel()
        restartIndicatorTask = nil
        restartTapPolicy.reset()
        isPreviousTapArmed = false
    }

    func restart(preferences: UserPreferences) {
        let wallDate = Date()
        let clockDate = virtualNow()
        handle(
            engine.restartPhase(at: clockDate),
            preferences: preferences,
            clockDate: clockDate,
            wallDate: wallDate
        )
    }

    func returnToPreviousExercise(preferences: UserPreferences) {
        clearRestartTapState()
        let wallDate = Date()
        let clockDate = virtualNow()
        handle(
            engine.returnToPreviousExercise(at: clockDate),
            preferences: preferences,
            clockDate: clockDate,
            wallDate: wallDate
        )
    }

    func toggleMute() {
        isMuted.toggle()
        cuePlayer.setMuted(isMuted)
    }

    func startOneMoreRound(preferences: UserPreferences) {
        guard completion != nil, let recoveryStartedAt else { return }
        let recoverySeconds = OneMoreRoundRecovery().remainingSeconds(
            configuredSeconds: plan.roundRecoverySeconds,
            elapsedSeconds: Date().timeIntervalSince(recoveryStartedAt)
        )
        let roundNumber = plan.roundCount + extraRoundCount + 1
        guard let extraTimeline = try? WorkoutTimeline.oneMoreRound(
            for: plan,
            recoverySeconds: recoverySeconds,
            roundNumber: roundNumber
        ) else { return }

        completion = nil
        self.recoveryStartedAt = nil
        extraRoundCount += 1
        engine = IntervalTimerEngine(timeline: extraTimeline)
        lastCountdownSecond = nil
        halfwayCueTracker = HalfwayExerciseCueTracker()

        let wallDate = Date()
        let clockDate = virtualNow()
        handle(
            engine.start(at: clockDate),
            preferences: preferences,
            clockDate: clockDate,
            wallDate: wallDate
        )
    }

    private func virtualNow() -> Date {
        let duration = monotonicAnchor.duration(to: ContinuousClock().now)
        let components = duration.components
        let elapsed = max(
            0,
            Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
        ) * speedMultiplier
        return virtualAnchor.addingTimeInterval(elapsed)
    }

    private func handle(
        _ events: [TimerEvent],
        preferences: UserPreferences,
        clockDate: Date,
        wallDate: Date
    ) {
        if events.contains(where: { event in
            if case .phaseStarted = event { return true }
            return false
        }) { clearRestartTapState() }
        let completed = events.contains { event in
            if case .workoutCompleted = event { return true }
            return false
        }
        let lastPhaseEventIndex = events.lastIndex { event in
            switch event {
            case .phaseStarted, .phaseRestarted: return true
            default: return false
            }
        }

        for (index, event) in events.enumerated() {
            switch event {
            case let .phaseStarted(phase), let .phaseRestarted(phase):
                guard !completed, index == lastPhaseEventIndex else { continue }
                lastCountdownSecond = nil
                cuePlayer.phase(phase, preferences: preferences, muted: isMuted)
            case .workoutCompleted:
                activeDuration.pause(at: clockDate)
                finish(preferences: preferences, finishedAt: wallDate)
            case .paused:
                activeDuration.pause(at: clockDate)
                cuePlayer.pause(preferences: preferences, muted: isMuted)
            case .resumed:
                activeDuration.start(at: clockDate)
                cuePlayer.resume(preferences: preferences, muted: isMuted)
            case .workoutStarted:
                activeDuration.start(at: clockDate)
            }
        }
    }

    private func finish(preferences: UserPreferences, finishedAt: Date) {
        guard completion == nil else { return }
        cuePlayer.complete(preferences: preferences, muted: isMuted)
        let started = startedAt ?? finishedAt
        recoveryStartedAt = finishedAt
        completion = WorkoutHistoryEntry(
            id: historyEntryID,
            planID: plan.id,
            planName: plan.name,
            startedAt: started,
            completedAt: finishedAt,
            plannedDurationSeconds: plannedTimeline.totalDurationSeconds,
            elapsedDurationSeconds: max(0, Int(activeDuration.accumulatedSeconds)),
            roundCount: plan.roundCount + extraRoundCount,
            exerciseCount: plan.exercises.count,
            planSnapshot: plan
        )
    }
}

@MainActor
private final class SessionCuePlayer {
    private let speech = AVSpeechSynthesizer()
    private let haptics = SessionHapticPlayer()
    private var tonePlayer: AVAudioPlayer?
    private var audioDeactivationTask: Task<Void, Never>?

    func setMuted(_ muted: Bool) {
        if muted, speech.isSpeaking {
            speech.stopSpeaking(at: .immediate)
        }
        if muted {
            tonePlayer?.stop()
            audioDeactivationTask?.cancel()
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    func phase(_ phase: WorkoutPhase, preferences: UserPreferences, muted: Bool) {
        haptics.play(.phase, enabled: preferences.hapticsEnabled)
        guard !muted, preferences.cueStyle != .silent else { return }
        prepareAudio(preferences)
        switch preferences.cueStyle {
        case .tones:
            playTone(phase.kind == .work ? .work : .transition)
        case .spoken:
            let german = usesGerman(preferences)
            var words = localizedTitle(for: phase, german: german)
            if let side = phase.side {
                if german {
                    words += side == .left ? ", linke Seite" : ", rechte Seite"
                } else {
                    words += side == .left ? ", left side" : ", right side"
                }
            }
            speech.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: words)
            utterance.voice = AVSpeechSynthesisVoice(language: german ? "de-DE" : "en-US")
            speech.speak(utterance)
        case .silent:
            break
        }
    }

    var isSpeaking: Bool { speech.isSpeaking }

    func countdown(_ second: Int, preferences: UserPreferences, muted: Bool) {
        haptics.play(.countdown, enabled: preferences.hapticsEnabled)
        guard !muted, preferences.cueStyle != .silent else { return }
        guard !speech.isSpeaking else { return }
        prepareAudio(preferences)
        switch preferences.cueStyle {
        case .tones:
            playTone(.countdown)
        case .spoken:
            let german = usesGerman(preferences)
            let utterance = AVSpeechUtterance(string: String(second))
            utterance.voice = AVSpeechSynthesisVoice(language: german ? "de-DE" : "en-US")
            speech.stopSpeaking(at: .immediate)
            speech.speak(utterance)
        case .silent:
            break
        }
    }

    func halfway(exerciseName: String, preferences: UserPreferences, muted: Bool) {
        guard !muted else { return }
        let output = HalfwayCueAudio.output(
            enabled: preferences.halfwayCueEnabled,
            cueStyle: preferences.cueStyle
        )
        guard output != .none else { return }
        prepareAudio(preferences)
        switch output {
        case .tone:
            playTone(.halfway)
        case .spoken:
            let german = usesGerman(preferences)
            let utterance = AVSpeechUtterance(
                string: german ? "Halbzeit bei \(exerciseName)" : "Halfway through \(exerciseName)"
            )
            utterance.voice = AVSpeechSynthesisVoice(language: german ? "de-DE" : "en-US")
            speech.stopSpeaking(at: .immediate)
            speech.speak(utterance)
        case .none:
            break
        }
    }

    func pause(preferences: UserPreferences, muted: Bool) {
        haptics.play(.pause, enabled: preferences.hapticsEnabled)
        guard !muted, preferences.cueStyle != .silent else { return }
        prepareAudio(preferences)
        switch preferences.cueStyle {
        case .tones:
            playTone(.pause)
        case .spoken:
            let german = usesGerman(preferences)
            let utterance = AVSpeechUtterance(string: german ? "Pausiert" : "Paused")
            utterance.voice = AVSpeechSynthesisVoice(language: german ? "de-DE" : "en-US")
            speech.speak(utterance)
        case .silent:
            break
        }
    }

    func resume(preferences: UserPreferences, muted: Bool) {
        haptics.play(.resume, enabled: preferences.hapticsEnabled)
        guard !muted, preferences.cueStyle != .silent else { return }
        prepareAudio(preferences)
        switch preferences.cueStyle {
        case .tones:
            playTone(.resume)
        case .spoken:
            let german = usesGerman(preferences)
            let utterance = AVSpeechUtterance(string: german ? "Weiter" : "Resume")
            utterance.voice = AVSpeechSynthesisVoice(language: german ? "de-DE" : "en-US")
            speech.speak(utterance)
        case .silent:
            break
        }
    }

    func complete(preferences: UserPreferences, muted: Bool) {
        haptics.play(.completion, enabled: preferences.hapticsEnabled)
        guard !muted, preferences.cueStyle != .silent else { return }
        prepareAudio(preferences)
        if preferences.cueStyle == .tones { playTone(.completion) }
        if preferences.cueStyle == .spoken {
            let german = usesGerman(preferences)
            let utterance = AVSpeechUtterance(
                string: german ? "Training abgeschlossen" : "Workout complete"
            )
            utterance.voice = AVSpeechSynthesisVoice(language: german ? "de-DE" : "en-US")
            speech.speak(utterance)
        }
    }

    private func prepareAudio(_ preferences: UserPreferences) {
        let session = AVAudioSession.sharedInstance()
        let policy = CueAudioPolicy()
        let category: AVAudioSession.Category = switch policy.category {
        case .playback: .playback
        }
        let options: AVAudioSession.CategoryOptions = switch policy.mixingStrategy(
            duckOtherAudio: preferences.duckOtherAudio
        ) {
        case .duckOthers: [.duckOthers]
        case .mixWithOthers: [.mixWithOthers]
        }
        try? session.setCategory(category, mode: .default, options: options)
        try? session.setActive(true)

        audioDeactivationTask?.cancel()
        audioDeactivationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            while self?.speech.isSpeaking == true {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            }
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func playTone(_ event: CueToneEvent) {
        let signal = CueToneSignal.signal(for: event)
        guard let player = try? AVAudioPlayer(data: signal.pcmWAVData()) else { return }
        tonePlayer = player
        player.prepareToPlay()
        player.play()
    }

    private func usesGerman(_ preferences: UserPreferences) -> Bool {
        switch preferences.cueLanguage {
        case .english: return false
        case .german: return true
        case .system: return Locale.current.language.languageCode?.identifier == "de"
        }
    }

    private func localizedTitle(for phase: WorkoutPhase, german: Bool) -> String {
        guard german else { return phase.title }
        switch phase.kind {
        case .warmUp: return "Aufwärmen"
        case .sideSwitch: return "Seite wechseln"
        case .recovery: return "Pause"
        case .roundRecovery: return "Rundenpause"
        case .coolDown: return "Abkühlen"
        case .work: return phase.title
        }
    }
}

@MainActor
private final class SessionHapticPlayer {
    func play(_ event: HapticCueEvent, enabled: Bool) {
        guard let feedback = HapticCuePolicy.feedback(
            for: event,
            hapticsEnabled: enabled
        ) else { return }

        switch feedback {
        case .lightImpact:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .softImpact:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .mediumImpact:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
