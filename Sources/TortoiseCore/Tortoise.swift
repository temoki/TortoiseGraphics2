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

    public init() {}

    // MARK: - Movement

    /// Move forward by `distance` pixels (negative = backward).
    public func forward(_ distance: Double) {
        commands.append(.forward(distance))
    }

    /// Move backward by `distance` pixels.
    public func backward(_ distance: Double) {
        commands.append(.forward(-distance))
    }

    /// Rotate clockwise by `degrees`.
    public func right(_ degrees: Double) {
        commands.append(.rotate(degrees))
    }

    /// Rotate counterclockwise by `degrees`.
    public func left(_ degrees: Double) {
        commands.append(.rotate(-degrees))
    }

    /// Move to origin (0, 0) and reset heading to north.
    public func home() {
        commands.append(.home)
    }

    /// Teleport to the given position without changing heading.
    public func setPosition(x: Double, y: Double) {
        commands.append(.setPosition(Vec2D(x: x, y: y)))
    }

    /// Teleport to the given position without changing heading.
    public func setPosition(_ position: Vec2D) {
        commands.append(.setPosition(position))
    }

    /// Set heading in degrees (0 = north, clockwise).
    public func setHeading(_ degrees: Double) {
        commands.append(.setHeading(degrees))
    }

    // MARK: - Pen

    public func penDown() {
        commands.append(.penDown)
    }

    public func penUp() {
        commands.append(.penUp)
    }

    public func setPenColor(_ color: Color) {
        commands.append(.penColor(color))
    }

    public func setPenWidth(_ width: Double) {
        commands.append(.penWidth(width))
    }

    // MARK: - Fill

    public func setFillColor(_ color: Color) {
        commands.append(.fillColor(color))
    }

    public func beginFill() {
        commands.append(.beginFill)
    }

    public func endFill() {
        commands.append(.endFill)
    }

    // MARK: - Appearance

    public func showTurtle() {
        commands.append(.showTurtle)
    }

    public func hideTurtle() {
        commands.append(.hideTurtle)
    }

    /// Set playback speed: 1 (slowest) … 10 (fastest), 0 = instant.
    public func speed(_ speed: Double) {
        commands.append(.speed(speed))
    }

    // MARK: - Canvas

    public func setBackgroundColor(_ color: Color) {
        commands.append(.backgroundColor(color))
    }

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
    /// `seth` — alias for ``setHeading(_:)``.
    public func seth(_ degrees: Double) { setHeading(degrees) }
}
