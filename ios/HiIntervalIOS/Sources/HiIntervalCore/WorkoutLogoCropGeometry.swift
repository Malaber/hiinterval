/// Geometry shared by the square crop preview and its final image render.
/// Inputs are positive image/viewport dimensions and zoom of at least one.
public struct WorkoutLogoCropGeometry: Sendable {
    public let sourceWidth: Double
    public let sourceHeight: Double
    public let viewportSide: Double
    public let zoom: Double

    public init(sourceWidth: Double, sourceHeight: Double, viewportSide: Double, zoom: Double) {
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.viewportSide = viewportSide
        self.zoom = zoom
    }

    public var scale: Double {
        max(viewportSide / sourceWidth, viewportSide / sourceHeight) * zoom
    }

    public var cropSide: Double { viewportSide / scale }

    public func clampedOffset(x: Double, y: Double) -> (x: Double, y: Double) {
        let maximumX = max(0, (sourceWidth * scale - viewportSide) / 2)
        let maximumY = max(0, (sourceHeight * scale - viewportSide) / 2)
        return (
            x: min(maximumX, max(-maximumX, x)),
            y: min(maximumY, max(-maximumY, y))
        )
    }

    public func cropOrigin(offsetX: Double, offsetY: Double) -> (x: Double, y: Double) {
        let offset = clampedOffset(x: offsetX, y: offsetY)
        let originX = sourceWidth / 2 - offset.x / scale - cropSide / 2
        let originY = sourceHeight / 2 - offset.y / scale - cropSide / 2
        return (
            x: min(max(0, originX), max(0, sourceWidth - cropSide)),
            y: min(max(0, originY), max(0, sourceHeight - cropSide))
        )
    }
}
