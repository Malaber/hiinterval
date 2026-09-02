import Combine
import Foundation
import HiIntervalCore

/// Single source of truth for persisted app state.
///
/// Mutations live here so every feature gets identical persistence and selection behavior.
@MainActor
final class AppStore: ObservableObject {
    static let persistenceKey = "io.malaber.hiinterval.app-data.v1"

    @Published var data: AppData {
        didSet { persist() }
    }

    @Published private(set) var lastErrorMessage: String?

    let reminders: ReminderScheduler

    private let defaults: UserDefaults
    private let persistenceKey: String
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        persistenceKey: String = AppStore.persistenceKey,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: @escaping () -> Date = { Date() },
        reminders: ReminderScheduler = ReminderScheduler()
    ) {
        self.defaults = defaults
        self.persistenceKey = persistenceKey
        self.now = now
        self.reminders = reminders

        let launchMode = UITestLaunchMode(arguments: arguments, environment: environment)
        if launchMode.isEnabled {
            defaults.removeObject(forKey: persistenceKey)
            switch launchMode.fixture {
            case .standard:
                data = AppData.uiTestFixture(now: now())
            case .empty:
                data = AppData()
            case .glanceableSession:
                data = AppData.uiTestGlanceableSessionFixture(now: now())
            }
            lastErrorMessage = nil
            persist()
            return
        }

        if arguments.contains("--reset-data") || arguments.contains("-reset-data") {
            defaults.removeObject(forKey: persistenceKey)
        }

        guard let encoded = defaults.data(forKey: persistenceKey) else {
            data = AppData.starter(now: now())
            lastErrorMessage = nil
            persist()
            return
        }

        do {
            data = Self.normalized(try AppDataCodec.decode(encoded))
            lastErrorMessage = nil
        } catch {
            defaults.set(encoded, forKey: "\(persistenceKey).recovery")
            data = AppData.starter(now: now())
            lastErrorMessage = "Saved data could not be opened. A recovery copy was kept and a fresh starter workout was created."
            persist()
        }
    }

    var selectedPlan: WorkoutPlan? {
        if let selectedID = data.selectedPlanID,
           let selected = data.plans.first(where: { $0.id == selectedID }) {
            return selected
        }
        return data.plans.first
    }

    @discardableResult
    func savePlan(_ plan: WorkoutPlan) -> Bool {
        do {
            try plan.validate()
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }

        var saved = plan
        saved.updatedAt = now()
        if let index = data.plans.firstIndex(where: { $0.id == saved.id }) {
            data.plans[index] = saved
        } else {
            data.plans.append(saved)
        }
        data.selectedPlanID = saved.id
        lastErrorMessage = nil
        return true
    }

    func deletePlan(id: UUID) {
        data.plans.removeAll { $0.id == id }
        if data.selectedPlanID == id || selectedPlan == nil {
            data.selectedPlanID = data.plans.first?.id
        }
    }

    @discardableResult
    func duplicatePlan(id: UUID) -> WorkoutPlan? {
        guard var copy = data.plans.first(where: { $0.id == id }) else { return nil }
        let timestamp = now()
        copy.id = UUID()
        copy.name = availableCopyName(for: copy.name)
        copy.createdAt = timestamp
        copy.updatedAt = timestamp
        for index in copy.exercises.indices {
            copy.exercises[index].id = UUID()
        }
        for index in copy.roundOverrides.indices {
            copy.roundOverrides[index].id = UUID()
        }
        data.plans.append(copy)
        data.selectedPlanID = copy.id
        return copy
    }

    func selectPlan(id: UUID) {
        guard data.plans.contains(where: { $0.id == id }) else { return }
        data.selectedPlanID = id
    }

    func addHistory(_ entry: WorkoutHistoryEntry) {
        guard !data.history.contains(where: { $0.id == entry.id }) else {
            updateHistory(entry)
            return
        }

        // Commit history and entitlement usage as one persisted AppData value. A workout
        // must never appear in history without also counting toward a future access policy.
        var updated = data
        updated.history.append(entry)
        updated.history.sort { $0.completedAt > $1.completedAt }
        updated.usage.completedWorkoutDates.append(entry.completedAt)
        data = updated
    }

    func updateHistory(_ entry: WorkoutHistoryEntry) {
        guard let index = data.history.firstIndex(where: { $0.id == entry.id }) else {
            addHistory(entry)
            return
        }
        var updated = data
        updated.history[index] = entry
        updated.history.sort { $0.completedAt > $1.completedAt }
        data = updated
    }

    func deleteHistory(id: UUID) {
        data.history.removeAll { $0.id == id }
    }

    func clearHistory() {
        data.history.removeAll()
    }

    func updatePreferences(_ preferences: UserPreferences) {
        data.preferences = preferences
    }

    func mutatePreferences(_ mutation: (inout UserPreferences) -> Void) {
        mutation(&data.preferences)
    }

    func beginTrialIfNeeded() {
        guard data.usage.trialStartedAt == nil else { return }
        data.usage.trialStartedAt = now()
    }

    func workoutAccess(
        policy: EntitlementPolicy = EntitlementPolicy(),
        at date: Date? = nil
    ) -> WorkoutAccess {
        policy.access(for: data.usage, now: date ?? now())
    }

    @discardableResult
    func recordCompletion(
        of plan: WorkoutPlan,
        startedAt: Date,
        completedAt: Date,
        elapsedSeconds: Int
    ) -> WorkoutHistoryEntry {
        let plannedDuration = (try? WorkoutTimeline(plan: plan).totalDurationSeconds) ?? elapsedSeconds
        let entry = WorkoutHistoryEntry(
            planID: plan.id,
            planName: plan.name,
            startedAt: startedAt,
            completedAt: completedAt,
            plannedDurationSeconds: plannedDuration,
            elapsedDurationSeconds: max(0, elapsedSeconds),
            roundCount: plan.roundCount,
            exerciseCount: plan.exercises.count,
            planSnapshot: plan
        )
        addHistory(entry)
        return entry
    }

    func resetAllData() {
        defaults.removeObject(forKey: persistenceKey)
        data = AppData.starter(now: now())
        lastErrorMessage = nil
    }

    /// Deterministic content used by XCUITest. Existing user defaults never leak into tests.
    func resetForUITesting() {
        defaults.removeObject(forKey: persistenceKey)
        data = AppData.uiTestFixture(now: now())
        lastErrorMessage = nil
    }

    func clearError() {
        lastErrorMessage = nil
    }

    private func availableCopyName(for original: String) -> String {
        let base = "\(original) Copy"
        if !data.plans.contains(where: { $0.name == base }) { return base }
        var suffix = 2
        while data.plans.contains(where: { $0.name == "\(base) \(suffix)" }) {
            suffix += 1
        }
        return "\(base) \(suffix)"
    }

    private func persist() {
        do {
            defaults.set(try AppDataCodec.encode(data), forKey: persistenceKey)
        } catch {
            lastErrorMessage = "Changes could not be saved."
        }
    }

    private static func normalized(_ source: AppData) -> AppData {
        var result = source
        if let selectedID = result.selectedPlanID,
           !result.plans.contains(where: { $0.id == selectedID }) {
            result.selectedPlanID = result.plans.first?.id
        }
        result.history.sort { $0.completedAt > $1.completedAt }
        return result
    }
}

