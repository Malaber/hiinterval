import XCTest
@testable import HiIntervalCore

final class ExerciseCatalogueTests: XCTestCase {
    func testLabelNormalizesWhitespaceCaseAndDiacritics() {
        let label = ExerciseLabel(name: "  Achílles\n Recovery  ", kind: .tag).normalized()
        XCTAssertEqual(label.name, "Achílles Recovery")
        XCTAssertEqual(ExerciseLabel.normalizedName(label.name), "achilles recovery")
    }

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

    func testDecoding040PayloadCreatesSharedLabelsAndModernRoundTripDropsTerms() throws {
        let exerciseID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let json = """
        {
          "plans": [],
          "history": [],
          "preferences": {},
          "usage": {
            "trialStartedAt": null,
            "completedWorkoutDates": [],
            "purchasedUnlimited": false
          },
          "selectedPlanID": null,
          "exerciseCatalogue": [{
            "id": "\(exerciseID.uuidString)",
            "name": " Squat ",
            "bodyAreas": [" Legs ", "legs"],
            "tags": ["Strength", " strength "],
            "duration": {"planDefault": {}},
            "recovery": {"planDefault": {}},
            "sideConfiguration": {"mode": "together", "firstSide": "left", "switchSeconds": 0},
            "notes": ""
          }]
        }
        """
        let data = try AppDataCodec.decode(Data(json.utf8))
        XCTAssertEqual(data.exerciseCatalogue[0].name, "Squat")
        XCTAssertEqual(data.exerciseLabels.map(\.name), ["Legs", "Strength"])
        XCTAssertEqual(data.exerciseLabels.map(\.kind), [.bodyArea, .tag])
        XCTAssertEqual(data.labels(for: data.exerciseCatalogue[0]).map(\.name), ["Legs", "Strength"])
        let encoded = String(decoding: try AppDataCodec.encode(data), as: UTF8.self)
        XCTAssertFalse(encoded.contains("bodyAreas"))
        XCTAssertFalse(encoded.contains("\"tags\""))
        XCTAssertTrue(encoded.contains("labelIDs"))
        XCTAssertEqual(try AppDataCodec.decode(Data(encoded.utf8)), data)
    }

    func testDecodingLegacyJSONWithoutCatalogueMigratesLiveSteps() throws {
        let stepID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let json = """
        {
          "plans": [{
            "id": "00000000-0000-0000-0000-000000000002",
            "name": "Legacy",
            "warmUpSeconds": 0,
            "defaultWorkSeconds": 40,
            "defaultRecoverySeconds": 20,
            "roundRecoverySeconds": 0,
            "coolDownSeconds": 0,
            "roundCount": 1,
            "exercises": [{
              "id": "\(stepID.uuidString)",
              "name": " Push-up ",
              "duration": {"planDefault": {}},
              "recovery": {"planDefault": {}},
              "sideConfiguration": {"mode": "together", "firstSide": "left", "switchSeconds": 0},
              "notes": ""
            }],
            "roundOverrides": [],
            "createdAt": "2023-11-14T22:13:20Z",
            "updatedAt": "2023-11-14T22:13:20Z"
          }],
          "history": [],
          "preferences": {},
          "usage": {
            "trialStartedAt": null,
            "completedWorkoutDates": [],
            "purchasedUnlimited": false
          },
          "selectedPlanID": null
        }
        """
        let data = try AppDataCodec.decode(Data(json.utf8))
        XCTAssertEqual(data.exerciseCatalogue.map(\.id), [stepID])
        XCTAssertEqual(data.plans[0].exercises[0].catalogueExerciseID, stepID)
        XCTAssertEqual(data.plans[0].exercises[0].name, "Push-up")
        XCTAssertTrue(data.exerciseLabels.isEmpty)
    }

