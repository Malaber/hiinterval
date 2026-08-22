import SwiftUI
import HiIntervalCore

struct RoundOverridesEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let roundCount: Int
    let defaultWorkSeconds: Int

    @Binding private var overrides: [WorkoutRoundOverride]
    @State private var workingOverrides: [WorkoutRoundOverride]

    init(
        roundCount: Int,
        defaultWorkSeconds: Int,
        overrides: Binding<[WorkoutRoundOverride]>
    ) {
        self.roundCount = roundCount
        self.defaultWorkSeconds = defaultWorkSeconds
        _overrides = overrides
        _workingOverrides = State(initialValue: overrides.wrappedValue)
    }

    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Shape each round")
                            .font(.headline)
                        Text("Overrides apply to every exercise in that round.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "square.3.layers.3d.down.right.fill")
                        .font(.title2)
                        .foregroundStyle(PlanPalette.secondary)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)

            ForEach(1...max(1, roundCount), id: \.self) { round in
                roundSection(round)
            }

            if !workingOverrides.isEmpty {
                Section {
                    Button("Reset every round", role: .destructive) {
                        withAnimation { workingOverrides.removeAll() }
                    }
                    .accessibilityIdentifier("roundOverrides.resetAll")
                }
            }
        }
        .navigationTitle("Round overrides")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("roundOverrides.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: save)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("roundOverrides.save")
            }
        }
        .accessibilityIdentifier("roundOverrides.screen")
    }

    @ViewBuilder
    private func roundSection(_ round: Int) -> some View {
        Section {
            Toggle("Customize round \(round)", isOn: overrideEnabled(round))
                .fontWeight(.medium)
                .tint(PlanPalette.accent)
                .accessibilityIdentifier("roundOverride.enabled.\(round)")

            if currentOverride(round) != nil {
                Toggle("Custom work time", isOn: workOverrideEnabled(round))
                    .accessibilityIdentifier("roundOverride.work.enabled.\(round)")

                if workOverrideEnabled(round).wrappedValue {
                    PlanDurationStepper(
                        "Work per exercise",
                        seconds: workSeconds(round),
                        range: 1...3_600,
                        accessibilityID: "roundOverride.work.seconds.\(round)"
                    )
                }

                Toggle("Override training style", isOn: sideOverrideEnabled(round))
                    .accessibilityIdentifier("roundOverride.side.enabled.\(round)")

                if sideOverrideEnabled(round).wrappedValue {
                    Picker("Training style", selection: sideMode(round)) {
                        Text("Together").tag(SideMode.together)
                        Text("Left + right").tag(SideMode.leftRight)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("roundOverride.side.mode.\(round)")

                    if sideMode(round).wrappedValue == .leftRight {
                        Picker("Start on", selection: firstSide(round)) {
                            ForEach(WorkoutSide.allCases, id: \.self) { side in
                                Text(PlanFormatting.sideLabel(side)).tag(side)
                            }
                        }
                        .accessibilityIdentifier("roundOverride.side.first.\(round)")

                        PlanDurationStepper(
                            "Time to switch",
                            seconds: switchSeconds(round),
                            range: 0...300,
                            step: 1,
                            accessibilityID: "roundOverride.side.switch.\(round)"
                        )
                    }
                }
            }
        } header: {
            HStack {
                Text("Round \(round)")
                Spacer()
                Text(summary(round))
                    .font(.caption)
                    .textCase(nil)
                    .foregroundStyle(currentOverride(round) == nil ? Color.secondary : PlanPalette.secondary)
            }
        } footer: {
            if let roundOverride = currentOverride(round),
               roundOverride.sideConfiguration?.mode == .leftRight {
                Text("Left/right replaces each exercise's own side setting for this round.")
            }
        }
    }

    private func currentOverride(_ round: Int) -> WorkoutRoundOverride? {
        workingOverrides.last { $0.roundNumber == round }
    }

    private func updateOverride(
        _ round: Int,
        update: (inout WorkoutRoundOverride) -> Void
    ) {
        var item = currentOverride(round) ?? WorkoutRoundOverride(roundNumber: round)
        update(&item)
        workingOverrides.removeAll { $0.roundNumber == round }
        workingOverrides.append(item)
        workingOverrides.sort { $0.roundNumber < $1.roundNumber }
    }

    private func overrideEnabled(_ round: Int) -> Binding<Bool> {
        Binding {
            currentOverride(round) != nil
        } set: { enabled in
            if enabled {
                guard currentOverride(round) == nil else { return }
                workingOverrides.append(
                    WorkoutRoundOverride(roundNumber: round, workSeconds: defaultWorkSeconds)
                )
                workingOverrides.sort { $0.roundNumber < $1.roundNumber }
            } else {
                workingOverrides.removeAll { $0.roundNumber == round }
            }
        }
    }

    private func workOverrideEnabled(_ round: Int) -> Binding<Bool> {
        Binding {
            currentOverride(round)?.workSeconds != nil
        } set: { enabled in
            updateOverride(round) { item in
                item.workSeconds = enabled ? max(1, item.workSeconds ?? defaultWorkSeconds) : nil
            }
        }
    }

    private func workSeconds(_ round: Int) -> Binding<Int> {
        Binding {
            currentOverride(round)?.workSeconds ?? max(1, defaultWorkSeconds)
        } set: { seconds in
            updateOverride(round) { $0.workSeconds = max(1, seconds) }
        }
    }

    private func sideOverrideEnabled(_ round: Int) -> Binding<Bool> {
        Binding {
            currentOverride(round)?.sideConfiguration != nil
        } set: { enabled in
            updateOverride(round) { item in
                item.sideConfiguration = enabled ? (item.sideConfiguration ?? .together) : nil
            }
        }
    }

    private func sideMode(_ round: Int) -> Binding<SideMode> {
        Binding {
            currentOverride(round)?.sideConfiguration?.mode ?? .together
        } set: { mode in
            updateOverride(round) { item in
                var configuration = item.sideConfiguration ?? .together
                configuration.mode = mode
                item.sideConfiguration = configuration
            }
        }
    }

    private func firstSide(_ round: Int) -> Binding<WorkoutSide> {
        Binding {
            currentOverride(round)?.sideConfiguration?.firstSide ?? .left
        } set: { side in
            updateOverride(round) { item in
                var configuration = item.sideConfiguration ?? .leftRight()
                configuration.firstSide = side
                item.sideConfiguration = configuration
            }
        }
    }

    private func switchSeconds(_ round: Int) -> Binding<Int> {
        Binding {
            currentOverride(round)?.sideConfiguration?.switchSeconds ?? 0
        } set: { seconds in
            updateOverride(round) { item in
                var configuration = item.sideConfiguration ?? .leftRight()
                configuration.switchSeconds = max(0, seconds)
                item.sideConfiguration = configuration
            }
        }
    }

    private func summary(_ round: Int) -> String {
        guard let item = currentOverride(round) else { return "Plan defaults" }
        var parts: [String] = []
        if let seconds = item.workSeconds {
            parts.append(PlanFormatting.compactDuration(seconds))
        }
        if let side = item.sideConfiguration {
            parts.append(side.mode == .leftRight ? "Split sides" : "Together")
        }
        return parts.isEmpty ? "Customized" : parts.joined(separator: " · ")
    }

    private func save() {
        overrides = (1...roundCount).compactMap { round in
            workingOverrides.last { $0.roundNumber == round }
        }
        dismiss()
    }
}
