import Foundation

/// A 2D point or vector in turtle-graphics coordinate space
/// (center origin, Y axis points up).
public struct Vec2D: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2D()

    public static func + (lhs: Vec2D, rhs: Vec2D) -> Vec2D {
        Vec2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Vec2D, rhs: Vec2D) -> Vec2D {
        Vec2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public var magnitude: Double {
        (x * x + y * y).squareRoot()
    }

    public func distance(to other: Vec2D) -> Double {
        (self - other).magnitude
    }
}

extension Vec2D {
    /// Returns the point reached by moving `distance` in the direction of `heading`.
    /// Heading convention: 0 = north (up), clockwise positive.
    func moved(distance: Double, heading: Double) -> Vec2D {
        let rad = heading * (.pi / 180)
        return Vec2D(x: x + distance * sin(rad), y: y + distance * cos(rad))
    }
}