    func testSynchronizeUsesCanonicalNameAndPreservesStepConfiguration() {
        let id = UUID()
        let legs = ExerciseLabel(name: "Legs", kind: .bodyArea)
        let entry = CatalogueExercise(id: id, name: "Squat", labelIDs: [legs.id])
        let step = ExerciseStep(
            name: "Old label",
            duration: .custom(seconds: 12),
            recovery: .none,
            sideConfiguration: .leftRight(firstSide: .right, switchSeconds: 2),
            notes: "instance",
            catalogueExerciseID: id
        )

        let data = AppData(
            plans: [WorkoutPlan(name: "Plan", exercises: [step])],
            exerciseCatalogue: [entry],
            exerciseLabels: [legs]
        )

        XCTAssertEqual(data.plans[0].exercises[0].name, "Squat")
        XCTAssertEqual(data.plans[0].exercises[0].duration, .custom(seconds: 12))
        XCTAssertEqual(data.plans[0].exercises[0].recovery, .none)
        XCTAssertEqual(data.plans[0].exercises[0].sideConfiguration, .leftRight(firstSide: .right, switchSeconds: 2))
        XCTAssertEqual(data.plans[0].exercises[0].notes, "instance")
    }

    func testDecodingMissingRequiredAppDataFieldsStillFails() {
        XCTAssertThrowsError(try AppDataCodec.decode(Data("{}".utf8)))
        XCTAssertThrowsError(try AppDataCodec.decode(Data("{\"history\": [], \"preferences\": {}, \"usage\": {}}".utf8)))
    }

    func testSharedLabelsDeduplicateReferencesAndUnusedLabelsRemainAvailable() {
        let legs = ExerciseLabel(name: "Legs", kind: .bodyArea)
        let duplicateLegs = ExerciseLabel(name: " legs ", kind: .bodyArea)
        let futureTag = ExerciseLabel(name: "Achilles recovery", kind: .tag)
        let first = CatalogueExercise(name: "Lunge", labelIDs: [legs.id, duplicateLegs.id, UUID()])
        let second = CatalogueExercise(name: "Squat", labelIDs: [duplicateLegs.id])
        let data = AppData(exerciseCatalogue: [first, second], exerciseLabels: [legs, duplicateLegs, futureTag])
        XCTAssertEqual(data.exerciseLabels.count, 2)
        XCTAssertEqual(data.exerciseCatalogue[0].labelIDs, [legs.id])
        XCTAssertEqual(data.exerciseCatalogue[1].labelIDs, [legs.id])
        XCTAssertEqual(data.exerciseLabels.last?.id, futureTag.id)
    }

    func testLabelNormalizationKeepsFirstValidUUIDRecordAndRemovesMalformedReferences() {
        let sharedID = UUID()
        let blankID = UUID()
        let first = ExerciseLabel(id: sharedID, name: "Legs", kind: .bodyArea)
        let duplicateName = ExerciseLabel(id: UUID(), name: " legs ", kind: .bodyArea)
        let collidingLater = ExerciseLabel(id: sharedID, name: "Recovery", kind: .tag)
        let blank = ExerciseLabel(id: blankID, name: " \n ", kind: .tag)
        let exercise = CatalogueExercise(
            name: "Lunge",
            labelIDs: [duplicateName.id, sharedID, blankID, UUID(), sharedID]
        )

        let data = AppData(
            exerciseCatalogue: [exercise],
            exerciseLabels: [first, duplicateName, collidingLater, blank]
        )

        XCTAssertEqual(data.exerciseLabels, [first])
        XCTAssertEqual(data.exerciseCatalogue[0].labelIDs, [sharedID])
        XCTAssertEqual(data.labels(for: data.exerciseCatalogue[0], kind: .bodyArea), [first])
        XCTAssertTrue(data.labels(for: data.exerciseCatalogue[0], kind: .tag).isEmpty)
    }

    func testSaveNewLabelsReusesCanonicalDefinitionsAndDetachRetainsCatalogueRecord() throws {
        let existing = ExerciseLabel(name: "Legs", kind: .bodyArea)
        let draft = ExerciseLabel(name: " legs ", kind: .bodyArea)
        let entry = CatalogueExercise(name: "Lunge", labelIDs: [draft.id])
        var data = AppData(exerciseLabels: [existing])
        try data.saveCatalogueExercise(entry, labels: [draft])
        XCTAssertEqual(data.exerciseLabels, [existing])
        XCTAssertEqual(data.exerciseCatalogue[0].labelIDs, [existing.id])

        var detached = data.exerciseCatalogue[0]
        detached.labelIDs = []
        try data.saveCatalogueExercise(detached)
        XCTAssertEqual(data.exerciseCatalogue[0].labelIDs, [])
        XCTAssertEqual(data.exerciseLabels, [existing])
    }

