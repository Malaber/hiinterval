public struct SessionHeadingHierarchy: Equatable, Sendable {
    public let currentNamePointSize: Double
    public let nextNamePointSize: Double
    public let nextSurfaceOpacity: Double
    public let nextStrokeOpacity: Double

    public init(
        currentNamePointSize: Double = 42,
        nextNamePointSize: Double = 19,
        nextSurfaceOpacity: Double = 0.12,
        nextStrokeOpacity: Double = 0.1
    ) {
        self.currentNamePointSize = currentNamePointSize
        self.nextNamePointSize = nextNamePointSize
        self.nextSurfaceOpacity = nextSurfaceOpacity
        self.nextStrokeOpacity = nextStrokeOpacity
    }

    public var clearlyPrioritizesCurrentHeading: Bool {
        currentNamePointSize > nextNamePointSize
            && nextSurfaceOpacity < 0.2
            && nextStrokeOpacity < 0.2
    }
}
