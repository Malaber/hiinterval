import XCTest
@testable import HiIntervalCore

final class CueAudioPolicyTests: XCTestCase {
    func testCuesUsePlaybackCategoryAndRequestedMixingBehavior() {
        let policy = CueAudioPolicy()

        XCTAssertEqual(policy.category, .playback)
        XCTAssertEqual(policy.mixingStrategy(duckOtherAudio: false), .mixWithOthers)
        XCTAssertEqual(policy.mixingStrategy(duckOtherAudio: true), .duckOthers)
    }

    func testEveryCueEventHasAUsableToneSignal() {
        let signals = CueToneEvent.allCases.map(CueToneSignal.signal(for:))

        XCTAssertEqual(signals.count, 7)
        XCTAssertEqual(signals.map(\.frequencyHz), [880, 660, 1_000, 740, 520, 780, 1_047])
        XCTAssertTrue(signals.allSatisfy { $0.durationSeconds > 0 })
        XCTAssertEqual(Set(signals.map(\.frequencyHz)).count, signals.count)
    }

    func testHalfwayCueRespectsAudioModeAndWarningPreference() {
        XCTAssertEqual(HalfwayCueAudio.output(enabled: true, cueStyle: .tones), .tone)
        XCTAssertEqual(HalfwayCueAudio.output(enabled: true, cueStyle: .spoken), .spoken)
        XCTAssertEqual(HalfwayCueAudio.output(enabled: true, cueStyle: .silent), .none)
        for style in CueStyle.allCases {
            XCTAssertEqual(HalfwayCueAudio.output(enabled: false, cueStyle: style), .none)
        }
    }

    func testToneSignalProducesValidMonoPCMHeaderAndSamples() {
        let data = CueToneSignal(frequencyHz: 440, durationSeconds: 0.01)
            .pcmWAVData(sampleRate: 8_000)

        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
        XCTAssertEqual(String(decoding: data[36..<40], as: UTF8.self), "data")
        XCTAssertEqual(data.count, 44 + 80 * MemoryLayout<Int16>.size)
        XCTAssertTrue(data.dropFirst(44).contains { $0 != 0 })
    }

    func testToneSignalClampsInvalidRateAndDuration() {
        let data = CueToneSignal(frequencyHz: 440, durationSeconds: -1)
            .pcmWAVData(sampleRate: 1)

        XCTAssertEqual(data.count, 44 + MemoryLayout<Int16>.size)
    }
}
