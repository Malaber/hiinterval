import XCTest
@testable import HiIntervalCore

final class ExerciseCatalogueTests: XCTestCase {
    func testLegacyPlansMigrateEachStepWithoutTouchingHistory() throws {
        let first = ExerciseStep(id: UUID(), name: "Push-up", notes: "slow")
        let second = ExerciseStep(id: UUID(), name: "Push-up")
        let plan = WorkoutPlan(name: "Live", exercises: [first, second])
        let historical = WorkoutPlan(name: "Old", exercises: [ExerciseStep(name: "Old")])
        let data = AppData(plans: [plan], history: [history(snapshot: historical)])
        XCTAssertEqual(data.exerciseCatalogue.map(\.id), [first.id, second.id])
        XCTAssertEqual(data.plans[0].exercises.map(\.catalogueExerciseID), [first.id, second.id])
        XCTAssertNil(data.history[0].planSnapshot?.exercises[0].catalogueExerciseID)
        let decoded = try AppDataCodec.decode(AppDataCodec.encode(data))
        XCTAssertEqual(decoded.exerciseCatalogue, data.exerciseCatalogue)
        XCTAssertEqual(decoded.plans[0].exercises, data.plans[0].exercises)
    }

    func testDecodingLegacyJSONWithoutCatalogueMigratesLiveSteps() throws {
        let stepID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let json = """
        {
          "plans": [{
            "id": "00000000-0000-0000-0000-000000000002", "name": "Legacy",
            "warmUpSeconds": 0, "defaultWorkSeconds": 40, "defaultRecoverySeconds": 20,
            "roundRecoverySeconds": 0, "coolDownSeconds": 0, "roundCount": 1,
            "exercises": [{"id": "\(stepID.uuidString)", "name": " Push-up ", "duration": {"planDefault": {}}, "recovery": {"planDefault": {}}, "sideConfiguration": {"mode": "together", "firstSide": "left", "switchSeconds": 0}, "notes": ""}],
            "roundOverrides": [], "createdAt": "2023-11-14T22:13:20Z", "updatedAt": "2023-11-14T22:13:20Z"
          }], "history": [], "preferences": {}, "usage": {"trialStartedAt": null, "completedWorkoutDates": [], "purchasedUnlimited": false}, "selectedPlanID": null
        }
        """
        let data = try AppDataCodec.decode(Data(json.utf8))
        XCTAssertEqual(data.exerciseCatalogue.map(\.id), [stepID])
        XCTAssertEqual(data.plans[0].exercises[0].catalogueExerciseID, stepID)
        XCTAssertEqual(data.plans[0].exercises[0].name, "Push-up")
    }

    func testDecodingMissingRequiredAppDataFieldsStillFails() {
        XCTAssertThrowsError(try AppDataCodec.decode(Data("{}".utf8)))
        XCTAssertThrowsError(try AppDataCodec.decode(Data("{\"history\": [], \"preferences\": {}, \"usage\": {}}".utf8)))
    }

    func testSynchronizeUsesCanonicalNameAndPreservesConfiguration() {
        let id = UUID()
        let entry = CatalogueExercise(id: id, name: "Squat", tags: ["Legs"])
        let step = ExerciseStep(name: "Old label", duration: .custom(seconds: 12), recovery: .none, notes: "instance", catalogueExerciseID: id)
        let data = AppData(plans: [WorkoutPlan(name: "Plan", exercises: [step])], exerciseCatalogue: [entry])
        XCTAssertEqual(data.plans[0].exercises[0].name, "Squat")
        XCTAssertEqual(data.plans[0].exercises[0].duration, .custom(seconds: 12))
        XCTAssertEqual(data.plans[0].exercises[0].notes, "instance")
    }

