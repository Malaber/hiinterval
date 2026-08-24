import Foundation
import HiIntervalCore
import SwiftUI

struct TrainHomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var activePlan: WorkoutPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    if let plan = store.selectedPlan {
                        selectedPlanCard(plan)
                    } else {
                        emptyCard
                    }
                    lastWorkout
                    earlyAccessNote
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Train")
        }
        .fullScreenCover(item: $activePlan) { plan in
            WorkoutSessionFlow(plan: plan)
                .environmentObject(store)
        }
        .accessibilityIdentifier("train.screen")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("READY WHEN YOU ARE")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(.primary)
            Text("Move with intent.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Build exact intervals once. Stay focused while HiInterval handles every cue.")
                .font(.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func selectedPlanCard(_ plan: WorkoutPlan) -> some View {
        let timeline = try? WorkoutTimeline(plan: plan)
        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("UP NEXT", systemImage: "waveform.path.ecg")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.primary)
                    Text(plan.name)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .accessibilityIdentifier("train.selected-plan-name")
                }
                Spacer()
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 0) {
                metric(value: "\(plan.exercises.count)", label: "exercises")
                Divider().frame(height: 36)
                metric(value: "\(plan.roundCount)", label: "rounds")
                Divider().frame(height: 36)
                metric(
                    value: SessionFormat.duration(timeline?.totalDurationSeconds ?? 0),
                    label: "total"
                )
            }

            Button {
                activePlan = plan
            } label: {
                Label("Start workout", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("train.start")
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.primary.opacity(0.07))
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var lastWorkout: some View {
        if let entry = store.data.history.sorted(by: { $0.completedAt > $1.completedAt }).first {
            VStack(alignment: .leading, spacing: 12) {
                Text("LAST SESSION")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.primary)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.planName)
                            .font(.headline)
                        Text(entry.completedAt, style: .relative)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Text(SessionFormat.duration(entry.elapsedDurationSeconds))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }
            }
            .padding(18)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 20)
            )
        }
    }

    private var earlyAccessNote: some View {
        Label {
            Text("Unlimited workouts during early access. No limits or purchase prompts.")
        } icon: {
            Image(systemName: "infinity.circle.fill")
                .foregroundStyle(Color.accentColor)
        }
        .font(.footnote)
        .foregroundStyle(.primary)
        .padding(.horizontal, 4)
        .accessibilityIdentifier("train.free-status")
    }

    private var emptyCard: some View {
        ContentUnavailableView(
            "Create your first plan",
            systemImage: "figure.highintensity.intervaltraining",
            description: Text("Open Plans to configure exercises, timing, rounds, and sides.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }
}

enum SessionFormat {
    static func duration(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3_600
        let minutes = (clamped % 3_600) / 60
        let remainder = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%d:%02d", minutes, remainder)
    }
}
