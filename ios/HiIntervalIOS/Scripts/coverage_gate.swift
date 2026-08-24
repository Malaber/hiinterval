import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: coverage_gate.swift <coverage.json> <minimum-percent>\n", stderr)
    exit(2)
}

let coverageURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let minimum = Double(CommandLine.arguments[2]) else {
    fputs("minimum-percent must be numeric\n", stderr)
    exit(2)
}

let data = try Data(contentsOf: coverageURL)
guard
    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    let reports = root["data"] as? [[String: Any]],
    let report = reports.first,
    let files = report["files"] as? [[String: Any]]
else {
    fputs("llvm-cov JSON has unexpected structure\n", stderr)
    exit(2)
}

let sourceMarker = "/Sources/HiIntervalCore/"
var coveredLines = 0
var totalLines = 0

for file in files where (file["filename"] as? String)?.contains(sourceMarker) == true {
    guard
        let summary = file["summary"] as? [String: Any],
        let lines = summary["lines"] as? [String: Any],
        let covered = lines["covered"] as? Int,
        let count = lines["count"] as? Int
    else {
        continue
    }
    coveredLines += covered
    totalLines += count
}

guard totalLines > 0 else {
    fputs("No HiIntervalCore source lines found in coverage report\n", stderr)
    exit(2)
}

let percent = Double(coveredLines) * 100.0 / Double(totalLines)
print(
    String(
        format: "HiIntervalCore line coverage: %.2f%% (%d/%d; gate %.2f%%)",
        percent,
        coveredLines,
        totalLines,
        minimum
    )
)

if percent + 1e-9 < minimum {
    fputs(String(format: "Coverage %.2f%% is below %.2f%% gate\n", percent, minimum), stderr)
    exit(1)
}