    func testSaveNormalizesAndMergeRelinksLivePlansButNotHistory() throws {
        let target = CatalogueExercise(id: UUID(), name: "Push-up", bodyAreas: [" Arms "], tags: ["strength"])
        let source = CatalogueExercise(id: UUID(), name: "Press", bodyAreas: ["arms", "Chest"], tags: ["Strength", "floor"])
        let live = WorkoutPlan(name: "Live", exercises: [ExerciseStep(id: UUID(), name: "Press", duration: .custom(seconds: 10), catalogueExerciseID: source.id)])
        let past = WorkoutPlan(name: "Past", exercises: [ExerciseStep(name: "Press", catalogueExerciseID: source.id)])
        var data = AppData(plans: [live], history: [history(snapshot: past)], exerciseCatalogue: [target, source])
        try data.mergeCatalogueExercises(sourceIDs: [source.id], into: target.id)
        XCTAssertEqual(data.exerciseCatalogue.count, 1)
        XCTAssertEqual(data.exerciseCatalogue[0].bodyAreas, ["Arms", "Chest"])
        XCTAssertEqual(data.exerciseCatalogue[0].tags, ["strength", "floor"])
        XCTAssertEqual(data.plans[0].exercises[0].catalogueExerciseID, target.id)
        XCTAssertEqual(data.plans[0].exercises[0].duration, .custom(seconds: 10))
        XCTAssertEqual(data.history[0].planSnapshot?.exercises[0].catalogueExerciseID, source.id)
        XCTAssertThrowsError(try data.saveCatalogueExercise(CatalogueExercise(name: "  ")))
        XCTAssertThrowsError(try data.mergeCatalogueExercises(sourceIDs: [UUID()], into: target.id))
    }

    func testSaveNewEntryAndRenamePropagatesOnlyName() throws {
        let entry = CatalogueExercise(id: UUID(), name: "  Lunge  ", bodyAreas: [" Legs ", "legs"], tags: ["Strength", " strength "])
        let step = ExerciseStep(
            id: UUID(), name: "Lunge", duration: .custom(seconds: 17), recovery: .none,
            sideConfiguration: .leftRight(firstSide: .right, switchSeconds: 2), notes: "instance",
            catalogueExerciseID: entry.id
        )
        var data = AppData(
            plans: [WorkoutPlan(name: "Plan", exercises: [step])],
            exerciseCatalogue: [entry]
        )
        try data.saveCatalogueExercise(entry)
        XCTAssertEqual(data.exerciseCatalogue.last?.name, "Lunge")
        XCTAssertEqual(data.exerciseCatalogue.last?.bodyAreas, ["Legs"])
        XCTAssertEqual(data.exerciseCatalogue.last?.tags, ["Strength"])

        var renamed = data.exerciseCatalogue.last!
        renamed.name = "Reverse lunge"
        try data.saveCatalogueExercise(renamed)
        XCTAssertEqual(data.plans[0].exercises[0].name, "Reverse lunge")
        XCTAssertEqual(data.plans[0].exercises[0].duration, .custom(seconds: 17))
        XCTAssertEqual(data.plans[0].exercises[0].recovery, .none)
        XCTAssertEqual(data.plans[0].exercises[0].notes, "instance")
    }

    func testSaveInvalidConfigurationAndMergeFailuresAreAtomic() throws {
        let target = CatalogueExercise(id: UUID(), name: "Target")
        let source = CatalogueExercise(id: UUID(), name: "Source")
        var data = AppData(exerciseCatalogue: [target, source])
        let before = data
        let invalid = CatalogueExercise(name: "Split", duration: .custom(seconds: 1), sideConfiguration: .leftRight())
        XCTAssertThrowsError(try data.saveCatalogueExercise(invalid)) { error in
            XCTAssertEqual(error as? ExerciseCatalogueError, .invalidConfiguration("Exercise 1 needs at least two seconds for left/right mode."))
        }
        XCTAssertEqual(data, before)
        let unknown = UUID()
        XCTAssertThrowsError(try data.mergeCatalogueExercises(sourceIDs: [source.id], into: unknown)) { error in
            XCTAssertEqual(error as? ExerciseCatalogueError, .missingMergeTarget(unknown))
        }
        XCTAssertEqual(data, before)
        XCTAssertThrowsError(try data.mergeCatalogueExercises(sourceIDs: [unknown], into: target.id)) { error in
            XCTAssertEqual(error as? ExerciseCatalogueError, .missingExercise(unknown))
        }
        XCTAssertEqual(data, before)
    }

