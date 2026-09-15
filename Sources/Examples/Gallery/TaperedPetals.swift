import SwiftUI
import TortoiseUI

/// A pinwheel of brush strokes, each one thick at the hub and vanishing at the
/// tip — drawn with the pen-width taper (see `forward(_:widthTo:)` and
/// `circle(radius:extent:widthTo:)`).
///
/// A taper is not a stroke primitive: the move is subdivided into short
/// constant-width segments, so this is an ordinary command stream. The step
/// count comes from the *width* change rather than the distance, which is why
/// the long curved petals here cost about as much as the short straight rays.
enum TaperedPetals {
    @MainActor
    static func draw(_ 🐢: Tortoise) {
        🐢.backgroundColor = .white
        🐢.speed = 10

        let petals = 12
        for i in 0..<petals {
            let t = Double(i) / Double(petals)

            // A curved petal: thick at the hub, tapering away to nothing.
            🐢.penUp()
            🐢.home()
            🐢.heading = t * 360
            🐢.penColor = hue(t)
            🐢.penWidth = 9
            🐢.penDown()
            🐢.circle(radius: 60, extent: 135, widthTo: 0.5)

            // A straight ray bisecting the gap, tapering the other way: broad
            // where it leaves the hub and sharpened to a point at the rim.
            🐢.penUp()
            🐢.home()
            🐢.heading = (t + 0.5 / Double(petals)) * 360
            🐢.forward(40)
            🐢.penColor = hue(t + 0.5)
            🐢.penWidth = 5
            🐢.penDown()
            🐢.forward(50, widthTo: 0.5)
        }

        🐢.penUp()
        🐢.home()
        🐢.penColor = .black
        🐢.dot(size: 14)
    }

    /// A smooth trip around the color wheel, so neighbouring strokes differ.
    private static func hue(_ t: Double) -> TortoiseCore.Color {
        func channel(_ phase: Double) -> Double {
            (sin((t + phase) * 2 * .pi) + 1) / 2
        }
        return TortoiseCore.Color(
            red: channel(0), green: channel(1.0 / 3), blue: channel(2.0 / 3))
    }
}

#Preview("Tapered Petals") {
    TortoiseCanvas(TaperedPetals.draw)
        .padding()
}