private enum UITestFixtureMode {
    case standard
    case empty
    case glanceableSession
}

private struct UITestLaunchMode {
    let isEnabled: Bool
    let fixture: UITestFixtureMode

    init(arguments: [String], environment: [String: String]) {
        let values = Set(arguments.map { $0.lowercased() })
        let isEmpty = values.contains("--ui-testing-empty")
            || values.contains("-ui-testing-empty")
            || environment["HIINTERVAL_UI_TEST_FIXTURE"] == "empty"
        if isEmpty {
            fixture = .empty
        } else if environment["HIINTERVAL_UI_TEST_FIXTURE"] == "glanceable-session" {
            fixture = .glanceableSession
        } else {
            fixture = .standard
        }
        isEnabled = values.contains("--ui-testing")
            || values.contains("-ui-testing")
            || environment["HIINTERVAL_UI_TESTING"] == "1"
            || fixture != .standard
    }
}

private extension AppData {
    static func uiTestFixture(now: Date) -> AppData {
        let primaryID = fixtureUUID(1)
        let secondaryID = fixtureUUID(2)
        let primary = WorkoutPlan(
            id: primaryID,
            name: "Quick Start",
            warmUpSeconds: 3,
            defaultWorkSeconds: 5,
            defaultRecoverySeconds: 2,
            roundRecoverySeconds: 3,
            coolDownSeconds: 2,
            roundCount: 2,
            exercises: [
                ExerciseStep(id: fixtureUUID(11), name: "High Knees"),
                ExerciseStep(
                    id: fixtureUUID(12),
                    name: "Reverse Lunges",
                    duration: .custom(seconds: 6),
                    sideConfiguration: .leftRight(switchSeconds: 1)
                ),
            ],
            createdAt: now.addingTimeInterval(-86_400 * 14),
            updatedAt: now.addingTimeInterval(-86_400)
        )
        let secondary = WorkoutPlan(
            id: secondaryID,
            name: "Core Focus",
            warmUpSeconds: 5,
            defaultWorkSeconds: 8,
            defaultRecoverySeconds: 3,
            roundRecoverySeconds: 5,
            coolDownSeconds: 5,
            roundCount: 2,
            exercises: [
                ExerciseStep(id: fixtureUUID(21), name: "Dead Bug"),
                ExerciseStep(id: fixtureUUID(22), name: "Side Plank", sideConfiguration: .leftRight()),
            ],
            createdAt: now.addingTimeInterval(-86_400 * 7),
            updatedAt: now.addingTimeInterval(-86_400 * 2)
        )
        let completion = WorkoutHistoryEntry(
            id: fixtureUUID(31),
            planID: secondaryID,
            planName: secondary.name,
            startedAt: now.addingTimeInterval(-3_900),
            completedAt: now.addingTimeInterval(-3_600),
            plannedDurationSeconds: 57,
            elapsedDurationSeconds: 54,
            roundCount: secondary.roundCount,
            exerciseCount: secondary.exercises.count,
            planSnapshot: secondary
        )
        return AppData(
            plans: [primary, secondary],
            history: [completion],
            usage: UsageRecord(completedWorkoutDates: [completion.completedAt]),
            selectedPlanID: primary.id
        )
    }

