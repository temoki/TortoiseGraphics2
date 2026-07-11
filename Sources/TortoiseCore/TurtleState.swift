/// The complete state of the turtle at a point in time.
public struct TurtleState: Sendable, Equatable {
    /// Current position in turtle coordinate space (center origin, Y up).
    public var position: Point
    /// Current heading in degrees (0 = north, clockwise positive).
    public var heading: Double
    public var isPenDown: Bool
    public var penColor: Color
    public var penWidth: Double
    public var fillColor: Color
    public var isVisible: Bool
    /// Playback speed: 1 (slowest) … 10 (fastest), 0 = instant.
    public var speed: Double

    public static let `default` = TurtleState(
        position: .zero,
        heading: 0,
        isPenDown: true,
        penColor: .black,
        penWidth: 1,
        fillColor: .black,
        isVisible: true,
        speed: 5
    )
}
