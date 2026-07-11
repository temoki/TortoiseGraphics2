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
    public let width: Double
}
