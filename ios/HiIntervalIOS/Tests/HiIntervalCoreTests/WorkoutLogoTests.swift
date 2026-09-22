import XCTest
@testable import HiIntervalCore

final class WorkoutLogoTests: XCTestCase {
    func testPlanRoundTripsCustomLogo() throws {
        let logo = WorkoutLogo(
            symbolName: "flame.fill",
            symbolColor: WorkoutLogoColor(red: 1, green: 0.4, blue: 0.1),
            backgroundColor: WorkoutLogoColor(red: 0.1, green: 0.2, blue: 0.3),
            photoFilename: "c0c1b6f4-4e67-4e62-90b4-cb80b7b81d29.jpg"
        )
        let plan = WorkoutPlan(name: "Power", exercises: [ExerciseStep(name: "Burpees")], logo: logo)

        let decoded = try JSONDecoder().decode(WorkoutPlan.self, from: JSONEncoder().encode(plan))

        XCTAssertEqual(decoded.logo, logo)
    }

    func testPlanWithoutLogoDecodesToDefault() throws {
        let plan = WorkoutPlan(name: "Legacy", exercises: [ExerciseStep(name: "Squats")])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        object.removeValue(forKey: "logo")
        let legacy = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(WorkoutPlan.self, from: legacy)

        XCTAssertEqual(decoded.logo, .default)
    }

    func testHistorySnapshotRetainsLogoDescription() throws {
        let logo = WorkoutLogo(symbolName: "bolt.fill", photoFilename: "cf74c09c-dc83-49ee-af5d-00fe5320b22a.jpg")
        let plan = WorkoutPlan(name: "Intervals", exercises: [ExerciseStep(name: "Sprints")], logo: logo)
        let entry = WorkoutHistoryEntry(
            planID: plan.id,
            planName: plan.name,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_060),
            plannedDurationSeconds: 60,
            elapsedDurationSeconds: 60,
            roundCount: 1,
            exerciseCount: 1,
            planSnapshot: plan
        )

        let decoded = try JSONDecoder().decode(WorkoutHistoryEntry.self, from: JSONEncoder().encode(entry))

        XCTAssertEqual(decoded.planSnapshot?.logo, logo)
    }

    func testLogoColorClampsDecodedValues() throws {
        let color = try JSONDecoder().decode(
            WorkoutLogoColor.self,
            from: Data(#"{"red":2,"green":-1,"blue":0.25,"opacity":4}"#.utf8)
        )

        XCTAssertEqual(color, WorkoutLogoColor(red: 1, green: 0, blue: 0.25, opacity: 1))
    }
}
