/// A filled circle drawn at a fixed position by the ``TortoiseCommand/dot(_:)`` command.
public struct Dot: Sendable {
    /// Center of the dot in tortoise coordinates.
    public let center: Point
    /// Diameter of the dot in logical units.
    public let size: Double
    /// Fill color of the dot.
    public let color: Color
}
