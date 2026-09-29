import Foundation

public enum CueAudioCategory: Equatable, Sendable {
    case playback
}

public enum CueAudioMixingStrategy: Equatable, Sendable {
    case mixWithOthers
    case duckOthers
}

public struct CueAudioPolicy: Equatable, Sendable {
    public let category: CueAudioCategory

    public init(category: CueAudioCategory = .playback) {
        self.category = category
    }

    public func mixingStrategy(duckOtherAudio: Bool) -> CueAudioMixingStrategy {
        duckOtherAudio ? .duckOthers : .mixWithOthers
    }
}

public enum HalfwayCueAudio: Equatable, Sendable {
    case none
    case tone
    case spoken

    public static func output(enabled: Bool, cueStyle: CueStyle) -> Self {
        guard enabled else { return .none }
        switch cueStyle {
        case .tones: return .tone
        case .spoken: return .spoken
        case .silent: return .none
        }
    }
}

public enum CueToneEvent: String, Codable, CaseIterable, Hashable, Sendable {
    case work
    case transition
    case countdown
    case halfway
    case pause
    case resume
    case completion

    public var displayName: String {
        switch self {
        case .work: "Work"
        case .transition: "Transition"
        case .countdown: "Countdown"
        case .halfway: "Halfway"
        case .pause: "Pause"
        case .resume: "Resume"
        case .completion: "Completion"
        }
    }
}

public enum CueTonePreset: String, Codable, CaseIterable, Hashable, Sendable {
    case classic
    case bright
    case mellow
    case chime
    case bell
    case pulse
    case sweep

    public var displayName: String {
        switch self {
        case .classic: "Classic"
        case .bright: "Bright"
        case .mellow: "Mellow"
        case .chime: "Chime"
        case .bell: "Bell"
        case .pulse: "Pulse"
        case .sweep: "Sweep"
        }
    }
}

public struct CueToneConfiguration: Codable, Equatable, Sendable {
    public var work: CueTonePreset
    public var transition: CueTonePreset
    public var countdown: CueTonePreset
    public var halfway: CueTonePreset
    public var pause: CueTonePreset
    public var resume: CueTonePreset
    public var completion: CueTonePreset

    public init(
        work: CueTonePreset = .classic,
        transition: CueTonePreset = .classic,
        countdown: CueTonePreset = .classic,
        halfway: CueTonePreset = .classic,
        pause: CueTonePreset = .classic,
        resume: CueTonePreset = .classic,
        completion: CueTonePreset = .classic
    ) {
        self.work = work
        self.transition = transition
        self.countdown = countdown
        self.halfway = halfway
        self.pause = pause
        self.resume = resume
        self.completion = completion
    }

    private enum CodingKeys: String, CodingKey {
        case work, transition, countdown, halfway, pause, resume, completion
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        work = try values.decodeIfPresent(CueTonePreset.self, forKey: .work) ?? .classic
        transition = try values.decodeIfPresent(CueTonePreset.self, forKey: .transition) ?? .classic
        countdown = try values.decodeIfPresent(CueTonePreset.self, forKey: .countdown) ?? .classic
        halfway = try values.decodeIfPresent(CueTonePreset.self, forKey: .halfway) ?? .classic
        pause = try values.decodeIfPresent(CueTonePreset.self, forKey: .pause) ?? .classic
        resume = try values.decodeIfPresent(CueTonePreset.self, forKey: .resume) ?? .classic
        completion = try values.decodeIfPresent(CueTonePreset.self, forKey: .completion) ?? .classic
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(work, forKey: .work)
        try values.encode(transition, forKey: .transition)
        try values.encode(countdown, forKey: .countdown)
        try values.encode(halfway, forKey: .halfway)
        try values.encode(pause, forKey: .pause)
        try values.encode(resume, forKey: .resume)
        try values.encode(completion, forKey: .completion)
    }

    public func preset(for event: CueToneEvent) -> CueTonePreset {
        switch event {
        case .work: work
        case .transition: transition
        case .countdown: countdown
        case .halfway: halfway
        case .pause: pause
        case .resume: resume
        case .completion: completion
        }
    }

    public mutating func setPreset(_ preset: CueTonePreset, for event: CueToneEvent) {
        switch event {
        case .work: work = preset
        case .transition: transition = preset
        case .countdown: countdown = preset
        case .halfway: halfway = preset
        case .pause: pause = preset
        case .resume: resume = preset
        case .completion: completion = preset
        }
    }
}

public enum CueDispatchKind: CaseIterable, Equatable, Sendable {
    case phase
    case countdown
    case halfway
    case pause
    case resume
    case completion
}

public enum CueDispatchPolicy {
    public static func isEligible(_ kind: CueDispatchKind, state: TimerState) -> Bool {
        switch kind {
        case .phase, .countdown, .halfway, .resume: state == .running
        case .pause: state == .paused
        case .completion: state == .finished
        }
    }
}

