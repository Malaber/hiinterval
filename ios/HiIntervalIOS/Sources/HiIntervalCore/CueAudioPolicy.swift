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

public enum CueToneEvent: CaseIterable, Equatable, Sendable {
    case work
    case transition
    case countdown
    case pause
    case resume
    case completion
}

public struct CueToneSignal: Equatable, Sendable {
    public let frequencyHz: Double
    public let durationSeconds: TimeInterval

    public init(frequencyHz: Double, durationSeconds: TimeInterval) {
        self.frequencyHz = frequencyHz
        self.durationSeconds = durationSeconds
    }

    public static func signal(for event: CueToneEvent) -> CueToneSignal {
        switch event {
        case .work:
            CueToneSignal(frequencyHz: 880, durationSeconds: 0.18)
        case .transition:
            CueToneSignal(frequencyHz: 660, durationSeconds: 0.18)
        case .countdown:
            CueToneSignal(frequencyHz: 1_000, durationSeconds: 0.12)
        case .pause:
            CueToneSignal(frequencyHz: 520, durationSeconds: 0.16)
        case .resume:
            CueToneSignal(frequencyHz: 780, durationSeconds: 0.16)
        case .completion:
            CueToneSignal(frequencyHz: 1_047, durationSeconds: 0.42)
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
            let wave = sin(2 * .pi * frequencyHz * Double(sampleIndex) / Double(sampleRate))
            let amplitude = wave * envelope * Double(Int16.max) * 0.24
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
