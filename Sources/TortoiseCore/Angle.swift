import Foundation

/// A geometric angle, storable as degrees.
public struct Angle: Sendable, Hashable {
    public var degrees: Double

    public init(degrees: Double) {
        self.degrees = degrees
    }

    public init(radians: Double) {
        self.degrees = radians * (180 / .pi)
    }

    public var radians: Double {
        degrees * (.pi / 180)
    }

    public static let zero = Angle(degrees: 0)
}

extension Angle {
    public static func + (lhs: Angle, rhs: Angle) -> Angle {
        Angle(degrees: lhs.degrees + rhs.degrees)
    }

    public static func - (lhs: Angle, rhs: Angle) -> Angle {
        Angle(degrees: lhs.degrees - rhs.degrees)
    }

    public static prefix func - (angle: Angle) -> Angle {
        Angle(degrees: -angle.degrees)
    }
}
