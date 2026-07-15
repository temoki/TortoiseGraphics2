import SwiftUI
import TortoiseUI

/// A five-pointed star drawn with the classic 144° turn,
/// filled while it's being traced.
enum FilledStar {
    @MainActor
    static func draw(_ 🐢: Tortoise) {
        🐢.backgroundColor = .white
        🐢.speed = 8
        🐢.penColor = .orange
        🐢.fillColor = .yellow
        🐢.penWidth = 3
        🐢.penUp()
        🐢.setPosition(x: -80, y: 50)
        🐢.heading = 90
        🐢.penDown()
        🐢.beginFill()
        for _ in 0..<5 {
            🐢.forward(160)
            🐢.right(144)
        }
        🐢.endFill()
    }
}

#Preview("Filled Star") {
    TortoiseCanvas(FilledStar.draw)
        .padding()
}