    func testCatalogueAndGenerationErrorsHaveHelpfulDescriptions() {
        XCTAssertEqual(ExerciseCatalogueError.emptyName.errorDescription, "Exercise name cannot be empty.")
        XCTAssertEqual(ExerciseCatalogueError.missingExercise(UUID()).errorDescription, "One or more exercises could not be found.")
        XCTAssertEqual(ExerciseCatalogueError.missingMergeTarget(UUID()).errorDescription, "The exercise to merge into could not be found.")
        XCTAssertEqual(ExerciseCatalogueError.invalidConfiguration("Bad template.").errorDescription, "Bad template.")
        XCTAssertEqual(WorkoutGenerationError.invalidExerciseCount.errorDescription, "Choose at least one exercise.")
        XCTAssertEqual(
            WorkoutGenerationError.insufficientEligibleExercises(available: 2, requested: 6).errorDescription,
            "Only 2 eligible exercises are available; 6 were requested."
        )
    }

    func testSynchronizeRepairsDanglingLinksAndIDCollisionsWithoutHistoryMutation() throws {
        let reusedID = UUID()
        let danglingID = UUID()
        let existing = CatalogueExercise(id: reusedID, name: "Existing")
        let first = ExerciseStep(id: reusedID, name: "First")
        let dangling = ExerciseStep(id: UUID(), name: " Dangling ", catalogueExerciseID: danglingID)
        let historical = WorkoutPlan(name: "Historical", exercises: [ExerciseStep(name: "unchanged")])
        let originalHistory = history(snapshot: historical)
        var data = AppData(
            plans: [WorkoutPlan(name: "Live", exercises: [first, dangling])],
            history: [originalHistory],
            exerciseCatalogue: [existing, existing]
        )
        XCTAssertNotEqual(data.plans[0].exercises[0].catalogueExerciseID, reusedID)
        XCTAssertNotEqual(data.plans[0].exercises[1].catalogueExerciseID, danglingID)
        XCTAssertEqual(data.plans[0].exercises[1].name, "Dangling")
        XCTAssertEqual(data.history, [originalHistory])
        let firstPass = try AppDataCodec.decode(AppDataCodec.encode(data))
        data.synchronizeExerciseCatalogue()
        XCTAssertEqual(data.plans[0].exercises, firstPass.plans[0].exercises)
        XCTAssertEqual(data.exerciseCatalogue, firstPass.exerciseCatalogue)
        XCTAssertEqual(data.history, [originalHistory])
    }

    func testGeneratorFiltersAlternatesAndCreatesLinkedUniqueSteps() throws {
        let catalogue = [
            CatalogueExercise(id: UUID(), name: "Arm 1", bodyAreas: ["arms"], tags: ["home", "recovery"]),
            CatalogueExercise(id: UUID(), name: "Arm 2", bodyAreas: ["arms"], tags: ["home"]),
            CatalogueExercise(id: UUID(), name: "Leg 1", bodyAreas: ["legs"], tags: [" home ", "recovery"]),
            CatalogueExercise(id: UUID(), name: "Leg 2", bodyAreas: ["legs"], tags: ["home", "recovery"]),
            CatalogueExercise(id: UUID(), name: "Skip", bodyAreas: ["back"], tags: ["home", "injured"]),
        ]
        var generator = SeededGenerator(state: 1)
        let options = WorkoutGenerationOptions(exerciseCount: 3, requiredTags: [" RECOVERY "], excludedTags: ["injured"])
        XCTAssertEqual(WorkoutGenerator.eligibleExercises(in: catalogue, options: options).count, 3)
        let plan = try WorkoutGenerator.generate(from: catalogue, options: options, using: &generator)
        XCTAssertEqual(plan.name, "Generated workout")
        XCTAssertEqual(Set(plan.exercises.map(\.catalogueExerciseID)).count, 3)
        let selectedAreas = plan.exercises.compactMap { step in
            catalogue.first(where: { $0.id == step.catalogueExerciseID })?.bodyAreas.first
        }
        XCTAssertTrue(selectedAreas.contains("arms"))
        XCTAssertTrue(selectedAreas.contains("legs"))
    }

    func testGeneratorErrorsForInvalidAndInsufficientCounts() {
        var generator = SeededGenerator(state: 0)
        XCTAssertThrowsError(try WorkoutGenerator.generate(from: [], options: WorkoutGenerationOptions(exerciseCount: 0), using: &generator))
        XCTAssertThrowsError(try WorkoutGenerator.generate(from: [], options: WorkoutGenerationOptions(exerciseCount: 1), using: &generator))
    }

