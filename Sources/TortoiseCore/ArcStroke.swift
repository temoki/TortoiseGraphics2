/// A circular arc drawn by the turtle.
///
/// Angles are in degrees in turtle coordinate space (Y axis up, 0 = east, counterclockwise positive).
/// Renderers must convert to their own coordinate system (SVG / Core Graphics have Y flipped).
public struct ArcStroke: Sendable, Equatable {
    /// Center of the circle in turtle coordinate space.
    public let center: Point
    public let radius: Double
    /// Angle from center to the start point (0 = east, CCW positive in turtle space).
    public let startAngle: Double
    /// Sweep angle in degrees (positive = CCW in turtle space).
    public let sweep: Double
    public let color: Color
    public let width: Double
}
