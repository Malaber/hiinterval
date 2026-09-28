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

    func testDefaultConfigurationPreservesEveryClassicSignal() {
        let configuration = CueToneConfiguration()
        for event in CueToneEvent.allCases {
            XCTAssertEqual(configuration.preset(for: event), .classic)
            XCTAssertEqual(
                CueToneSignal.signal(for: event, configuration: configuration),
                CueToneSignal.signal(for: event)
            )
        }
    }

    func testPartiallyEncodedToneConfigurationUsesClassicForMissingEvents() throws {
        let decoder = JSONDecoder()
        let empty = try decoder.decode(CueToneConfiguration.self, from: Data("{}".utf8))
        for event in CueToneEvent.allCases {
            XCTAssertEqual(empty.preset(for: event), .classic)
        }

        let configuration = try decoder.decode(
            CueToneConfiguration.self,
            from: Data(#"{"work":"bright"}"#.utf8)
        )

        XCTAssertEqual(configuration.preset(for: .work), .bright)
        for event in CueToneEvent.allCases where event != .work {
            XCTAssertEqual(configuration.preset(for: event), .classic)
        }
    }

    func testToneEventsAndPresetsHaveDisplayNames() {
        XCTAssertEqual(
            CueToneEvent.allCases.map(\.displayName),
            ["Work", "Transition", "Countdown", "Halfway", "Pause", "Resume", "Completion"]
        )
        XCTAssertEqual(CueTonePreset.allCases.map(\.displayName), ["Classic", "Bright", "Mellow"])
    }

    func testTonePresetsCanBeSelectedIndependentlyForEveryEvent() {
        for event in CueToneEvent.allCases {
            var configuration = CueToneConfiguration()
            configuration.setPreset(.bright, for: event)
            XCTAssertEqual(configuration.preset(for: event), .bright)
            XCTAssertNotEqual(
                CueToneSignal.signal(for: event, configuration: configuration),
                CueToneSignal.signal(for: event)
            )
            for other in CueToneEvent.allCases where other != event {
                XCTAssertEqual(configuration.preset(for: other), .classic)
                XCTAssertEqual(
                    CueToneSignal.signal(for: other, configuration: configuration),
                    CueToneSignal.signal(for: other)
                )
            }
            configuration.setPreset(.mellow, for: event)
            let classic = CueToneSignal.signal(for: event)
            let mellow = CueToneSignal.signal(for: event, configuration: configuration)
            XCTAssertEqual(mellow.frequencyHz, classic.frequencyHz * 0.8)
            XCTAssertEqual(mellow.durationSeconds, classic.durationSeconds * 1.15)
        }
    }

    func testCueDispatchEligibilityForEveryEventAndTimerState() {
        for kind in CueDispatchKind.allCases {
            let expectedState: TimerState = switch kind {
            case .phase, .countdown, .halfway, .resume: .running
            case .pause: .paused
            case .completion: .finished
            }
            for state in [TimerState.ready, .running, .paused, .finished] {
                XCTAssertEqual(
                    CueDispatchPolicy.isEligible(kind, state: state),
                    state == expectedState,
                    "Unexpected \(kind) eligibility in \(state)"
                )
            }
        }
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
