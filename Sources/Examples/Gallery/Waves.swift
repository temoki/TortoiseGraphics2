import SwiftUI
import TortoiseUI

/// A wave built from half-circle arcs: flipping the sign of the radius
/// flips which side the arc bends to (see `circle(radius:extent:)`),
/// so alternating signs traces crests and troughs.
enum Waves {
    @MainActor
    static func draw(_ 🐢: Tortoise) {
        🐢.backgroundColor = .white
        🐢.speed = 10
        🐢.penWidth = 2.5
        🐢.penUp()
        🐢.setPosition(x: -180, y: 0)
        🐢.heading = 180
        🐢.penDown()
        for i in 0..<6 {
            🐢.penColor = i.isMultiple(of: 2) ? .blue : .cyan
            // Crest, trough, crest, … — only the radius sign changes.
            🐢.circle(radius: i.isMultiple(of: 2) ? 30 : -30, extent: 180)
        }
    }
}

#Preview("Waves") {
    TortoiseCanvas(Waves.draw)
        .padding()
}
