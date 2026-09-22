import Foundation

public struct CatalogueExercise: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var labelIDs: [UUID]
    public var duration: DurationSetting
    public var recovery: RecoverySetting
    public var sideConfiguration: SideConfiguration
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        labelIDs: [UUID] = [],
        duration: DurationSetting = .planDefault,
        recovery: RecoverySetting = .planDefault,
        sideConfiguration: SideConfiguration = .together,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.labelIDs = labelIDs
        self.duration = duration
        self.recovery = recovery
        self.sideConfiguration = sideConfiguration
        self.notes = notes
    }

    public init(step: ExerciseStep) {
        self.init(
            id: step.id,
            name: step.name,
            duration: step.duration,
            recovery: step.recovery,
            sideConfiguration: step.sideConfiguration,
            notes: step.notes
        )
    }

    public func makeStep() -> ExerciseStep {
        ExerciseStep(
            name: name,
            duration: duration,
            recovery: recovery,
            sideConfiguration: sideConfiguration,
            notes: notes,
            catalogueExerciseID: id
        )
    }

    public func normalized() -> CatalogueExercise {
        var value = self
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.labelIDs = Self.uniqueIDs(labelIDs)
        return value
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, labelIDs, duration, recovery, sideConfiguration, notes
        case bodyAreas, tags
    }

    private var legacyBodyAreas: [String] = []
    private var legacyTags: [String] = []

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decode(String.self, forKey: .name)
        labelIDs = try values.decodeIfPresent([UUID].self, forKey: .labelIDs) ?? []
        duration = try values.decodeIfPresent(DurationSetting.self, forKey: .duration) ?? .planDefault
        recovery = try values.decodeIfPresent(RecoverySetting.self, forKey: .recovery) ?? .planDefault
        sideConfiguration = try values.decodeIfPresent(SideConfiguration.self, forKey: .sideConfiguration) ?? .together
        notes = try values.decodeIfPresent(String.self, forKey: .notes) ?? ""
        legacyBodyAreas = try values.decodeIfPresent([String].self, forKey: .bodyAreas) ?? []
        legacyTags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(name, forKey: .name)
        try values.encode(labelIDs, forKey: .labelIDs)
        try values.encode(duration, forKey: .duration)
        try values.encode(recovery, forKey: .recovery)
        try values.encode(sideConfiguration, forKey: .sideConfiguration)
        try values.encode(notes, forKey: .notes)
    }

    mutating func migrateLegacyLabels(using resolve: (String, ExerciseLabel.Kind) -> UUID?) {
        labelIDs += legacyBodyAreas.compactMap { resolve($0, .bodyArea) }
        labelIDs += legacyTags.compactMap { resolve($0, .tag) }
        labelIDs = Self.uniqueIDs(labelIDs)
        legacyBodyAreas = []
        legacyTags = []
    }

    private static func uniqueIDs(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}

public enum ExerciseCatalogueError: Error, Equatable, LocalizedError, Sendable {
    case emptyName
    case missingExercise(UUID)
    case missingMergeTarget(UUID)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Exercise name cannot be empty."
        case .missingExercise: return "One or more exercises could not be found."
        case .missingMergeTarget: return "The exercise to merge into could not be found."
        case let .invalidConfiguration(description): return description
        }
    }
}
