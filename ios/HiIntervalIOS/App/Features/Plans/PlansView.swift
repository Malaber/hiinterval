import SwiftUI
import HiIntervalCore

struct PlansView: View {
    @EnvironmentObject private var store: AppStore

    @State private var editorDestination: PlanEditorDestination?
    @State private var planPendingDeletion: WorkoutPlan?

    var body: some View {
        NavigationStack {
            ZStack {
                background
                if store.data.plans.isEmpty {
                    emptyState
                } else {
                    planList
                }
            }
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createPlan) {
                        Label("New plan", systemImage: "plus")
                    }
                    .accessibilityIdentifier("plans.add")
                }
            }
        }
        .tint(PlanPalette.accent)
        .accessibilityIdentifier("plans.screen")
        .sheet(item: $editorDestination) { destination in
            NavigationStack {
                PlanEditorView(plan: destination.plan, isNew: destination.isNew) { savedPlan in
                    store.savePlan(savedPlan)
                    store.selectPlan(id: savedPlan.id)
                    editorDestination = nil
                }
            }
            .tint(PlanPalette.accent)
        }
        .confirmationDialog(
            "Delete \(planPendingDeletion?.name ?? "plan")?",
            isPresented: deletionDialogBinding,
            titleVisibility: .visible
        ) {
            if let plan = planPendingDeletion {
                Button("Delete plan", role: .destructive) {
                    store.deletePlan(id: plan.id)
                    planPendingDeletion = nil
                }
                .accessibilityIdentifier("plan.delete.confirm")
            }
            Button("Cancel", role: .cancel) {
                planPendingDeletion = nil
            }
        } message: {
            Text("Workout history stays intact. This plan cannot be recovered.")
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                PlanPalette.secondary.opacity(0.12),
                PlanPalette.accent.opacity(0.06),
                Color(uiColor: .systemBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var planList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                intro
                ForEach(store.data.plans) { plan in
                    PlanCard(
                        plan: plan,
                        isSelected: store.data.selectedPlanID == plan.id,
                        onSelect: { store.selectPlan(id: plan.id) },
                        onEdit: { edit(plan) },
                        onDuplicate: { store.duplicatePlan(id: plan.id) },
                        onDelete: { planPendingDeletion = plan }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .hiStableScrollContrast()
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PlanPalette.accent)
                .frame(width: 42, height: 42)
                .background(PlanPalette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) {
                Text("Build your rhythm")
                    .font(.headline)
                Text("Every interval, side switch, and recovery can be tuned to your workout.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(PlanPalette.accent)
                .frame(width: 82, height: 82)
                .background(PlanPalette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 24))
            VStack(spacing: 6) {
                Text("Create your first plan")
                    .font(.title2.bold())
                Text("Start with one exercise. Fine-tune every interval whenever you want.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: createPlan) {
                Label("Create plan", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("plans.empty.create")
        }
        .padding(28)
        .accessibilityElement(children: .contain)
    }

    private var deletionDialogBinding: Binding<Bool> {
        Binding(
            get: { planPendingDeletion != nil },
            set: { if !$0 { planPendingDeletion = nil } }
        )
    }

    private func createPlan() {
        let plan = WorkoutPlan(
            name: "New interval plan",
            exercises: [ExerciseStep(name: "First exercise")]
        )
        editorDestination = PlanEditorDestination(plan: plan, isNew: true)
    }

    private func edit(_ plan: WorkoutPlan) {
        editorDestination = PlanEditorDestination(plan: plan, isNew: false)
    }
}

private struct PlanEditorDestination: Identifiable {
    let id = UUID()
    let plan: WorkoutPlan
    let isNew: Bool
}

private struct PlanCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var titleSize = 17

    let plan: WorkoutPlan
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    private var duration: String {
        guard let seconds = PlanFormatting.totalDuration(for: plan) else { return "Needs review" }
        return PlanFormatting.duration(seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(colorScheme == .dark ? Color.white : Color.black)
                    Image(systemName: isSelected ? "waveform.path.ecg" : "figure.highintensity.intervaltraining")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                }
                .frame(width: 48, height: 48)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(PlanPalette.accent, lineWidth: 3)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    titleBlock
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(plan.exercises.prefix(3)) { exercise in
                            Text(exercise.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(PlanPalette.cardText(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("Exercise: \(exercise.name)")
                        }
                    }
                }
                Spacer(minLength: 4)
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("plan.menu.edit.\(plan.id.uuidString)")
                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .accessibilityIdentifier("plan.duplicate.\(plan.id.uuidString)")
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("plan.delete.\(plan.id.uuidString)")
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Options for \(plan.name)")
                .accessibilityIdentifier("plan.menu.\(plan.id.uuidString)")
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    planMetrics
                }
            } else {
                HStack(spacing: 0) {
                    planMetrics
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    selectionButton
                    editButton
                }
            } else {
                HStack(spacing: 10) {
                    selectionButton
                    editButton
                }
            }
        }
        .padding(16)
        .foregroundStyle(PlanPalette.cardText(for: colorScheme))
        .background(
            PlanPalette.cardSurface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? PlanPalette.accent.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 5)
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Duplicate", action: onDuplicate)
            Button("Delete", role: .destructive, action: onDelete)
        }
        // Give the card its own accessibility container. Without `.contain`, applying an
        // identifier to this layout container can flatten or overwrite the identifiers of
        // its Button descendants when SwiftUI switches between the HStack and large-type
        // VStack layouts.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.card.\(plan.id.uuidString)")
    }

    @ViewBuilder
    private var titleBlock: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                planTitle
                readyBadge
            }
        } else {
            HStack(spacing: 8) {
                planTitle
                readyBadge
            }
        }
    }

    private var planTitle: some View {
        Text(plan.name)
            .font(.system(size: titleSize, weight: .semibold))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var readyBadge: some View {
        if isSelected {
            Text("READY")
                .font(.caption2.bold())
                .tracking(0.8)
                .foregroundStyle(PlanPalette.cardText(for: colorScheme))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(PlanPalette.accent.opacity(0.14), in: Capsule())
        }
    }

    @ViewBuilder
    private var planMetrics: some View {
        PlanMetric(icon: "clock", value: duration, label: "Duration", showsIcon: false)
            .frame(maxWidth: .infinity, alignment: .leading)
        PlanMetric(icon: "repeat", value: "\(plan.roundCount)", label: "Rounds", showsIcon: false)
            .frame(maxWidth: .infinity, alignment: .leading)
        PlanMetric(icon: "figure.run", value: "\(plan.exercises.count)", label: "Exercises", showsIcon: false)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectionButton: some View {
        Button(action: onSelect) {
            Label(
                isSelected ? "Selected" : "Use this plan",
                systemImage: isSelected ? "checkmark.circle.fill" : "play.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(Color.black.opacity(0.9))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background(PlanPalette.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Current plan" : "")
        .accessibilityIdentifier("plan.select.\(plan.id.uuidString)")
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Label("Edit", systemImage: "slider.horizontal.3")
                .font(.body.weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .frame(minHeight: 44)
                .padding(.horizontal, 16)
                .background(PlanPalette.cardText(for: colorScheme), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan.edit.\(plan.id.uuidString)")
    }
}
