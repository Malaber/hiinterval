import XCTest
@testable import HiIntervalCore

final class CatalogueDeletionTests: XCTestCase {
    func testDeletingUsedExerciseRetainsLiveStepHistoryLabelsAndTombstoneAfterReload() throws {
        let exerciseID = UUID()
        let label = ExerciseLabel(name: "Legs", kind: .bodyArea)
        let catalogue = CatalogueExercise(id: exerciseID, name: "Squat", labelIDs: [label.id])
        let liveStep = ExerciseStep(
            id: UUID(),
            name: "Old squat name",
            duration: .custom(seconds: 33),
            recovery: .custom(seconds: 7),
            sideConfiguration: .leftRight(firstSide: .right, switchSeconds: 2),
            notes: "Keep knees aligned",
            catalogueExerciseID: exerciseID
        )
        let plan = WorkoutPlan(name: "Leg day", exercises: [liveStep])
        let historicalPlan = WorkoutPlan(name: "Completed", exercises: [ExerciseStep(name: "Historic squat", catalogueExerciseID: exerciseID)])
        let history = WorkoutHistoryEntry(
            planID: historicalPlan.id,
            planName: historicalPlan.name,
            startedAt: Date(timeIntervalSince1970: 10),
            completedAt: Date(timeIntervalSince1970: 20),
            plannedDurationSeconds: 30,
            elapsedDurationSeconds: 30,
            roundCount: 1,
            exerciseCount: 1,
            planSnapshot: historicalPlan
        )
        var data = AppData(
            plans: [plan],
            history: [history],
            exerciseCatalogue: [catalogue],
            exerciseLabels: [label]
        )
        let savedStep = data.plans[0].exercises[0]

        try data.deleteCatalogueExercise(id: exerciseID)

        XCTAssertTrue(data.exerciseCatalogue.isEmpty)
        XCTAssertEqual(data.deletedCatalogueExerciseIDs, [exerciseID])
        XCTAssertEqual(data.plans[0].exercises[0], savedStep)
        XCTAssertEqual(data.history[0], history)
        XCTAssertEqual(data.exerciseLabels, [label])

        let reloaded = try AppDataCodec.decode(AppDataCodec.encode(data))
        XCTAssertTrue(reloaded.exerciseCatalogue.isEmpty)
        XCTAssertEqual(reloaded.deletedCatalogueExerciseIDs, [exerciseID])
        XCTAssertEqual(reloaded.plans[0].exercises[0], savedStep)
        XCTAssertEqual(reloaded.history[0], history)
        XCTAssertEqual(reloaded.exerciseLabels, [label])
        XCTAssertThrowsError(
            try WorkoutGenerator.generate(
                from: reloaded.exerciseCatalogue,
                labels: reloaded.exerciseLabels,
                options: WorkoutGenerationOptions(exerciseCount: 1)
            )
        ) { error in
            XCTAssertEqual(error as? WorkoutGenerationError, .insufficientEligibleExercises(available: 0, requested: 1))
        }
    }

    func testDeletingUnusedExerciseDoesNotChangePlansOrLabels() throws {
        let unusedID = UUID()
        let label = ExerciseLabel(name: "Mobility", kind: .tag)
        let unused = CatalogueExercise(id: unusedID, name: "Ankle circles", labelIDs: [label.id])
        let plan = WorkoutPlan(name: "Plan", exercises: [ExerciseStep(name: "Keep")])
        var data = AppData(plans: [plan], exerciseCatalogue: [unused], exerciseLabels: [label])
        let savedPlan = data.plans[0]

        try data.deleteCatalogueExercise(id: unusedID)

        XCTAssertEqual(data.plans, [savedPlan])
        XCTAssertEqual(data.exerciseLabels, [label])
        XCTAssertTrue(data.exerciseCatalogue.allSatisfy { $0.id != unusedID })
        XCTAssertTrue(data.deletedCatalogueExerciseIDs.contains(unusedID))
    }

    func testDeletingMissingExerciseFailsWithoutMutation() {
        let saved = CatalogueExercise(name: "Push-up")
        var data = AppData(exerciseCatalogue: [saved])
        let original = data
        let missing = UUID()

        XCTAssertThrowsError(try data.deleteCatalogueExercise(id: missing)) { error in
            XCTAssertEqual(error as? ExerciseCatalogueError, .missingExercise(missing))
        }
        XCTAssertEqual(data, original)
    }

    func testSavingExplicitRecordWithDeletedIDRestoresItAndClearsTombstone() throws {
        let id = UUID()
        var data = AppData(exerciseCatalogue: [CatalogueExercise(id: id, name: "Old")])
        try data.deleteCatalogueExercise(id: id)
        try data.saveCatalogueExercise(CatalogueExercise(id: id, name: "Restored"))

        XCTAssertEqual(data.exerciseCatalogue.map(\.name), ["Restored"])
        XCTAssertFalse(data.deletedCatalogueExerciseIDs.contains(id))
    }

    func testLegacyPayloadWithoutDeletedIDsDecodesWithEmptyTombstones() throws {
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
          "exerciseCatalogue": [],
          "exerciseLabels": []
        }
        """

        XCTAssertTrue(try AppDataCodec.decode(Data(json.utf8)).deletedCatalogueExerciseIDs.isEmpty)
    }
}