public enum CueToneVoice: Equatable, Sendable {
    case sine
    case chime
    case bell
    case pulse
    case sweep
}

public struct CueToneSignal: Equatable, Sendable {
    public let frequencyHz: Double
    public let durationSeconds: TimeInterval
    public let voice: CueToneVoice

    public init(frequencyHz: Double, durationSeconds: TimeInterval, voice: CueToneVoice = .sine) {
        self.frequencyHz = frequencyHz
        self.durationSeconds = durationSeconds
        self.voice = voice
    }

    public static func signal(for event: CueToneEvent) -> CueToneSignal {
        switch event {
        case .work:
            CueToneSignal(frequencyHz: 880, durationSeconds: 0.18)
        case .transition:
            CueToneSignal(frequencyHz: 660, durationSeconds: 0.18)
        case .countdown:
            CueToneSignal(frequencyHz: 1_000, durationSeconds: 0.12)
        case .halfway:
            CueToneSignal(frequencyHz: 740, durationSeconds: 0.3)
        case .pause:
            CueToneSignal(frequencyHz: 520, durationSeconds: 0.16)
        case .resume:
            CueToneSignal(frequencyHz: 780, durationSeconds: 0.16)
        case .completion:
            CueToneSignal(frequencyHz: 1_047, durationSeconds: 0.42)
        }
    }

    public static func signal(
        for event: CueToneEvent,
        configuration: CueToneConfiguration
    ) -> CueToneSignal {
        let classic = signal(for: event)
        switch configuration.preset(for: event) {
        case .classic: return classic
        case .bright:
            return CueToneSignal(
                frequencyHz: classic.frequencyHz * 1.2,
                durationSeconds: classic.durationSeconds * 0.85
            )
        case .mellow:
            return CueToneSignal(
                frequencyHz: classic.frequencyHz * 0.8,
                durationSeconds: classic.durationSeconds * 1.15
            )
        case .chime:
            return CueToneSignal(
                frequencyHz: classic.frequencyHz * 1.1,
                durationSeconds: max(0.22, classic.durationSeconds * 1.2),
                voice: .chime
            )
        case .bell:
            return CueToneSignal(
                frequencyHz: classic.frequencyHz * 0.75,
                durationSeconds: max(0.3, classic.durationSeconds * 1.5),
                voice: .bell
            )
        case .pulse:
            return CueToneSignal(
                frequencyHz: classic.frequencyHz * 0.9,
                durationSeconds: max(0.22, classic.durationSeconds),
                voice: .pulse
            )
        case .sweep:
            return CueToneSignal(
                frequencyHz: classic.frequencyHz,
                durationSeconds: max(0.24, classic.durationSeconds),
                voice: .sweep
            )
        }
    }

    public func pcmWAVData(sampleRate requestedSampleRate: Int = 44_100) -> Data {
        let sampleRate = max(8_000, requestedSampleRate)
        let sampleCount = max(1, Int(max(0, durationSeconds) * Double(sampleRate)))
        let dataSize = sampleCount * MemoryLayout<Int16>.size
        var data = Data()

        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + dataSize), to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * MemoryLayout<Int16>.size), to: &data)
        append(UInt16(MemoryLayout<Int16>.size), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        append(UInt32(dataSize), to: &data)

        for sampleIndex in 0..<sampleCount {
            let progress = Double(sampleIndex) / Double(max(1, sampleCount - 1))
            let envelope = min(1, progress * 12) * min(1, (1 - progress) * 12)
            let time = Double(sampleIndex) / Double(sampleRate)
            let phase = 2 * Double.pi * frequencyHz * time
            let wave: Double
            let decay: Double
            switch voice {
            case .sine:
                wave = sin(phase)
                decay = 1
            case .chime:
                wave = (sin(phase) + 0.35 * sin(2 * phase) + 0.12 * sin(3 * phase)) / 1.47
                decay = exp(-2.3 * progress)
            case .bell:
                wave = (sin(phase) + 0.32 * sin(2.4 * phase) + 0.2 * sin(3.1 * phase)) / 1.52
                decay = exp(-3.2 * progress)
            case .pulse:
                let harmonics = (sin(phase) + sin(3 * phase) / 3 + sin(5 * phase) / 5) / 1.53
                let beat = 0.25 + 0.75 * pow(max(0, sin(2 * .pi * 11 * time)), 2)
                wave = harmonics * beat
                decay = 1
            case .sweep:
                let sweptPhase = phase * (1.5 - 0.5 * progress)
                wave = sin(sweptPhase)
                decay = 1
            }
            let amplitude = wave * envelope * decay * Double(Int16.max) * 0.24
            append(Int16(amplitude), to: &data)
        }

        return data
    }
}

private func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
        data.append(contentsOf: bytes)
    }
}
