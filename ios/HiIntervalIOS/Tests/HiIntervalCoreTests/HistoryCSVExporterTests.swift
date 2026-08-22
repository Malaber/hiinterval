import XCTest
@testable import HiIntervalCore

final class HistoryCSVExporterTests: XCTestCase {
    func testExportsStableHeaderValuesAndEscapedPlanName() {
        let entry = WorkoutHistoryEntry(
            planID: UUID(),
            planName: "Power, \"Left + Right\"",
            startedAt: Date(timeIntervalSince1970: 0),
            completedAt: Date(timeIntervalSince1970: 60),
            plannedDurationSeconds: 75,
            elapsedDurationSeconds: 60,
            roundCount: 3,
            exerciseCount: 4
        )

        XCTAssertEqual(
            HistoryCSVExporter.csv(entries: [entry]),
            "completed_at,plan,duration_seconds,rounds,exercises\n"
                + "1970-01-01T00:01:00Z,\"Power, \"\"Left + Right\"\"\",60,3,4"
        )
    }

    func testEmptyHistoryExportsHeaderOnly() {
        XCTAssertEqual(
            HistoryCSVExporter.csv(entries: []),
            "completed_at,plan,duration_seconds,rounds,exercises"
        )
    }

    func testSpreadsheetFormulaPrefixesAreNeutralized() {
        let names = ["=1+1", "+SUM(A1)", "-2+3", "@SUM(A1)", "\tcommand", "\rcommand"]
        let entries = names.enumerated().map { index, name in
            WorkoutHistoryEntry(
                planID: UUID(),
                planName: name,
                startedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                completedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                plannedDurationSeconds: 1,
                elapsedDurationSeconds: 1,
                roundCount: 1,
                exerciseCount: 1
            )
        }

        let csv = HistoryCSVExporter.csv(entries: entries)
        for name in names {
            XCTAssertTrue(csv.contains("\"'\(name)\""))
        }
    }
}
