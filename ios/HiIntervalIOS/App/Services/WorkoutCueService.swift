import AVFAudio
import AudioToolbox
import HiIntervalCore
import UIKit

/// Owns short, local workout feedback. No network or recorded voice assets required.
@MainActor
final class WorkoutCueService {
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var isMuted = false

    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted, speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }

    func play(event: TimerEvent, preferences: UserPreferences) {
        switch event {
        case let .phaseStarted(phase), let .phaseRestarted(phase):
            announce(phase: phase, preferences: preferences)
        case .workoutStarted, .resumed:
            playStart(preferences: preferences)
        case .paused:
            playPause(preferences: preferences)
        case .workoutCompleted:
            playCompletion(preferences: preferences)
        }
    }

    func playCountdown(secondsRemaining: Int, preferences: UserPreferences) {
        guard preferences.countdownEnabled, (1...3).contains(secondsRemaining) else { return }
        if preferences.cueStyle == .spoken {
            speak(String(secondsRemaining))
        } else if preferences.cueStyle == .tones, !isMuted {
            AudioServicesPlaySystemSound(1104)
        }
        if preferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        }
    }

    private func announce(phase: WorkoutPhase, preferences: UserPreferences) {
        let side = phase.side.map { ", \($0 == .left ? "left side" : "right side")" } ?? ""
        if preferences.cueStyle == .spoken {
            speak("\(phase.title)\(side)")
        } else if preferences.cueStyle == .tones, !isMuted {
            AudioServicesPlaySystemSound(phase.kind == .work ? 1113 : 1114)
        }
        if preferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: phase.kind == .work ? .heavy : .medium).impactOccurred()
        }
    }

    private func playStart(preferences: UserPreferences) {
        guard !isMuted else { return }
        if preferences.cueStyle == .spoken {
            speak("Go")
        } else if preferences.cueStyle == .tones {
            AudioServicesPlaySystemSound(1113)
        }
        if preferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    private func playPause(preferences: UserPreferences) {
        guard !isMuted else { return }
        if preferences.cueStyle == .spoken {
            speak("Paused")
        } else if preferences.cueStyle == .tones {
            AudioServicesPlaySystemSound(1114)
        }
    }

    private func playCompletion(preferences: UserPreferences) {
        guard !isMuted else { return }
        if preferences.cueStyle == .spoken {
            speak("Workout complete")
        } else if preferences.cueStyle == .tones {
            AudioServicesPlaySystemSound(1025)
        }
        if preferences.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func speak(_ text: String) {
        guard !isMuted else { return }
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.02
        speechSynthesizer.speak(utterance)
    }
}
