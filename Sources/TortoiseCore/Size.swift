/// A 2D size in logical (world) coordinate space.
///
/// The logical canvas spans from `(-width/2, -height/2)` to `(width/2, height/2)`
/// in turtle coordinate space (center origin, Y axis up).
public struct Size: Sendable, Hashable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// The default logical canvas size when none is specified (400 × 400).
    public static let defaultCanvas = Size(width: 400, height: 400)
}