    func testSaveDeduplicatesSeparateDraftIDsThatResolveToSameLabel() throws {
        let existing = ExerciseLabel(name: "Legs", kind: .bodyArea)
        let firstDraft = ExerciseLabel(name: "legs", kind: .bodyArea)
        let secondDraft = ExerciseLabel(name: " LEGS ", kind: .bodyArea)
        let entry = CatalogueExercise(name: "Squat", labelIDs: [firstDraft.id, secondDraft.id])
        var data = AppData(exerciseLabels: [existing])
        try data.saveCatalogueExercise(entry, labels: [firstDraft, secondDraft])
        XCTAssertEqual(data.exerciseCatalogue[0].labelIDs, [existing.id])
        XCTAssertEqual(data.exerciseLabels, [existing])
    }

    func testSaveKeepsFirstDraftWhenMalformedDraftUUIDIsReused() throws {
        let sharedID = UUID()
        let first = ExerciseLabel(id: sharedID, name: "Legs", kind: .bodyArea)
        let later = ExerciseLabel(id: sharedID, name: "Recovery", kind: .tag)
        let entry = CatalogueExercise(name: "Lunge", labelIDs: [sharedID])
        var data = AppData()

        try data.saveCatalogueExercise(entry, labels: [first, later])

        XCTAssertEqual(data.exerciseLabels, [first])
        XCTAssertEqual(data.exerciseCatalogue[0].labelIDs, [sharedID])
    }

    func testSaveValidatesBeforeCreatingDraftLabelsAndRenamePropagatesOnlyName() throws {
        let draft = ExerciseLabel(name: "Arms", kind: .bodyArea)
        var data = AppData()
        let invalid = CatalogueExercise(name: "Split", labelIDs: [draft.id], duration: .custom(seconds: 1), sideConfiguration: .leftRight())
        XCTAssertThrowsError(try data.saveCatalogueExercise(invalid, labels: [draft])) { error in
            XCTAssertEqual(error as? ExerciseCatalogueError, .invalidConfiguration("Exercise 1 needs at least two seconds for left/right mode."))
        }
        XCTAssertTrue(data.exerciseLabels.isEmpty)
        XCTAssertTrue(data.exerciseCatalogue.isEmpty)

        let entry = CatalogueExercise(name: "Lunge", labelIDs: [draft.id])
        let step = ExerciseStep(
            name: "Lunge",
            duration: .custom(seconds: 17),
            recovery: .none,
            sideConfiguration: .leftRight(firstSide: .right, switchSeconds: 2),
            notes: "instance",
            catalogueExerciseID: entry.id
        )
        data = AppData(plans: [WorkoutPlan(name: "Plan", exercises: [step])], exerciseCatalogue: [entry])
        try data.saveCatalogueExercise(entry, labels: [draft])
        var renamed = data.exerciseCatalogue.first(where: { $0.id == entry.id })!
        renamed.name = "Reverse lunge"
        try data.saveCatalogueExercise(renamed)
        XCTAssertEqual(data.plans[0].exercises[0].name, "Reverse lunge")
        XCTAssertEqual(data.plans[0].exercises[0].duration, .custom(seconds: 17))
        XCTAssertEqual(data.plans[0].exercises[0].recovery, .none)
        XCTAssertEqual(data.plans[0].exercises[0].sideConfiguration, .leftRight(firstSide: .right, switchSeconds: 2))
        XCTAssertEqual(data.plans[0].exercises[0].notes, "instance")
    }

