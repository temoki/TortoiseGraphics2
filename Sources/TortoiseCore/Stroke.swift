/// A line segment drawn by the turtle.
public struct Stroke: Sendable, Equatable {
    public let from: Vec2D
    public let to: Vec2D
    public let color: Color
    public let width: Double
}
