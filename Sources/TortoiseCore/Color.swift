/// A platform-independent RGBA color with components in 0…1.
///
/// In `TortoiseUI`, use the provided `SwiftUI.Color` extension to convert.
public struct Color: Sendable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red.clamped01
        self.green = green.clamped01
        self.blue = blue.clamped01
        self.alpha = alpha.clamped01
    }

    public init(white: Double, alpha: Double = 1) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }
}

extension Color {
    public static let black = Color(red: 0, green: 0, blue: 0)
    public static let white = Color(red: 1, green: 1, blue: 1)
    public static let red = Color(red: 1, green: 0, blue: 0)
    public static let green = Color(red: 0, green: 0.502, blue: 0)
    public static let blue = Color(red: 0, green: 0, blue: 1)
    public static let yellow = Color(red: 1, green: 1, blue: 0)
    public static let orange = Color(red: 1, green: 0.502, blue: 0)
    public static let purple = Color(red: 0.502, green: 0, blue: 0.502)
    public static let cyan = Color(red: 0, green: 1, blue: 1)
    public static let magenta = Color(red: 1, green: 0, blue: 1)
    public static let clear = Color(red: 0, green: 0, blue: 0, alpha: 0)

    /// The background every ``Tortoise`` starts with, and the value
    /// ``CommandPlayer`` replays from when a stream sets no background of its
    /// own — the single source of truth for "no `.backgroundColor` command
    /// was issued". Renderers must not substitute their own fallback, or the
    /// tortoise and the drawing disagree about the color of the paper (#44).
    ///
    /// Pass `Color.clear` explicitly (`tortoise.backgroundColor = .clear`) for
    /// a transparent canvas.
    public static let defaultBackground = white
}

extension Double {
    fileprivate var clamped01: Double { Swift.min(Swift.max(self, 0), 1) }
}
