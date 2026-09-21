/// A circular arc drawn by the tortoise.
///
/// Angles are in degrees in tortoise coordinate space (Y axis up, 0 = east, counterclockwise positive).
/// Renderers must convert to their own coordinate system (SVG / Core Graphics have Y flipped).
public struct ArcStroke: Sendable, Equatable {
    /// Center of the circle in tortoise coordinate space.
    public let center: Point
    public let radius: Double
    /// Angle from center to the start point (0 = east, CCW positive in tortoise space).
    public let startAngle: Double
    /// Sweep angle in degrees (positive = CCW in tortoise space).
    public let sweep: Double
    public let color: Color
    /// Pen width at the start of the sweep.
    public let width: Double
    /// Pen width at the end of the sweep.
    public let endWidth: Double

    /// Creates an arc stroke. `endWidth` defaults to `width`, giving the
    /// constant-width arc that ``TortoiseCommand/arc(radius:extent:)`` produces.
    public init(
        center: Point, radius: Double, startAngle: Double, sweep: Double,
        color: Color, width: Double, endWidth: Double? = nil
    ) {
        self.center = center
        self.radius = radius
        self.startAngle = startAngle
        self.sweep = sweep
        self.color = color
        self.width = width
        self.endWidth = endWidth ?? width
    }

    /// Whether the pen width changes across this arc.
    public var isTapered: Bool { endWidth != width }
}
