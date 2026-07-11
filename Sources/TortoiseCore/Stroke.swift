/// A line segment drawn by the turtle.
public struct Stroke: Sendable, Equatable {
    public let from: Point
    public let to: Point
    public let color: Color
    public let width: Double
}