    func testFailedSaveDoesNotMutateExistingLabelsOrCatalogue() {
        let existing = ExerciseLabel(name: "Legs", kind: .bodyArea)
        let saved = CatalogueExercise(name: "Lunge", labelIDs: [existing.id])
        let draft = ExerciseLabel(name: "Arms", kind: .bodyArea)
        let invalid = CatalogueExercise(
            name: "Split",
            labelIDs: [draft.id],
            duration: .custom(seconds: 1),
            sideConfiguration: .leftRight()
        )
        var data = AppData(exerciseCatalogue: [saved], exerciseLabels: [existing])
        let before = data

        XCTAssertThrowsError(try data.saveCatalogueExercise(invalid, labels: [draft]))
        XCTAssertEqual(data, before)
    }

    func testMergeUnionsLabelsRelinksLivePlansAndPreservesHistory() throws {
        let arms = ExerciseLabel(name: "Arms", kind: .bodyArea)
        let strength = ExerciseLabel(name: "Strength", kind: .tag)
        let floor = ExerciseLabel(name: "Floor", kind: .tag)
        let target = CatalogueExercise(id: UUID(), name: "Push-up", labelIDs: [arms.id, strength.id])
        let source = CatalogueExercise(id: UUID(), name: "Press", labelIDs: [strength.id, floor.id])
        let live = WorkoutPlan(name: "Live", exercises: [ExerciseStep(name: "Press", duration: .custom(seconds: 10), catalogueExerciseID: source.id)])
        let past = WorkoutPlan(name: "Past", exercises: [ExerciseStep(name: "Press", catalogueExerciseID: source.id)])
        var data = AppData(plans: [live], history: [history(snapshot: past)], exerciseCatalogue: [target, source], exerciseLabels: [arms, strength, floor])
        try data.mergeCatalogueExercises(sourceIDs: [source.id], into: target.id)
        XCTAssertEqual(data.exerciseCatalogue.count, 1)
        XCTAssertEqual(data.exerciseCatalogue[0].labelIDs, [arms.id, strength.id, floor.id])
        XCTAssertEqual(data.plans[0].exercises[0].catalogueExerciseID, target.id)
        XCTAssertEqual(data.plans[0].exercises[0].duration, .custom(seconds: 10))
        XCTAssertEqual(data.history[0].planSnapshot?.exercises[0].catalogueExerciseID, source.id)
        XCTAssertEqual(data.exerciseLabels.count, 3)
    }

