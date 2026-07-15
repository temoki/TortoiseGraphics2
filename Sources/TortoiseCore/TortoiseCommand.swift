/// A single instruction produced by the ``Tortoise`` API.
///
/// Commands are `Sendable` value types — the same stream is consumed
/// by SwiftUI canvas rendering, SVG export, and tests.
///
/// Heading convention throughout: 0 = north (up), clockwise positive.
public enum TortoiseCommand: Sendable, Equatable {
    // MARK: Movement
    /// Move forward (positive) or backward (negative) by `distance` pixels.
    case forward(Double)
    /// Rotate clockwise (positive) or counterclockwise (negative) by `degrees`.
    case rotate(Double)
    /// Move to the origin (0, 0) and reset heading to 0 (north).
    case home
    /// Teleport to the given position without changing heading.
    case setPosition(Point)
    /// Set heading in degrees (0 = north, clockwise).
    case setHeading(Double)

    // MARK: Pen
    case penDown
    case penUp
    case penColor(Color)
    case penWidth(Double)

    // MARK: Fill
    case fillColor(Color)
    case beginFill
    case endFill

    // MARK: Appearance
    case showTortoise
    case hideTortoise
    /// Playback speed: 1 (slowest) … 10 (fastest), 0 = instant.
    case speed(Double)

    // MARK: Canvas
    case backgroundColor(Color)
    /// Clear all drawings and discard any in-progress fill;
    /// tortoise position and pen state are preserved.
    case clear

    // MARK: Arc
    /// Draw a circular arc.
    ///
    /// The arc center is placed to the tortoise's left at distance `radius`.
    /// `extent` is in degrees: 360 = full circle, positive = counterclockwise.
    /// A negative `radius` mirrors the arc (center on the tortoise's right,
    /// sweep directions flipped), matching Python turtle.
    case arc(radius: Double, extent: Double)

    // MARK: Dot
    /// Draw a filled circle at the current position without moving the tortoise.
    ///
    /// `size` is the diameter in logical units.
    case dot(Double)
}
