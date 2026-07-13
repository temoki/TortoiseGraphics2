/// Axis-aligned bounding box of drawing output in tortoise coordinate space.
public struct DrawingBounds: Sendable {
    public let minX, minY, maxX, maxY: Double

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var centerX: Double { (minX + maxX) / 2 }
    public var centerY: Double { (minY + maxY) / 2 }

    /// Computes the bounding box of all visible output across the given frames.
    ///
    /// Arc bounding boxes use the full-circle extent (center ± radius) —
    /// conservative but always correct without trigonometry over partial arc segments.
    public static func compute(from frames: [PlaybackFrame]) -> DrawingBounds? {
        var builder = Builder()
        for frame in frames {
            if frame.didClear { builder = Builder() }
            if let s = frame.newStroke {
                builder.expand(to: s.from)
                builder.expand(to: s.to)
            }
            if let a = frame.newArcStroke {
                builder.expand(to: Point(x: a.center.x - a.radius, y: a.center.y - a.radius))
                builder.expand(to: Point(x: a.center.x + a.radius, y: a.center.y + a.radius))
            }
            if let f = frame.completedFill {
                for pt in f.points { builder.expand(to: pt) }
            }
            if let d = frame.newDot {
                let r = d.size / 2
                builder.expand(to: Point(x: d.center.x - r, y: d.center.y - r))
                builder.expand(to: Point(x: d.center.x + r, y: d.center.y + r))
            }
        }
        return builder.build()
    }

    public struct Builder: Sendable {
        private var minX = Double.infinity
        private var minY = Double.infinity
        private var maxX = -Double.infinity
        private var maxY = -Double.infinity

        public init() {}

        public mutating func expand(to point: Point) {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        public func build() -> DrawingBounds? {
            guard minX <= maxX && minY <= maxY else { return nil }
            return DrawingBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
        }
    }
}
