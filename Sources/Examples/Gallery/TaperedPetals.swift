import SwiftUI
import TortoiseCore
import TortoiseUI

/// A rosette of petals drawn with a pen that thickens and thins as it goes.
///
/// Each petal is two tapered arcs: out from the centre with the pen swelling,
/// back again with it closing to a point. Because a taper is a single command
/// rather than a run of stepped-width segments, each arc here is one playback
/// frame and one filled region — the petals animate at the same pace as any
/// other arc, and the translucent fills blend once rather than darkening
/// wherever sub-segments would have overlapped.
enum TaperedPetals {
    @MainActor
    static func draw(_ 🐢: Tortoise) {
        🐢.backgroundColor = TortoiseCore.Color(red: 0.07, green: 0.07, blue: 0.12)
        🐢.speed = 10

        let petals = 9
        for i in 0..<petals {
            let hue = Double(i) / Double(petals)
            🐢.penColor = petalColor(hue: hue)
            🐢.penUp()
            🐢.home()
            🐢.heading = hue * 360
            🐢.penDown()

            🐢.penWidth = 1
            🐢.circle(radius: 90, extent: 110, widthTo: 13)
            🐢.circle(radius: 90, extent: 110, widthTo: 1)
        }
    }

    /// A hue sweep around the rosette.
    ///
    /// Opaque on purpose: the two arcs of a petal meet cap-to-cap at its tip,
    /// and two translucent marks sharing a cap blend twice there — the same
    /// double-blend any two overlapping translucent strokes have always had,
    /// but conspicuous as a dot when it lands on a showcase drawing.
    private static func petalColor(hue: Double) -> TortoiseCore.Color {
        let angle = hue * 2 * .pi
        return TortoiseCore.Color(
            red: 0.55 + 0.45 * cos(angle),
            green: 0.45 + 0.4 * cos(angle - 2.1),
            blue: 0.6 + 0.4 * cos(angle - 4.2),
            alpha: 1
        )
    }
}

#Preview("Tapered Petals") {
    TortoiseCanvas(TaperedPetals.draw)
        .padding()
}
