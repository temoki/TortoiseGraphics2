import Foundation
import Observation

/// The main turtle-graphics API.
///
/// Create a `Tortoise`, call drawing methods on it,
/// then pass ``commands`` to a renderer or ``CommandPlayer``.
///
/// ```swift
/// let 🐢 = Tortoise()
/// for _ in 1...4 {
///     🐢.forward(100)
///     🐢.right(90)
/// }
/// // 🐢.commands now holds the full command stream.
/// ```
@Observable
@MainActor
public final class Tortoise {
    /// The command stream produced so far.
    public private(set) var commands: [TurtleCommand] = []

    /// The logical canvas size in turtle coordinate units.
    ///
    /// This value is independent of the view's pixel dimensions.
    /// The canvas spans from `(-canvasSize.width/2, -canvasSize.height/2)`
    /// to `(canvasSize.width/2, canvasSize.height/2)`.
    /// Renderers use this as the reference frame (e.g., SVG `viewBox`,
    /// `TortoiseCanvasView` scale-to-fit mode).
    public let canvasSize: Size2D

    private var state: TurtleState = .default
    private var _backgroundColor: Color = .white

    public init(canvasSize: Size2D = .defaultCanvas) {
        self.canvasSize = canvasSize
    }

    // MARK: - Read-only positional state

    public var position: Vec2D { state.position }
    public var isPenDown: Bool { state.isPenDown }
    public var isVisible: Bool { state.isVisible }

    // MARK: - Read-write properties (append a command on set)

    public var penColor: Color {
        get { state.penColor }
        set { state.penColor = newValue; commands.append(.penColor(newValue)) }
    }

    public var penWidth: Double {
        get { state.penWidth }
        set {
            state.penWidth = max(0, newValue)
            commands.append(.penWidth(state.penWidth))
        }
    }

    public var fillColor: Color {
        get { state.fillColor }
        set { state.fillColor = newValue; commands.append(.fillColor(newValue)) }
    }

    /// Heading in degrees (0 = north, clockwise positive).
    public var heading: Double {
        get { state.heading }
        set {
            state.heading = newValue.truncatingRemainder(dividingBy: 360)
            commands.append(.setHeading(state.heading))
        }
    }

    /// Playback speed: 1 (slowest) … 10 (fastest), 0 = instant.
    public var speed: Double {
        get { state.speed }
        set { state.speed = max(0, newValue); commands.append(.speed(state.speed)) }
    }

    public var backgroundColor: Color {
        get { _backgroundColor }
        set { _backgroundColor = newValue; commands.append(.backgroundColor(newValue)) }
    }

    // MARK: - Movement

    /// Move forward by `distance` pixels (negative = backward).
    public func forward(_ distance: Double) {
        state.position = state.position.moved(distance: distance, heading: state.heading)
        commands.append(.forward(distance))
    }

    /// Move backward by `distance` pixels.
    public func backward(_ distance: Double) {
        forward(-distance)
    }

    /// Rotate clockwise by `degrees`.
    public func right(_ degrees: Double) {
        state.heading = (state.heading + degrees).truncatingRemainder(dividingBy: 360)
        commands.append(.rotate(degrees))
    }

    /// Rotate counterclockwise by `degrees`.
    public func left(_ degrees: Double) {
        right(-degrees)
    }

    /// Move to origin (0, 0) and reset heading to north (0°).
    public func home() {
        state.position = .zero
        state.heading = 0
        commands.append(.home)
    }

    /// Teleport to the given position without changing heading.
    public func setPosition(x: Double, y: Double) {
        state.position = Vec2D(x: x, y: y)
        commands.append(.setPosition(state.position))
    }

    /// Teleport to the given position without changing heading.
    public func setPosition(_ position: Vec2D) {
        state.position = position
        commands.append(.setPosition(position))
    }

    /// Draw an arc counterclockwise.
    ///
    /// The center is placed to the left of the turtle at distance `radius`.
    /// `extent` controls how many degrees of the circle are drawn (360 = full circle).
    /// Positive `extent` draws counterclockwise; negative `extent` draws clockwise.
    public func circle(radius: Double, extent: Double = 360) {
        let (newPos, newHeading) = Self.arcEndState(
            position: state.position,
            heading: state.heading,
            radius: radius,
            extent: extent
        )
        state.position = newPos
        state.heading = newHeading
        commands.append(.arc(radius: radius, extent: extent))
    }

    // MARK: - Pen

    public func penDown() {
        state.isPenDown = true
        commands.append(.penDown)
    }

    public func penUp() {
        state.isPenDown = false
        commands.append(.penUp)
    }

    // MARK: - Fill

    public func beginFill() {
        commands.append(.beginFill)
    }

    public func endFill() {
        commands.append(.endFill)
    }

    // MARK: - Appearance

    public func showTurtle() {
        state.isVisible = true
        commands.append(.showTurtle)
    }

    public func hideTurtle() {
        state.isVisible = false
        commands.append(.hideTurtle)
    }

    // MARK: - Canvas

    /// Clear all drawings; turtle position and pen state are preserved.
    public func clear() {
        commands.append(.clear)
    }

    // MARK: - Python-style aliases

    /// `fd` — alias for ``forward(_:)``.
    public func fd(_ distance: Double) { forward(distance) }
    /// `bk` — alias for ``backward(_:)``.
    public func bk(_ distance: Double) { backward(distance) }
    /// `rt` — alias for ``right(_:)``.
    public func rt(_ degrees: Double) { right(degrees) }
    /// `lt` — alias for ``left(_:)``.
    public func lt(_ degrees: Double) { left(degrees) }
    /// `pu` — alias for ``penUp()``.
    public func pu() { penUp() }
    /// `pd` — alias for ``penDown()``.
    public func pd() { penDown() }
    /// `ht` — alias for ``hideTurtle()``.
    public func ht() { hideTurtle() }
    /// `st` — alias for ``showTurtle()``.
    public func st() { showTurtle() }
    /// `goto` — alias for ``setPosition(_:)``.
    public func goto(_ position: Vec2D) { setPosition(position) }
    /// `goto` — alias for ``setPosition(x:y:)``.
    public func goto(x: Double, y: Double) { setPosition(x: x, y: y) }
    /// `seth` — alias for ``heading`` setter.
    public func seth(_ degrees: Double) { heading = degrees }
}

// MARK: - Arc geometry helper (shared with CommandPlayer)

extension Tortoise {
    nonisolated static func arcEndState(
        position: Vec2D,
        heading: Double,
        radius: Double,
        extent: Double
    ) -> (position: Vec2D, heading: Double) {
        let center = arcCenter(position: position, heading: heading, radius: radius)
        let dx = position.x - center.x
        let dy = position.y - center.y
        let startAngle = atan2(dy, dx)
        let endAngleRad = startAngle + extent * (.pi / 180)
        let newPos = Vec2D(
            x: center.x + radius * cos(endAngleRad),
            y: center.y + radius * sin(endAngleRad)
        )
        let newHeading = (heading - extent).truncatingRemainder(dividingBy: 360)
        return (newPos, newHeading)
    }

    nonisolated static func arcCenter(position: Vec2D, heading: Double, radius: Double) -> Vec2D {
        let leftRad = (heading - 90) * (.pi / 180)
        return Vec2D(
            x: position.x + radius * sin(leftRad),
            y: position.y + radius * cos(leftRad)
        )
    }
}
