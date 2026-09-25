import XCTest
@testable import HiIntervalCore

final class WorkoutReshuffleTests: XCTestCase {
    func testReplacesExercisesPreservesEverythingElseAndRoundOrder() throws {
        let old = CatalogueExercise(name: "Old")
        let fresh = [CatalogueExercise(name: "Squat"), CatalogueExercise(name: "Plank")]
        let plan = WorkoutPlan(name: "Keep", warmUpSeconds: 17, warmUpNotes: "Warm",
            defaultWorkSeconds: 23, defaultRecoverySeconds: 9, recoveryNotes: "Rest",
            roundRecoverySeconds: 18, roundRecoveryNotes: "Round", coolDownSeconds: 12,
            coolDownNotes: "Cool", roundCount: 2, exercises: [old.makeStep()],
            roundOverrides: [WorkoutRoundOverride(roundNumber: 2, workSeconds: 27)],
            logo: WorkoutLogo(symbolName: "heart.fill"))
        var rng = SeededRandom()
        let options = WorkoutGenerationOptions(exerciseCount: 2)
        let result = try WorkoutGenerator.replacingExercises(in: plan, from: [old] + fresh,
            labels: [], options: options, using: &rng)
        XCTAssertEqual(Set(result.exercises.compactMap(\.catalogueExerciseID)), Set(fresh.map(\.id)))
        var restored = result
        restored.exercises = plan.exercises
        restored.generationOptions = plan.generationOptions
        XCTAssertEqual(restored, plan)
        let phases = try WorkoutTimeline(plan: result).phases.filter { $0.kind == .work }
        XCTAssertEqual(Array(phases.prefix(2).map(\.title)), Array(phases.suffix(2).map(\.title)))
        let decoded = try AppDataCodec.decode(AppDataCodec.encode(AppData(plans: [result])))
        XCTAssertEqual(decoded.plans[0].generationOptions, options)
    }

    func testReusesOnlyWhenNeededAndRejectsInsufficientMatches() throws {
        let old = CatalogueExercise(name: "Old")
        let fresh = CatalogueExercise(name: "Fresh")
        let plan = WorkoutPlan(name: "Keep", exercises: [old.makeStep()])
        var rng = SeededRandom()
        let options = WorkoutGenerationOptions(exerciseCount: 2)
        let result = try WorkoutGenerator.replacingExercises(in: plan, from: [old, fresh],
            labels: [], options: options, using: &rng)
        XCTAssertEqual(Set(result.exercises.compactMap(\.catalogueExerciseID)), [old.id, fresh.id])
        XCTAssertThrowsError(try WorkoutGenerator.replacingExercises(in: plan, from: [old],
            labels: [], options: options, using: &rng))
    }

    func testGeneratorOptionsSurviveCodecAndOldPlanDefaultsToNone() throws {
        let tag = ExerciseLabel(name: "Recovery", kind: .tag)
        let exercise = CatalogueExercise(name: "Heel raise", labelIDs: [tag.id])
        let options = WorkoutGenerationOptions(exerciseCount: 1, requiredTagIDs: [tag.id], alternateBodyAreas: false)
        var rng = SeededRandom()
        let generated = try WorkoutGenerator.generate(from: [exercise], labels: [tag], options: options, using: &rng)
        let encoded = try AppDataCodec.encode(AppData(plans: [generated], exerciseCatalogue: [exercise], exerciseLabels: [tag]))
        XCTAssertEqual(try AppDataCodec.decode(encoded).plans[0].generationOptions, options)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var plans = try XCTUnwrap(json["plans"] as? [[String: Any]])
        plans[0].removeValue(forKey: "generationOptions")
        json["plans"] = plans
        XCTAssertNil(try AppDataCodec.decode(JSONSerialization.data(withJSONObject: json)).plans[0].generationOptions)
    }
}

private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64 = 42
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
