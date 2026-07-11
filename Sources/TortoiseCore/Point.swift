import Foundation

/// A 2D point or vector in turtle-graphics coordinate space
/// (center origin, Y axis points up).
public struct Point: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }

    public static let zero = Point()

    public static func + (lhs: Point, rhs: Point) -> Point {
        Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Point, rhs: Point) -> Point {
        Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public var magnitude: Double {
        (x * x + y * y).squareRoot()
    }

    public func distance(to other: Point) -> Double {
        (self - other).magnitude
    }
}

extension Point {
    /// Returns the point reached by moving `distance` in the direction of `heading`.
    /// Heading convention: 0 = north (up), clockwise positive.
    func moved(distance: Double, heading: Double) -> Point {
        let rad = heading * (.pi / 180)
        return Point(x: x + distance * sin(rad), y: y + distance * cos(rad))
    }
}
