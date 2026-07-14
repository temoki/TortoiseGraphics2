/// The complete state of the tortoise at a point in time.
public struct TortoiseState: Sendable, Equatable {
    /// Current position in tortoise coordinate space (center origin, Y up).
    public var position: Point
    /// Current heading in degrees (0 = north, clockwise positive).
    /// Kept normalized to [0, 360) by ``applying(_:)``.
    public var heading: Double
    public var isPenDown: Bool
    public var penColor: Color
    public var penWidth: Double
    public var fillColor: Color
    public var isVisible: Bool
    /// Playback speed: 1 (slowest) … 10 (fastest), 0 = instant.
    public var speed: Double

    public static let `default` = TortoiseState(
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

extension TortoiseState {
    /// Normalizes an angle in degrees to the canonical heading range [0, 360).
    static func normalizedHeading(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    /// Returns the state after applying a single command.
    ///
    /// This is the single source of truth for tortoise state transitions:
    /// ``Tortoise`` applies each command as it records it, and
    /// ``CommandPlayer`` replays streams with the same function — so the two
    /// can never drift apart. Custom renderers can use it for incremental
    /// replay. Commands that only produce drawing or canvas output
    /// (`beginFill`, `endFill`, `backgroundColor`, `clear`, `dot`) return
    /// the state unchanged.
    public func applying(_ command: TortoiseCommand) -> TortoiseState {
        var state = self
        switch command {
        case .forward(let distance):
            state.position = position.moved(distance: distance, heading: heading)
        case .rotate(let degrees):
            state.heading = Self.normalizedHeading(heading + degrees)
        case .home:
            state.position = .zero
            state.heading = 0
        case .setPosition(let position):
            state.position = position
        case .setHeading(let degrees):
            state.heading = Self.normalizedHeading(degrees)
        case .penDown:
            state.isPenDown = true
        case .penUp:
            state.isPenDown = false
        case .penColor(let color):
            state.penColor = color
        case .penWidth(let width):
            state.penWidth = max(0, width)
        case .fillColor(let color):
            state.fillColor = color
        case .showTortoise:
            state.isVisible = true
        case .hideTortoise:
            state.isVisible = false
        case .speed(let speed):
            state.speed = max(0, speed)
        case .arc(let radius, let extent):
            let end = Tortoise.arcEndState(
                position: position, heading: heading, radius: radius, extent: extent)
            state.position = end.position
            state.heading = Self.normalizedHeading(end.heading)
        case .beginFill, .endFill, .backgroundColor, .clear, .dot:
            break
        }
        return state
    }
}
