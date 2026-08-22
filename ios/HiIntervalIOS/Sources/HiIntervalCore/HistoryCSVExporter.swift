import Foundation

public enum HistoryCSVExporter {
    public static func csv(entries: [WorkoutHistoryEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        let header = "completed_at,plan,duration_seconds,rounds,exercises"
        let rows = entries.map { entry in
            [
                formatter.string(from: entry.completedAt),
                escaped(entry.planName),
                String(entry.elapsedDurationSeconds),
                String(entry.roundCount),
                String(entry.exerciseCount),
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func escaped(_ value: String) -> String {
        let spreadsheetSafeValue: String
        if let first = value.first, "=+-@\t\r".contains(first) {
            spreadsheetSafeValue = "'\(value)"
        } else {
            spreadsheetSafeValue = value
        }
        return "\"\(spreadsheetSafeValue.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
