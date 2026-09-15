import Foundation
import Observation

/// The main tortoise-graphics API.
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
    public private(set) var commands: [TortoiseCommand] = []

    /// Monotonically increasing count of mutations to the command stream —
    /// incremented by every recorded command and by ``reset()``.
    ///
    /// `TortoiseUI` observes this (not `commands.count`) to detect changes:
    /// a ``reset()`` followed by re-recording the same number of commands
    /// leaves the count unchanged, but never leaves `mutationCount` unchanged.
    package private(set) var mutationCount = 0

    /// The logical canvas size in tortoise coordinate units.
    ///
    /// This value is independent of the view's pixel dimensions.
    /// The canvas spans from `(-canvasSize.width/2, -canvasSize.height/2)`
    /// to `(canvasSize.width/2, canvasSize.height/2)`.
    /// Renderers use this as the reference frame (e.g., SVG `viewBox`,
    /// `TortoiseCanvasView` scale-to-fit mode).
    public let canvasSize: Size

    private var state: TortoiseState = .default
    private var _backgroundColor: Color = .defaultBackground
    private var _isFilling: Bool = false

    public init(canvasSize: Size = .defaultCanvas) {
        self.canvasSize = canvasSize
    }

    /// Appends a command to the stream and advances the tortoise state through
    /// the shared ``TortoiseState/applying(_:)`` reducer — the same function
    /// ``CommandPlayer`` uses for replay, so the two can never drift apart.
    private func record(_ command: TortoiseCommand) {
        commands.append(command)
        state = state.applying(command)
        mutationCount += 1
    }

    // MARK: - Read-only state

    public var position: Point { state.position }
    public var isPenDown: Bool { state.isPenDown }
    public var isVisible: Bool { state.isVisible }
    /// `true` when between a ``beginFill()`` and ``endFill()`` call.
    public var isFilling: Bool { _isFilling }

    // MARK: - Read-write properties (append a command on set)

    public var penColor: Color {
        get { state.penColor }
        set { record(.penColor(newValue)) }
    }

    public var penWidth: Double {
        get { state.penWidth }
        set { record(.penWidth(max(0, newValue))) }
    }

    public var fillColor: Color {
        get { state.fillColor }
        set { record(.fillColor(newValue)) }
    }

    /// Heading in degrees (0 = north, clockwise positive).
    ///
    /// Reading always returns a value in [0, 360), matching ``towards(x:y:)``
    /// and Python turtle; setting accepts any value and normalizes it
    /// (e.g. `-90` becomes `270`).
    public var heading: Double {
        get { state.heading }
        set { record(.setHeading(TortoiseState.normalizedHeading(newValue))) }
    }

    /// Playback speed: 1 (slowest) … 10 (fastest), 0 = instant.
    public var speed: Double {
        get { state.speed }
        set { record(.speed(max(0, newValue))) }
    }

    public var backgroundColor: Color {
        get { _backgroundColor }
        set {
            _backgroundColor = newValue
            record(.backgroundColor(newValue))
        }
    }

    // MARK: - Movement

    /// Move forward by `distance` pixels (negative = backward).
    public func forward(_ distance: Double) {
        record(.forward(distance))
    }

    /// Move backward by `distance` pixels.
    public func backward(_ distance: Double) {
        forward(-distance)
    }

    /// Move forward by `distance` pixels while ramping the pen width from its
    /// current value to `endWidth`.
    ///
    /// The taper is approximated by subdividing the move into sub-segments,
    /// each drawn at a constant width — there is no variable-width stroke
    /// primitive, so this is sugar over ``forward(_:)`` and
    /// ``penWidth``. After the call ``penWidth`` is exactly `endWidth`.
    ///
    /// - Parameters:
    ///   - distance: Distance to travel (negative = backward).
    ///   - endWidth: Pen width at the end of the move. Clamped to `>= 0`.
    ///   - steps: Number of sub-segments. Defaults to `nil`, which picks the
    ///     fewest steps that keep the width change per sub-segment at or below
    ///     ``taperWidthQuantum`` (capped at ``maxTaperSteps``). When the width
    ///     does not change at all, a single plain ``forward(_:)`` is recorded.
    public func forward(_ distance: Double, widthTo endWidth: Double, steps: Int? = nil) {
        taper(to: endWidth, steps: steps) { self.record(.forward(distance * $0)) }
    }

    /// Move backward by `distance` pixels while ramping the pen width to `endWidth`.
    ///
    /// See ``forward(_:widthTo:steps:)`` for how the taper is approximated.
    public func backward(_ distance: Double, widthTo endWidth: Double, steps: Int? = nil) {
        forward(-distance, widthTo: endWidth, steps: steps)
    }

    /// Rotate clockwise by `degrees`.
    public func right(_ degrees: Double) {
        record(.rotate(degrees))
    }

    /// Rotate counterclockwise by `degrees`.
    public func left(_ degrees: Double) {
        right(-degrees)
    }

    /// Move to origin (0, 0) and reset heading to north (0°).
    public func home() {
        record(.home)
    }

    /// Teleport to the given position without changing heading.
    public func setPosition(x: Double, y: Double) {
        record(.setPosition(Point(x: x, y: y)))
    }

    /// Teleport to the given position without changing heading.
    public func setPosition(_ position: Point) {
        record(.setPosition(position))
    }

    /// Teleport to `(x, position.y)` without changing heading or Y coordinate.
    public func setX(_ x: Double) {
        setPosition(x: x, y: state.position.y)
    }

    /// Teleport to `(position.x, y)` without changing heading or X coordinate.
    public func setY(_ y: Double) {
        setPosition(x: state.position.x, y: y)
    }

    /// Returns the heading (in degrees) toward the given point from the current position.
    ///
    /// - Returns: A value in [0, 360) where 0 = north, 90 = east, clockwise positive.
    public func towards(x: Double, y: Double) -> Double {
        let dx = x - state.position.x
        let dy = y - state.position.y
        let angle = atan2(dx, dy) * (180 / .pi)
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        return normalized < 0 ? normalized + 360 : normalized
    }

    /// Returns the heading (in degrees) toward `position` from the current position.
    public func towards(_ position: Point) -> Double {
        towards(x: position.x, y: position.y)
    }

    /// Returns the Euclidean distance from the current position to the given point.
    public func distance(x: Double, y: Double) -> Double {
        let dx = x - state.position.x
        let dy = y - state.position.y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Returns the Euclidean distance from the current position to `position`.
    public func distance(_ position: Point) -> Double {
        distance(x: position.x, y: position.y)
    }

    /// Draw a filled circle at the current position without moving the tortoise.
    ///
    /// - Parameter size: Diameter in logical units. Defaults to `max(penWidth + 4, 2 * penWidth)`.
    public func dot(size: Double? = nil) {
        let resolvedSize = size ?? max(state.penWidth + 4, 2 * state.penWidth)
        record(.dot(resolvedSize))
    }

    /// Draw a circular arc.
    ///
    /// The center is placed to the left of the tortoise at distance `radius`;
    /// a positive `extent` then draws counterclockwise and a negative one
    /// clockwise (360 = full circle).
    /// A negative `radius` mirrors the arc, matching Python turtle: the center
    /// sits to the tortoise's right and both sweep directions flip, so the
    /// same `extent` bends the path the other way.
    public func circle(radius: Double, extent: Double = 360) {
        record(.arc(radius: radius, extent: extent))
    }

    /// Draw a circular arc while ramping the pen width from its current value
    /// to `endWidth`.
    ///
    /// The arc is subdivided into sub-arcs of equal extent, each drawn at a
    /// constant width; sub-arcs compose exactly, so the tortoise lands where an
    /// undivided ``circle(radius:extent:)`` would. After the call ``penWidth``
    /// is exactly `endWidth`.
    ///
    /// See ``forward(_:widthTo:steps:)`` for how `steps` is chosen.
    public func circle(
        radius: Double, extent: Double = 360, widthTo endWidth: Double, steps: Int? = nil
    ) {
        taper(to: endWidth, steps: steps) { self.record(.arc(radius: radius, extent: extent * $0)) }
    }

    // MARK: - Pen-width taper

    /// Largest pen-width change (in logical units) allowed between consecutive
    /// sub-segments when a taper picks its own step count.
    ///
    /// A quarter of a unit is below the visible threshold at normal scales, and
    /// tying the step count to the *width* delta rather than to the distance is
    /// what keeps a gentle taper cheap: `forward(500, widthTo: penWidth + 1)`
    /// costs four sub-segments, not five hundred.
    public static let taperWidthQuantum = 0.25

    /// Upper bound on the sub-segments a taper will pick for itself.
    ///
    /// Each sub-segment is a distinct `Stroke` width, which defeats the
    /// same-width stroke batching in `TortoiseUI` and emits its own `<line>` in
    /// SVG, so an extreme width change buys fidelity with draw calls rather
    /// than unbounded ones. Pass `steps:` explicitly to go past this.
    public static let maxTaperSteps = 64

    /// Records `segment` `n` times — each call drawing a `1/n` fraction of the
    /// whole move — with the pen width stepped along the way.
    ///
    /// `segment` receives the fraction of the move to draw, so the same helper
    /// serves straight moves and arcs.
    private func taper(to rawEndWidth: Double, steps requested: Int?, segment: (Double) -> Void) {
        let endWidth = max(0, rawEndWidth)
        let startWidth = state.penWidth
        let n = Self.taperSteps(from: startWidth, to: endWidth, requested: requested)

        // No width change: a taper is then exactly a plain move, so a caller
        // that happens to pass its current width pays nothing for the call —
        // one command, one full-width stroke, still eligible for batching.
        guard startWidth != endWidth else {
            segment(1)
            return
        }

        let fraction = 1.0 / Double(n)
        for i in 0..<n {
            // Sampled at the sub-segment's *midpoint*, so the width error is
            // centered rather than accumulated on one side: half as many steps
            // reach the fidelity that sampling at the leading edge would need.
            let t = (Double(i) + 0.5) * fraction
            record(.penWidth(startWidth + (endWidth - startWidth) * t))
            segment(fraction)
        }
        // Midpoint sampling never emits the endpoint itself; land on it exactly
        // so `penWidth` after the call is the width the caller asked for.
        record(.penWidth(endWidth))
    }

    private static func taperSteps(from startWidth: Double, to endWidth: Double, requested: Int?)
        -> Int
    {
        if let requested { return max(1, requested) }
        let delta = abs(endWidth - startWidth)
        guard delta > 0 else { return 1 }
        return min(maxTaperSteps, max(1, Int((delta / taperWidthQuantum).rounded(.up))))
    }

    // MARK: - Pen

    public func penDown() {
        record(.penDown)
    }

    public func penUp() {
        record(.penUp)
    }

    // MARK: - Fill

    public func beginFill() {
        _isFilling = true
        record(.beginFill)
    }

    public func endFill() {
        _isFilling = false
        record(.endFill)
    }

    // MARK: - Appearance

    public func showTortoise() {
        record(.showTortoise)
    }

    public func hideTortoise() {
        record(.hideTortoise)
    }

    // MARK: - Canvas

    /// Clear all drawings; tortoise position, heading, and pen state are preserved.
    ///
    /// An in-progress fill started with ``beginFill()`` is discarded
    /// (matching Python turtle): ``isFilling`` becomes `false` and a
    /// subsequent ``endFill()`` does nothing.
    public func clear() {
        _isFilling = false
        record(.clear)
    }

    /// Discards the command stream and restores the initial state.
    ///
    /// Position, heading, pen, fill, visibility, speed, and background color
    /// all return to their defaults, ``commands`` becomes empty, and an
    /// in-progress fill is discarded (``isFilling`` becomes `false`);
    /// ``canvasSize`` is preserved. Equivalent to Python turtle's `reset()`.
    ///
    /// Unlike ``clear()`` — which appends a command and therefore keeps the
    /// stream growing — `reset()` empties the stream, so replay cost does not
    /// accumulate when a program is re-run repeatedly.
    public func reset() {
        commands = []
        state = .default
        _backgroundColor = .defaultBackground
        _isFilling = false
        mutationCount += 1
    }

}

// MARK: - Arc geometry helper (shared with CommandPlayer)

extension Tortoise {
    nonisolated static func arcEndState(
        position: Point,
        heading: Double,
        radius: Double,
        extent: Double
    ) -> (position: Point, heading: Double) {
        let center = arcCenter(position: position, heading: heading, radius: radius)
        let dx = position.x - center.x
        let dy = position.y - center.y
        let startAngle = atan2(dy, dx)
        // A negative radius mirrors the arc (center on the tortoise's right,
        // matching Python turtle): the sweep direction and turn flip together.
        let direction: Double = radius < 0 ? -1 : 1
        let endAngleRad = startAngle + direction * extent * (.pi / 180)
        let newPos = Point(
            x: center.x + abs(radius) * cos(endAngleRad),
            y: center.y + abs(radius) * sin(endAngleRad)
        )
        let newHeading = (heading - direction * extent).truncatingRemainder(dividingBy: 360)
        return (newPos, newHeading)
    }

    nonisolated static func arcCenter(position: Point, heading: Double, radius: Double) -> Point {
        let leftRad = (heading - 90) * (.pi / 180)
        return Point(
            x: position.x + radius * sin(leftRad),
            y: position.y + radius * cos(leftRad)
        )
    }
}