    func testMergeFailuresAreAtomic() throws {
        let target = CatalogueExercise(name: "Target")
        let source = CatalogueExercise(name: "Source")
        var data = AppData(exerciseCatalogue: [target, source])
        let before = data
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

    func testSynchronizeRepairsDanglingLinksAndIDCollisionsWithoutHistoryMutation() throws {
        let reusedID = UUID()
        let danglingID = UUID()
        let existing = CatalogueExercise(id: reusedID, name: "Existing")
        let first = ExerciseStep(id: reusedID, name: "First")
        let dangling = ExerciseStep(id: UUID(), name: " Dangling ", catalogueExerciseID: danglingID)
        let historical = WorkoutPlan(name: "Historical", exercises: [ExerciseStep(name: "unchanged")])
        let originalHistory = history(snapshot: historical)
        var data = AppData(plans: [WorkoutPlan(name: "Live", exercises: [first, dangling])], history: [originalHistory], exerciseCatalogue: [existing, existing])
        XCTAssertNotEqual(data.plans[0].exercises[0].catalogueExerciseID, reusedID)
        XCTAssertNotEqual(data.plans[0].exercises[1].catalogueExerciseID, danglingID)
        XCTAssertEqual(data.plans[0].exercises[1].name, "Dangling")
        let firstPass = try AppDataCodec.decode(AppDataCodec.encode(data))
        data.synchronizeExerciseCatalogue()
        XCTAssertEqual(data.plans[0].exercises, firstPass.plans[0].exercises)
        XCTAssertEqual(data.exerciseCatalogue, firstPass.exerciseCatalogue)
        XCTAssertEqual(data.history, [originalHistory])
    }

    func testGeneratorFiltersTagIDsAlternatesBodyAreasAndCreatesLinkedUniqueSteps() throws {
        let arms = ExerciseLabel(name: "Arms", kind: .bodyArea)
        let legs = ExerciseLabel(name: "Legs", kind: .bodyArea)
        let back = ExerciseLabel(name: "Back", kind: .bodyArea)
        let home = ExerciseLabel(name: "Home", kind: .tag)
        let recovery = ExerciseLabel(name: "Recovery", kind: .tag)
        let injured = ExerciseLabel(name: "Injured", kind: .tag)
        let impact = ExerciseLabel(name: "High impact", kind: .tag)
        let labels = [arms, legs, back, home, recovery, injured, impact]
        let catalogue = [
            CatalogueExercise(name: "Arm 1", labelIDs: [arms.id, home.id, recovery.id]),
            CatalogueExercise(name: "Arm 2", labelIDs: [arms.id, home.id]),
            CatalogueExercise(name: "Leg 1", labelIDs: [legs.id, home.id, recovery.id]),
            CatalogueExercise(name: "Leg 2", labelIDs: [legs.id, home.id, recovery.id]),
            CatalogueExercise(name: "Skip", labelIDs: [back.id, home.id, recovery.id, injured.id]),
        ]
        var generator = SeededGenerator(state: 1)
        let options = WorkoutGenerationOptions(
            exerciseCount: 3,
            requiredTagIDs: [home.id, recovery.id],
            excludedTagIDs: [injured.id, impact.id]
        )
        XCTAssertEqual(
            WorkoutGenerator.eligibleExercises(in: catalogue, labels: labels, options: options).map(\.name),
            ["Arm 1", "Leg 1", "Leg 2"]
        )
        let plan = try WorkoutGenerator.generate(from: catalogue, labels: labels, options: options, using: &generator)
        XCTAssertEqual(plan.name, "Generated workout")
        XCTAssertEqual(Set(plan.exercises.map(\.catalogueExerciseID)).count, 3)
    }

    func testGeneratorUsesTagKindsAndUnknownTagIDsDoNotMatch() throws {
        let bodyArea = ExerciseLabel(name: "Strength", kind: .bodyArea)
        let tag = ExerciseLabel(name: "Strength", kind: .tag)
        let duplicateID = UUID()
        let catalogue = [
            CatalogueExercise(id: duplicateID, name: "One", labelIDs: [tag.id]),
            CatalogueExercise(id: duplicateID, name: "Duplicate", labelIDs: [tag.id]),
            CatalogueExercise(name: "Wrong kind", labelIDs: [bodyArea.id]),
        ]
        let options = WorkoutGenerationOptions(exerciseCount: 1, requiredTagIDs: [tag.id, UUID()])
        XCTAssertTrue(WorkoutGenerator.eligibleExercises(in: catalogue, labels: [bodyArea, tag], options: options).isEmpty)
        let matching = WorkoutGenerationOptions(exerciseCount: 1, requiredTagIDs: [tag.id])
        XCTAssertEqual(WorkoutGenerator.eligibleExercises(in: catalogue, labels: [bodyArea, tag], options: matching).map(\.name), ["One"])
        var generator = SeededGenerator(state: 7)
        XCTAssertEqual(try WorkoutGenerator.generate(from: catalogue, labels: [bodyArea, tag], options: matching, using: &generator).exercises[0].catalogueExerciseID, duplicateID)
    }

    func testGeneratorCarriesTemplatesRepeatsOrderAndAlternatesAcrossSeeds() throws {
        let arms = ExerciseLabel(name: "Arms", kind: .bodyArea)
        let legs = ExerciseLabel(name: "Legs", kind: .bodyArea)
        let templates = [
            CatalogueExercise(name: "A", labelIDs: [arms.id], duration: .custom(seconds: 11), recovery: .none, notes: "template"),
            CatalogueExercise(name: "B", labelIDs: [legs.id], duration: .custom(seconds: 12), recovery: .custom(seconds: 3)),
        ]
        var generator = SeededGenerator(state: 9)
        var plan = try WorkoutGenerator.generate(from: templates, labels: [arms, legs], options: WorkoutGenerationOptions(exerciseCount: 2), using: &generator)
        plan.roundCount = 2
        plan.warmUpSeconds = 0
        plan.roundRecoverySeconds = 0
        plan.coolDownSeconds = 0
        XCTAssertEqual(plan.exercises[0].notes, templates.first(where: { $0.id == plan.exercises[0].catalogueExerciseID })?.notes)
        let timeline = try WorkoutTimeline(plan: plan)
        XCTAssertEqual(timeline.phases.filter { $0.kind == .work }.map(\.title), plan.exercises.map(\.name) + plan.exercises.map(\.name))

        let armExercises = (0..<10).map { CatalogueExercise(name: "Arm \($0)", labelIDs: [arms.id]) }
        let legExercises = (0..<10).map { CatalogueExercise(name: "Leg \($0)", labelIDs: [legs.id]) }
        for seed in 0..<20 {
            var random = SeededGenerator(state: UInt64(seed))
            let generated = try WorkoutGenerator.generate(from: armExercises + legExercises, labels: [arms, legs], options: WorkoutGenerationOptions(exerciseCount: 6), using: &random)
            let areas = generated.exercises.map { step in
                (armExercises + legExercises).first(where: { $0.id == step.catalogueExerciseID })!.labelIDs[0]
            }
            XCTAssertEqual(Set(generated.exercises.map(\.catalogueExerciseID)).count, 6)
            XCTAssertTrue(zip(areas, areas.dropFirst()).allSatisfy { $0 != $1 })
        }
    }

    func testGeneratorAllowsSameAreaWhenAlternationDisabled() throws {
        let arms = ExerciseLabel(name: "Arms", kind: .bodyArea)
        let catalogue = [
            CatalogueExercise(name: "Arm 1", labelIDs: [arms.id]),
            CatalogueExercise(name: "Arm 2", labelIDs: [arms.id]),
        ]
        var generator = SeededGenerator(state: 3)
        let plan = try WorkoutGenerator.generate(
            from: catalogue,
            labels: [arms],
            options: WorkoutGenerationOptions(exerciseCount: 2, alternateBodyAreas: false),
            using: &generator
        )

        XCTAssertEqual(Set(plan.exercises.map(\.catalogueExerciseID)), Set(catalogue.map(\.id)))
    }

    func testGeneratorErrorsAndSystemRandomOverload() throws {
        var generator = SeededGenerator(state: 0)
        XCTAssertThrowsError(try WorkoutGenerator.generate(from: [], labels: [], options: WorkoutGenerationOptions(exerciseCount: 0), using: &generator))
        XCTAssertThrowsError(try WorkoutGenerator.generate(from: [], labels: [], options: WorkoutGenerationOptions(exerciseCount: 1), using: &generator))
        let plan = try WorkoutGenerator.generate(from: [CatalogueExercise(name: "Unknown A"), CatalogueExercise(name: "Unknown B")], labels: [], options: WorkoutGenerationOptions(exerciseCount: 2))
        XCTAssertEqual(plan.exercises.count, 2)
    }

    func testCatalogueAndGenerationErrorsDescribeUserActions() {
        XCTAssertEqual(ExerciseCatalogueError.emptyName.errorDescription, "Exercise name cannot be empty.")
        XCTAssertEqual(ExerciseCatalogueError.missingExercise(UUID()).errorDescription, "One or more exercises could not be found.")
        XCTAssertEqual(ExerciseCatalogueError.missingMergeTarget(UUID()).errorDescription, "The exercise to merge into could not be found.")
        XCTAssertEqual(ExerciseCatalogueError.invalidConfiguration("Invalid template.").errorDescription, "Invalid template.")
        XCTAssertEqual(WorkoutGenerationError.invalidExerciseCount.errorDescription, "Choose at least one exercise.")
        XCTAssertEqual(
            WorkoutGenerationError.insufficientEligibleExercises(available: 2, requested: 6).errorDescription,
            "Only 2 eligible exercises are available; 6 were requested."
        )
    }

    private func history(snapshot: WorkoutPlan) -> WorkoutHistoryEntry {
        WorkoutHistoryEntry(planID: snapshot.id, planName: snapshot.name, startedAt: .distantPast, completedAt: .distantPast, plannedDurationSeconds: 1, elapsedDurationSeconds: 1, roundCount: 1, exerciseCount: 1, planSnapshot: snapshot)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 { state &+= 0x9E3779B97F4A7C15; return state }
}
