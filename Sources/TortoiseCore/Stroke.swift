/// A line segment drawn by the tortoise.
public struct Stroke: Sendable, Equatable {
    public let from: Point
    public let to: Point
    public let color: Color
    public let width: Double
}
