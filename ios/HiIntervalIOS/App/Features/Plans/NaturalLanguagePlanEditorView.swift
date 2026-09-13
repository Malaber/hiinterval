import FoundationModels
import HiIntervalCore
import SwiftUI

struct NaturalLanguagePlanEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: WorkoutPlan
    let isNew: Bool
    let onApply: (WorkoutPlan) -> Void

    @State private var request = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private var placeholder: String {
        if isNew {
            return "e.g. Create a 20-minute, low-impact workout with 3 rounds of squats, push-ups, and planks. Use 40 seconds work and 20 seconds recovery."
        }
        return "e.g. Make this workout 4 rounds, shorten recovery to 15 seconds, and add burpees after push-ups."
    }

    private var availability: AppleIntelligencePlanAvailability {
        AppleIntelligencePlanGenerator.availability
    }

    var body: some View {
        Form {
            Section {
                ZStack(alignment: .topLeading) {
                    if request.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("plan.ai.placeholder")
                    }

                    TextEditor(text: $request)
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)
                        .accessibilityLabel(isNew ? "Describe workout" : "Describe workout changes")
                        .accessibilityIdentifier("plan.ai.prompt")
                }
            } header: {
                Text(isNew ? "Describe your workout" : "What should change?")
            } footer: {
                Text("Example text is a visual placeholder only. Your prompt starts empty.")
            }

            Section("Apple Intelligence") {
                Label {
                    Text("Your request and workout stay on this device.")
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(PlanPalette.accent)
                }

                availabilityView

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("plan.ai.error")
                }
            }

            Section {
                Button(action: generate) {
                    HStack {
                        Spacer()
                        if isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "apple.intelligence")
                        }
                        Text(isGenerating ? "Updating…" : (isNew ? "Create Workout" : "Apply Changes"))
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(
                    request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || isGenerating
                        || availability != .available
                )
                .accessibilityIdentifier("plan.ai.generate")
            }
        }
        .navigationTitle(isNew ? "Create with Intelligence" : "Edit with Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("plan.ai.cancel")
            }
        }
        .interactiveDismissDisabled(isGenerating)
        .accessibilityIdentifier("plan.ai.screen")
    }

    @ViewBuilder
    private var availabilityView: some View {
        switch availability {
        case .available:
            Label("Ready on this device", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityIdentifier("plan.ai.available")
        case let .unavailable(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("plan.ai.unavailable")
        }
    }

    private func generate() {
        let trimmedRequest = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRequest.isEmpty, !isGenerating, availability == .available else { return }

        isGenerating = true
        errorMessage = nil
        Task {
            guard #available(iOS 26.0, *) else {
                errorMessage = "Requires iOS 26 or iPadOS 26."
                isGenerating = false
                return
            }
            do {
                let updated = try await AppleIntelligencePlanGenerator.generate(
                    plan: plan,
                    request: trimmedRequest
                )
                onApply(updated)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

enum AppleIntelligencePlanAvailability: Equatable {
    case available
    case unavailable(String)
}

enum AppleIntelligencePlanGenerator {
    static var availability: AppleIntelligencePlanAvailability {
        guard #available(iOS 26.0, *) else {
            return .unavailable("Requires iOS 26 or iPadOS 26.")
        }

        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Turn on Apple Intelligence in Settings to use this feature.")
        case .unavailable(.deviceNotEligible):
            return .unavailable("Apple Intelligence is not supported on this device.")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple Intelligence is still preparing its on-device model.")
        case .unavailable:
            return .unavailable("Apple Intelligence is currently unavailable.")
        }
    }

    @available(iOS 26.0, *)
    static func generate(plan: WorkoutPlan, request: String) async throws -> WorkoutPlan {
        let session = LanguageModelSession(instructions: """
            You edit interval workout plans. Return a complete plan reflecting the person's request.
            Preserve every existing value that the person did not ask to change. Durations are seconds.
            Keep exercise names short and actionable. Notes may be empty. A workout needs 1–30 exercises.
            """)
        let response = try await session.respond(
            to: """
                Current workout:
                \(plan.modelContext)

                Requested change:
                \(request)
                """,
            generating: GeneratedWorkoutPlan.self
        )
        return try response.content.applying(to: plan)
    }
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedWorkoutPlan {
    var name: String
    @Guide(.minimum(0), .maximum(3_600))
    var warmUpSeconds: Int
    var warmUpNotes: String
    @Guide(.minimum(1), .maximum(3_600))
    var defaultWorkSeconds: Int
    @Guide(.minimum(0), .maximum(3_600))
    var defaultRecoverySeconds: Int
    var recoveryNotes: String
    @Guide(.minimum(0), .maximum(3_600))
    var roundRecoverySeconds: Int
    var roundRecoveryNotes: String
    @Guide(.minimum(0), .maximum(3_600))
    var coolDownSeconds: Int
    var coolDownNotes: String
    @Guide(.minimum(1), .maximum(50))
    var roundCount: Int
    @Guide(.minimumCount(1), .maximumCount(30))
    var exercises: [GeneratedExercise]
    @Guide(.maximumCount(50))
    var roundOverrides: [GeneratedRoundOverride]

    func applying(to source: WorkoutPlan) throws -> WorkoutPlan {
        var result = source
        result.name = normalized(name, fallback: source.name)
        result.warmUpSeconds = warmUpSeconds
        result.warmUpNotes = optionalText(warmUpNotes)
        result.defaultWorkSeconds = defaultWorkSeconds
        result.defaultRecoverySeconds = defaultRecoverySeconds
        result.recoveryNotes = optionalText(recoveryNotes)
        result.roundRecoverySeconds = roundRecoverySeconds
        result.roundRecoveryNotes = optionalText(roundRecoveryNotes)
        result.coolDownSeconds = coolDownSeconds
        result.coolDownNotes = optionalText(coolDownNotes)
        result.roundCount = roundCount
        result.exercises = exercises.enumerated().map { index, generated in
            let existing = source.exercises.indices.contains(index) ? source.exercises[index] : nil
            return generated.exercise(existing: existing, index: index)
        }

        var seenRounds = Set<Int>()
        result.roundOverrides = roundOverrides.compactMap { generated in
            guard (1...result.roundCount).contains(generated.roundNumber),
                  seenRounds.insert(generated.roundNumber).inserted else { return nil }
            return generated.roundOverride
        }
        try result.validate()
        return result
    }
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedExercise {
    var name: String
    var usesDefaultWork: Bool
    @Guide(.minimum(1), .maximum(3_600))
    var workSeconds: Int
    var recoveryMode: GeneratedRecoveryMode
    @Guide(.minimum(0), .maximum(3_600))
    var recoverySeconds: Int
    var sideMode: GeneratedSideMode
    var startsOnLeft: Bool
    @Guide(.minimum(0), .maximum(600))
    var sideSwitchSeconds: Int
    var notes: String

    func exercise(existing: ExerciseStep?, index: Int) -> ExerciseStep {
        let duration: DurationSetting = usesDefaultWork
            ? .planDefault
            : .custom(seconds: workSeconds)
        let recovery: RecoverySetting = switch recoveryMode {
        case .planDefault: .planDefault
        case .custom: .custom(seconds: recoverySeconds)
        case .none: .none
        }
        let sideConfiguration: SideConfiguration = switch sideMode {
        case .together: .together
        case .leftRight:
            .leftRight(
                firstSide: startsOnLeft ? .left : .right,
                switchSeconds: sideSwitchSeconds
            )
        }

        return ExerciseStep(
            id: existing?.id ?? UUID(),
            name: normalized(name, fallback: existing?.name ?? "Exercise \(index + 1)"),
            duration: duration,
            recovery: recovery,
            sideConfiguration: sideConfiguration,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedRoundOverride {
    @Guide(.minimum(1), .maximum(50))
    var roundNumber: Int
    var overridesWork: Bool
    @Guide(.minimum(1), .maximum(3_600))
    var workSeconds: Int
    var overridesSides: Bool
    var sideMode: GeneratedSideMode
    var startsOnLeft: Bool
    @Guide(.minimum(0), .maximum(600))
    var sideSwitchSeconds: Int

    var roundOverride: WorkoutRoundOverride {
        let sideConfiguration: SideConfiguration?
        if overridesSides {
            sideConfiguration = switch sideMode {
            case .together: .together
            case .leftRight:
                .leftRight(
                    firstSide: startsOnLeft ? .left : .right,
                    switchSeconds: sideSwitchSeconds
                )
            }
        } else {
            sideConfiguration = nil
        }

        return WorkoutRoundOverride(
            roundNumber: roundNumber,
            workSeconds: overridesWork ? workSeconds : nil,
            sideConfiguration: sideConfiguration
        )
    }
}

@available(iOS 26.0, *)
@Generable
private enum GeneratedRecoveryMode {
    case planDefault
    case custom
    case none
}

@available(iOS 26.0, *)
@Generable
private enum GeneratedSideMode {
    case together
    case leftRight
}

private extension WorkoutPlan {
    var modelContext: String {
        let exerciseLines = exercises.enumerated().map { index, exercise in
            let work = switch exercise.duration {
            case .planDefault: "default"
            case let .custom(seconds): "\(seconds)s"
            }
            let recovery = switch exercise.recovery {
            case .planDefault: "default"
            case let .custom(seconds): "\(seconds)s"
            case .none: "none"
            }
            let sides = exercise.sideConfiguration.mode == .together
                ? "together"
                : "leftRight, first=\(exercise.sideConfiguration.firstSide.rawValue), switch=\(exercise.sideConfiguration.switchSeconds)s"
            return "\(index + 1). \(exercise.name); work=\(work); recovery=\(recovery); sides=\(sides); notes=\(exercise.notes)"
        }.joined(separator: "\n")
        let overrideLines = roundOverrides.map { override in
            "round=\(override.roundNumber); work=\(override.workSeconds.map(String.init) ?? "unchanged"); sides=\(override.sideConfiguration?.mode.rawValue ?? "unchanged")"
        }.joined(separator: "\n")

        return """
            name=\(name)
            warmUp=\(warmUpSeconds)s; warmUpNotes=\(warmUpNotes ?? "")
            defaultWork=\(defaultWorkSeconds)s; defaultRecovery=\(defaultRecoverySeconds)s
            recoveryNotes=\(recoveryNotes ?? "")
            rounds=\(roundCount); roundRecovery=\(roundRecoverySeconds)s; roundRecoveryNotes=\(roundRecoveryNotes ?? "")
            coolDown=\(coolDownSeconds)s; coolDownNotes=\(coolDownNotes ?? "")
            exercises:
            \(exerciseLines)
            roundOverrides:
            \(overrideLines.isEmpty ? "none" : overrideLines)
            """
    }
}

private func normalized(_ text: String, fallback: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? fallback : trimmed
}

private func optionalText(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
