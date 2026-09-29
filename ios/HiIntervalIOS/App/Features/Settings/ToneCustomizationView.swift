import AVFoundation
import HiIntervalCore
import SwiftUI

struct ToneCustomizationView: View {
    let theme: WorkoutTheme
    let hapticsEnabled: Bool
    let duckOtherAudio: Bool
    let save: (CueToneConfiguration) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var draft: CueToneConfiguration
    @State private var selectedEvent: CueToneEvent = .work
    @State private var isTrainingPreviewPresented = false
    @State private var player: AVAudioPlayer?
    @State private var playbackTask: Task<Void, Never>?
    @State private var playbackError: String?

    init(
        initialConfiguration: CueToneConfiguration,
        theme: WorkoutTheme,
        hapticsEnabled: Bool,
        duckOtherAudio: Bool,
        save: @escaping (CueToneConfiguration) -> Void
    ) {
        self.theme = theme
        self.hapticsEnabled = hapticsEnabled
        self.duckOtherAudio = duckOtherAudio
        self.save = save
        _draft = State(initialValue: initialConfiguration)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(eventTitle(selectedEvent))
                                .font(.headline)
                            Text(draft.preset(for: selectedEvent).displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            playPreview(for: selectedEvent)
                        } label: {
                            Label("Play tone", systemImage: "play.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.tone.selected-preview")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("settings.tone.workout-preview")

                    Button {
                        stopPlayback()
                        isTrainingPreviewPresented = true
                    } label: {
                        Label("Try with a real training", systemImage: "play.circle")
                    }
                    .accessibilityIdentifier("settings.tone.try-training")
                } header: {
                    Text("Preview")
                } footer: {
                    Text("Choose a cue below to hear it here, or try the tones in a full training session. Preview sessions never save history. Changes are saved only when you tap Save.")
                }

                Section("Workout tones") {
                    ForEach(CueToneEvent.allCases, id: \.rawValue) { event in
                        HStack(spacing: 12) {
                            Picker(eventTitle(event), selection: presetBinding(for: event)) {
                                ForEach(CueTonePreset.allCases, id: \.self) { preset in
                                    Text(preset.displayName).tag(preset)
                                }
                            }
                            .accessibilityIdentifier("settings.tone.preset.\(event.rawValue)")
                            .accessibilityValue(draft.preset(for: event).displayName)

                            Button {
                                selectedEvent = event
                                playPreview(for: event)
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Preview \(eventTitle(event)) tone")
                            .accessibilityIdentifier("settings.tone.preview.\(event.rawValue)")
                        }
                    }

                    if let playbackError {
                        Text(playbackError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

            }
            .navigationTitle("Workout tones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("settings.tone.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(draft)
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.tone.save")
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset to default", role: .destructive) {
                        stopPlayback()
                        draft = CueToneConfiguration()
                        selectedEvent = .work
                    }
                    .accessibilityIdentifier("settings.tone.reset")
                }
            }
        }
        .fullScreenCover(isPresented: $isTrainingPreviewPresented) {
            WorkoutSessionFlow(plan: WorkoutPreviewPlan.plan, previewPreferences: previewPreferences)
                .environmentObject(store)
        }
        .onDisappear {
            // The training flow owns the shared audio session while presented.
            if !isTrainingPreviewPresented { stopPlayback() }
        }
    }

    private var previewPreferences: UserPreferences {
        var preferences = store.data.preferences
        preferences.workoutTheme = theme
        preferences.toneConfiguration = draft
        preferences.cueStyle = .tones
        preferences.hapticsEnabled = hapticsEnabled
        preferences.duckOtherAudio = duckOtherAudio
        return preferences
    }

    private func presetBinding(for event: CueToneEvent) -> Binding<CueTonePreset> {
        Binding(
            get: { draft.preset(for: event) },
            set: { preset in
                draft.setPreset(preset, for: event)
                selectedEvent = event
            }
        )
    }

    private func eventTitle(_ event: CueToneEvent) -> String {
        switch event {
        case .work: "Exercise start"
        case .transition: "Transition / recovery"
        case .countdown: "Countdown"
        case .halfway: "Halfway"
        case .pause: "Pause"
        case .resume: "Resume"
        case .completion: "Completion"
        }
    }

    private func playPreview(for event: CueToneEvent) {
        stopPlayback()
        playbackError = nil

        let signal = CueToneSignal.signal(for: event, configuration: draft)
        let session = AVAudioSession.sharedInstance()
        let mixing: AVAudioSession.CategoryOptions = duckOtherAudio ? .duckOthers : .mixWithOthers
        do {
            try session.setCategory(.playback, mode: .default, options: mixing)
            try session.setActive(true)
            let nextPlayer = try AVAudioPlayer(data: signal.pcmWAVData())
            nextPlayer.prepareToPlay()
            guard nextPlayer.play() else {
                throw PreviewPlaybackError.couldNotPlay
            }
            player = nextPlayer
            playbackTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(signal.durationSeconds + 0.1))
                guard !Task.isCancelled else { return }
                stopPlayback()
            }
        } catch {
            playbackError = "Tone preview is unavailable."
            stopPlayback()
        }
    }

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private enum PreviewPlaybackError: Error {
    case couldNotPlay
}
