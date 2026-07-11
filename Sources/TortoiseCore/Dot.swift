/// A filled circle drawn at a fixed position by the ``TurtleCommand/dot(_:)`` command.
public struct Dot: Sendable {
    /// Center of the dot in turtle coordinates.
    public let center: Vec2D
    /// Diameter of the dot in logical units.
    public let size: Double
    /// Fill color of the dot.
    public let color: Color
}
