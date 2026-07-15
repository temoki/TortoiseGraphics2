import SwiftUI
import TortoiseCore
import TortoiseUI

/// SwiftUI declares a `Color` too; in this file we mean the tortoise one.
private typealias Color = TortoiseCore.Color

/// A square spiral that walks a little farther on every turn,
/// cycling the pen through the rainbow as it goes.
enum SquareSpiral {
    @MainActor
    static func draw(_ 🐢: Tortoise) {
        🐢.backgroundColor = .white
        🐢.speed = 10
        🐢.penWidth = 2
        for i in 0..<60 {
            🐢.penColor = rainbow(Double(i) / 60)
            🐢.forward(4 + Double(i) * 3)
            // A hair more than 90° makes the whole spiral slowly rotate.
            🐢.right(90.5)
        }
    }

    /// Maps a hue in 0...1 onto the RGB rainbow.
    private static func rainbow(_ hue: Double) -> Color {
        let h = hue * 6
        let x = 1 - abs(h.truncatingRemainder(dividingBy: 2) - 1)
        switch h {
        case ..<1: return Color(red: 1, green: x, blue: 0)
        case ..<2: return Color(red: x, green: 1, blue: 0)
        case ..<3: return Color(red: 0, green: 1, blue: x)
        case ..<4: return Color(red: 0, green: x, blue: 1)
        case ..<5: return Color(red: x, green: 0, blue: 1)
        default: return Color(red: 1, green: 0, blue: x)
        }
    }
}

#Preview("Square Spiral") {
    TortoiseCanvas(SquareSpiral.draw)
        .padding()
}