    static func uiTestGlanceableSessionFixture(now: Date) -> AppData {
        let plan = WorkoutPlan(
            id: fixtureUUID(41),
            name: "Eight Move Session",
            warmUpSeconds: 0,
            defaultWorkSeconds: 105,
            defaultRecoverySeconds: 20,
            roundRecoverySeconds: 0,
            coolDownSeconds: 30,
            roundCount: 1,
            exercises: [
                ExerciseStep(id: fixtureUUID(42), name: "High Knees"),
                ExerciseStep(
                    id: fixtureUUID(43),
                    name: "Reverse Lunges",
                    sideConfiguration: .leftRight(switchSeconds: 1)
                ),
                ExerciseStep(id: fixtureUUID(44), name: "Floor Press"),
                ExerciseStep(id: fixtureUUID(45), name: "Renegade Rows"),
                ExerciseStep(id: fixtureUUID(46), name: "Shadow Boxing"),
                ExerciseStep(id: fixtureUUID(47), name: "Mountain Climbers"),
                ExerciseStep(id: fixtureUUID(48), name: "Side Heel Touch Crunches"),
                ExerciseStep(id: fixtureUUID(49), name: "Seated Russian Twist"),
            ],
            createdAt: now,
            updatedAt: now
        )
        return AppData(plans: [plan], selectedPlanID: plan.id)
    }

    static func fixtureUUID(_ finalByte: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, finalByte))
    }
}
