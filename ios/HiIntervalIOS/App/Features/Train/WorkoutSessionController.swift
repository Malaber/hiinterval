import AudioToolbox
import AVFoundation
import HiIntervalCore
import SwiftUI
import UIKit

@MainActor
final class WorkoutSessionController: ObservableObject {
    @Published private(set) var engine: IntervalTimerEngine
    @Published private(set) var completion: WorkoutHistoryEntry?
    @Published var isMuted = false

    let plan: WorkoutPlan
    private let timeline: WorkoutTimeline
    private let cuePlayer = SessionCuePlayer()
    private let speedMultiplier: Double
    private let monotonicAnchor: ContinuousClock.Instant
    private let virtualAnchor: Date
    private var startedAt: Date?
    private var activeDuration = ActiveDurationTracker()
    private var lastCountdownSecond: Int?

    init(plan: WorkoutPlan) {
        self.plan = plan
        timeline = (try? WorkoutTimeline(plan: plan))
            ?? WorkoutTimeline(planID: plan.id, planName: plan.name, phases: [])
        engine = IntervalTimerEngine(timeline: timeline)
        speedMultiplier = max(
            1,
            Double(ProcessInfo.processInfo.environment["HIINTERVAL_UI_TEST_SPEED"] ?? "1") ?? 1
        )
        monotonicAnchor = ContinuousClock().now
        virtualAnchor = Date()
    }

    var tickInterval: TimeInterval { speedMultiplier > 1 ? 0.05 : 0.2 }

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
        let wallDate = Date()
        let clockDate = virtualNow()
        let priorSecond = engine.displayedRemainingSeconds
        let events = engine.tick(at: clockDate)
        handle(events, preferences: preferences, clockDate: clockDate, wallDate: wallDate)

        let second = engine.displayedRemainingSeconds
        if events.isEmpty,
           engine.state == .running,
           preferences.countdownEnabled,
           second > 0,
           second <= 3,
           second != priorSecond,
           second != lastCountdownSecond {
            lastCountdownSecond = second
            cuePlayer.countdown(second, preferences: preferences, muted: isMuted)
        }
    }

    func togglePause(preferences: UserPreferences) {
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
        let wallDate = Date()
        let clockDate = virtualNow()
        handle(
            engine.skip(at: clockDate),
            preferences: preferences,
            clockDate: clockDate,
            wallDate: wallDate
        )
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

    func toggleMute() {
        isMuted.toggle()
        cuePlayer.setMuted(isMuted)
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
        completion = WorkoutHistoryEntry(
            planID: plan.id,
            planName: plan.name,
            startedAt: started,
            completedAt: finishedAt,
            plannedDurationSeconds: timeline.totalDurationSeconds,
            elapsedDurationSeconds: max(0, Int(activeDuration.accumulatedSeconds)),
            roundCount: plan.roundCount,
            exerciseCount: plan.exercises.count,
            planSnapshot: plan
        )
    }
}

@MainActor
private final class SessionCuePlayer {
    private let speech = AVSpeechSynthesizer()
    private var audioDeactivationTask: Task<Void, Never>?

    func setMuted(_ muted: Bool) {
        if muted, speech.isSpeaking {
            speech.stopSpeaking(at: .immediate)
        }
        if muted {
            audioDeactivationTask?.cancel()
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    func phase(_ phase: WorkoutPhase, preferences: UserPreferences, muted: Bool) {
        haptic(preferences)
        guard !muted, preferences.cueStyle != .silent else { return }
        prepareAudio(preferences)
        switch preferences.cueStyle {
        case .tones:
            AudioServicesPlaySystemSound(phase.kind == .work ? 1_057 : 1_054)
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

    func countdown(_ second: Int, preferences: UserPreferences, muted: Bool) {
        if preferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        guard !muted, preferences.cueStyle != .silent else { return }
        prepareAudio(preferences)
        switch preferences.cueStyle {
        case .tones:
            AudioServicesPlaySystemSound(1_103)
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

    func pause(preferences: UserPreferences, muted: Bool) {
        if preferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        guard !muted, preferences.cueStyle != .silent else { return }
        prepareAudio(preferences)
        switch preferences.cueStyle {
        case .tones:
            AudioServicesPlaySystemSound(1_054)
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
        if preferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        guard !muted, preferences.cueStyle != .silent else { return }
        prepareAudio(preferences)
        switch preferences.cueStyle {
        case .tones:
            AudioServicesPlaySystemSound(1_057)
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
        if preferences.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        guard !muted, preferences.cueStyle != .silent else { return }
        prepareAudio(preferences)
        if preferences.cueStyle == .tones { AudioServicesPlaySystemSound(1_025) }
        if preferences.cueStyle == .spoken {
            let german = usesGerman(preferences)
            let utterance = AVSpeechUtterance(
                string: german ? "Training abgeschlossen" : "Workout complete"
            )
            utterance.voice = AVSpeechSynthesisVoice(language: german ? "de-DE" : "en-US")
            speech.speak(utterance)
        }
    }

    private func haptic(_ preferences: UserPreferences) {
        guard preferences.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func prepareAudio(_ preferences: UserPreferences) {
        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions = preferences.duckOtherAudio
            ? [.duckOthers]
            : [.mixWithOthers]
        try? session.setCategory(.playback, mode: .default, options: options)
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
