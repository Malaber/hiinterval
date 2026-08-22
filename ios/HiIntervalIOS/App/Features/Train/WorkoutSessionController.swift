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
    private let realAnchor: Date
    private let virtualAnchor: Date
    private var startedAt: Date?
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
        realAnchor = Date()
        virtualAnchor = Date()
    }

    var tickInterval: TimeInterval { speedMultiplier > 1 ? 0.05 : 0.2 }

    func start(preferences: UserPreferences) {
        guard engine.state == .ready else { return }
        startedAt = Date()
        handle(engine.start(at: virtualNow()), preferences: preferences)
    }

    func tick(preferences: UserPreferences) {
        let priorSecond = engine.displayedRemainingSeconds
        let events = engine.tick(at: virtualNow())
        handle(events, preferences: preferences)

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
        switch engine.state {
        case .running:
            handle(engine.pause(at: virtualNow()), preferences: preferences)
        case .paused:
            handle(engine.resume(at: virtualNow()), preferences: preferences)
        case .ready, .finished:
            break
        }
    }

    func pauseForBackground(preferences: UserPreferences) {
        guard preferences.pauseWhenInactive else { return }
        handle(engine.pause(at: virtualNow()), preferences: preferences)
    }

    func skip(preferences: UserPreferences) {
        handle(engine.skip(at: virtualNow()), preferences: preferences)
    }

    func restart(preferences: UserPreferences) {
        handle(engine.restartPhase(at: virtualNow()), preferences: preferences)
    }

    func toggleMute() {
        isMuted.toggle()
    }

    private func virtualNow() -> Date {
        let elapsed = Date().timeIntervalSince(realAnchor) * speedMultiplier
        return virtualAnchor.addingTimeInterval(elapsed)
    }

    private func handle(_ events: [TimerEvent], preferences: UserPreferences) {
        for event in events {
            switch event {
            case let .phaseStarted(phase), let .phaseRestarted(phase):
                lastCountdownSecond = nil
                cuePlayer.phase(phase, preferences: preferences, muted: isMuted)
            case .workoutCompleted:
                finish(preferences: preferences)
            case .paused:
                cuePlayer.pause(preferences: preferences, muted: isMuted)
            case .resumed:
                cuePlayer.resume(preferences: preferences, muted: isMuted)
            case .workoutStarted:
                break
            }
        }
    }

    private func finish(preferences: UserPreferences) {
        guard completion == nil else { return }
        cuePlayer.complete(preferences: preferences, muted: isMuted)
        let finishedAt = Date()
        let started = startedAt ?? finishedAt
        completion = WorkoutHistoryEntry(
            planID: plan.id,
            planName: plan.name,
            startedAt: started,
            completedAt: finishedAt,
            plannedDurationSeconds: timeline.totalDurationSeconds,
            elapsedDurationSeconds: max(0, Int(finishedAt.timeIntervalSince(started))),
            roundCount: plan.roundCount,
            exerciseCount: plan.exercises.count,
            planSnapshot: plan
        )
    }
}

@MainActor
private final class SessionCuePlayer {
    private let speech = AVSpeechSynthesizer()

    func phase(_ phase: WorkoutPhase, preferences: UserPreferences, muted: Bool) {
        guard !muted, preferences.cueStyle != .silent else { return }
        haptic(preferences)
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
        guard !muted, preferences.cueStyle != .silent else { return }
        AudioServicesPlaySystemSound(1_103)
        if preferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func pause(preferences: UserPreferences, muted: Bool) {
        guard !muted, preferences.cueStyle == .tones else { return }
        AudioServicesPlaySystemSound(1_054)
    }

    func resume(preferences: UserPreferences, muted: Bool) {
        guard !muted, preferences.cueStyle == .tones else { return }
        AudioServicesPlaySystemSound(1_057)
    }

    func complete(preferences: UserPreferences, muted: Bool) {
        guard !muted else { return }
        if preferences.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
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
