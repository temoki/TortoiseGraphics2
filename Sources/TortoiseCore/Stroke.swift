/// A straight pen stroke between two points.
///
/// ``width`` is the pen width at ``from`` and ``endWidth`` the width at ``to``.
/// They are equal for an ordinary stroke; when they differ the stroke is
/// *tapered* and renderers fill its outline rather than stroking a line at a
/// single width.
public struct Stroke: Sendable, Equatable {
    public let from: Point
    public let to: Point
    public let color: Color
    /// Pen width at ``from``.
    public let width: Double
    /// Pen width at ``to``.
    public let endWidth: Double

    /// Creates a stroke. `endWidth` defaults to `width`, giving the
    /// constant-width stroke that every non-tapered command produces.
    public init(from: Point, to: Point, color: Color, width: Double, endWidth: Double? = nil) {
        self.from = from
        self.to = to
        self.color = color
        self.width = width
        self.endWidth = endWidth ?? width
    }

    /// Whether the pen width changes across this stroke.
    ///
    /// Renderers use this to choose between stroking a line and filling an
    /// outline; it is also why a tapered stroke can never join a same-width
    /// batch.
    public var isTapered: Bool { endWidth != width }
}
