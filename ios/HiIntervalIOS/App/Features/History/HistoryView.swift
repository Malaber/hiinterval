import CoreTransferable
import Foundation
import HiIntervalCore
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showClearConfirmation = false

    private var entries: [WorkoutHistoryEntry] {
        store.data.history.sorted { $0.completedAt > $1.completedAt }
    }

    private var summary: HistorySummary {
        HistorySummary.calculate(entries: store.data.history, now: Date())
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Completed workouts appear here with reusable settings.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            summaryGrid
                            LazyVStack(spacing: 12) {
                                ForEach(entries) { entry in
                                    NavigationLink {
                                        HistoryDetailView(entryID: entry.id)
                                    } label: {
                                        historyRow(entry)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("history.entry.\(entry.id.uuidString)")
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("History")
            .toolbar {
                if !entries.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ShareLink(
                            item: HistoryCSVDocument(csv: HistoryCSVExporter.csv(entries: entries)),
                            preview: SharePreview("HiInterval History")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export history")
                        .accessibilityIdentifier("history.export")
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Clear history")
                        .accessibilityIdentifier("history.clear")
                    }
                }
            }
            .confirmationDialog(
                "Clear all workout history?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear history", role: .destructive) { store.clearHistory() }
                    .accessibilityIdentifier("history.clear.confirm")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Saved workout plans are not affected.")
            }
        }
        .accessibilityIdentifier("history.screen")
    }

    private var summaryGrid: some View {
        HStack(spacing: 10) {
            summaryCard("Sessions", "\(summary.completedWorkouts)", "checkmark.circle.fill")
            summaryCard("Training", SessionFormat.duration(summary.totalDurationSeconds), "stopwatch.fill")
            summaryCard("Streak", "\(summary.currentStreakDays)d", "flame.fill")
        }
        .padding(.top, 8)
    }

    private func summaryCard(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func historyRow(_ entry: WorkoutHistoryEntry) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        historyDate(entry)
                        historyDescription(entry)
                    }
                    historyDuration(entry)
                }
            } else {
                HStack(spacing: 14) {
                    historyDate(entry)
                    historyDescription(entry)
                    Spacer(minLength: 8)
                    historyDuration(entry)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private func historyDate(_ entry: WorkoutHistoryEntry) -> some View {
        VStack {
            Text(entry.completedAt, format: .dateTime.day())
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(entry.completedAt, format: .dateTime.month(.abbreviated))
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: true, vertical: true)
        }
        .frame(minWidth: 50, minHeight: 58)
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    private func historyDescription(_ entry: WorkoutHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.planName)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(entry.exerciseCount) exercises · \(entry.roundCount) rounds")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func historyDuration(_ entry: WorkoutHistoryEntry) -> some View {
        Text(SessionFormat.duration(entry.elapsedDurationSeconds))
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .monospacedDigit()
    }
}

private struct HistoryDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID
    @State private var showRename = false
    @State private var showDelete = false
    @State private var renamedPlan = ""
    @State private var reuseMessage: String?

    private var entry: WorkoutHistoryEntry? {
        store.data.history.first { $0.id == entryID }
    }

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.accentColor)
                            Text(entry.planName)
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("history.detail.title")
                            Text(entry.completedAt, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 18)

                        HStack(spacing: 12) {
                            detailMetric("Duration", SessionFormat.duration(entry.elapsedDurationSeconds))
                            detailMetric("Rounds", "\(entry.roundCount)")
                            detailMetric("Moves", "\(entry.exerciseCount)")
                        }

                        if let reuseMessage {
                            Label(reuseMessage, systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                                .accessibilityIdentifier("history.reuse.status")
                        }

                        Button {
                            reuse(entry)
                        } label: {
                            Label("Reuse as new plan", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(entry.planSnapshot == nil)
                        .accessibilityIdentifier("history.reuse")

                        Button {
                            renamedPlan = entry.planName
                            showRename = true
                        } label: {
                            Label("Rename session", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("history.rename")

                        Button(role: .destructive) {
                            showDelete = true
                        } label: {
                            Label("Delete session", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("history.delete")
                    }
                    .padding(20)
                }
                .navigationTitle("Session")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("Session not found", systemImage: "questionmark.folder")
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .accessibilityIdentifier("history.detail.screen")
        .alert("Rename session", isPresented: $showRename) {
            TextField("Session name", text: $renamedPlan)
                .accessibilityIdentifier("history.rename.field")
            Button("Save") { rename() }
                .accessibilityIdentifier("history.rename.save")
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this session?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete session", role: .destructive) {
                store.deleteHistory(id: entryID)
                dismiss()
            }
            .accessibilityIdentifier("history.delete.confirm")
            Button("Cancel", role: .cancel) {}
        }
    }

    private func detailMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func rename() {
        guard var updated = entry else { return }
        let trimmed = renamedPlan.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updated.planName = trimmed
        store.updateHistory(updated)
    }

    private func reuse(_ entry: WorkoutHistoryEntry) {
        guard var plan = entry.planSnapshot else { return }
        plan.id = UUID()
        plan.name += " Copy"
        plan.createdAt = Date()
        plan.updatedAt = plan.createdAt
        for index in plan.exercises.indices {
            plan.exercises[index].id = UUID()
        }
        for index in plan.roundOverrides.indices {
            plan.roundOverrides[index].id = UUID()
        }
        if store.savePlan(plan) {
            store.selectPlan(id: plan.id)
            reuseMessage = "Plan copied and selected"
        }
    }
}

private struct HistoryCSVDocument: Transferable {
    let csv: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { document in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("HiInterval-History.csv")
            try Data(document.csv.utf8).write(to: destination, options: .atomic)
            return SentTransferredFile(destination)
        }
    }
}