    func testGeneratorUsesAllRequiredTagsAnyExcludedTagAndUniqueCatalogueIDs() throws {
        let duplicateID = UUID()
        let catalogue = [
            CatalogueExercise(id: duplicateID, name: "One", tags: [" Strength ", "Home"]),
            CatalogueExercise(id: duplicateID, name: "Duplicate", tags: ["strength", "home"]),
            CatalogueExercise(name: "Missing", tags: ["strength"]),
            CatalogueExercise(name: "Excluded", tags: ["strength", "home", "injured"]),
        ]
        let options = WorkoutGenerationOptions(exerciseCount: 1, requiredTags: ["home", " STRENGTH "], excludedTags: ["injured"])
        XCTAssertEqual(WorkoutGenerator.eligibleExercises(in: catalogue, options: options).map(\.name), ["One"])
        var generator = SeededGenerator(state: 7)
        XCTAssertEqual(try WorkoutGenerator.generate(from: catalogue, options: options, using: &generator).exercises[0].catalogueExerciseID, duplicateID)
    }

    func testGeneratorCarriesTemplateSettingsAndRepeatsTheSameOrderPerRound() throws {
        let catalogue = [
            CatalogueExercise(name: "A", duration: .custom(seconds: 11), recovery: .none, notes: "template"),
            CatalogueExercise(name: "B", duration: .custom(seconds: 12), recovery: .custom(seconds: 3)),
        ]
        var generator = SeededGenerator(state: 9)
        var plan = try WorkoutGenerator.generate(from: catalogue, options: WorkoutGenerationOptions(exerciseCount: 2, alternateBodyAreas: false), using: &generator)
        plan.roundCount = 2
        plan.warmUpSeconds = 0
        plan.roundRecoverySeconds = 0
        plan.coolDownSeconds = 0
        XCTAssertEqual(plan.exercises[0].notes, catalogue.first(where: { $0.id == plan.exercises[0].catalogueExerciseID })?.notes)
        let timeline = try WorkoutTimeline(plan: plan)
        XCTAssertEqual(timeline.phases.filter { $0.kind == .work }.map(\.title), plan.exercises.map(\.name) + plan.exercises.map(\.name))
    }

    func testGeneratorAllowsUnknownAreasAndSystemRandomOverload() throws {
        let catalogue = [
            CatalogueExercise(name: "Unknown A", bodyAreas: ["   "]),
            CatalogueExercise(name: "Unknown B"),
        ]
        let plan = try WorkoutGenerator.generate(from: catalogue, options: WorkoutGenerationOptions(exerciseCount: 2))
        XCTAssertEqual(plan.exercises.count, 2)
        XCTAssertEqual(Set(plan.exercises.map(\.catalogueExerciseID)).count, 2)
    }

    func testGeneratorAlternatesTenArmAndLegExercisesAcrossSeeds() throws {
        let arms = (0..<10).map { CatalogueExercise(name: "Arm \($0)", bodyAreas: ["arms"]) }
        let legs = (0..<10).map { CatalogueExercise(name: "Leg \($0)", bodyAreas: ["legs"]) }
        for seed in 0..<20 {
            var generator = SeededGenerator(state: UInt64(seed))
            let plan = try WorkoutGenerator.generate(
                from: arms + legs,
                options: WorkoutGenerationOptions(exerciseCount: 6),
                using: &generator
            )
            let areas = plan.exercises.map { step in
                (arms + legs).first(where: { $0.id == step.catalogueExerciseID })!.bodyAreas[0]
            }
            XCTAssertEqual(Set(plan.exercises.map(\.catalogueExerciseID)).count, 6)
            XCTAssertTrue(zip(areas, areas.dropFirst()).allSatisfy { $0 != $1 })
        }
    }

    private func history(snapshot: WorkoutPlan) -> WorkoutHistoryEntry {
        WorkoutHistoryEntry(planID: snapshot.id, planName: snapshot.name, startedAt: .distantPast, completedAt: .distantPast, plannedDurationSeconds: 1, elapsedDurationSeconds: 1, roundCount: 1, exerciseCount: 1, planSnapshot: snapshot)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 { state &+= 0x9E3779B97F4A7C15; return state }
}
