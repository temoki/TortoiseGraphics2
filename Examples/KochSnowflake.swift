import SwiftUI
import TortoiseUI

/// The Koch snowflake: a triangle whose every side is replaced,
/// four levels deep, by a line with a triangular bump.
enum KochSnowflake {
    @MainActor
    static func draw(_ 🐢: Tortoise) {
        🐢.backgroundColor = .white
        // 768 tiny segments — draw instantly.
        🐢.speed = 0
        🐢.penColor = .blue
        🐢.penWidth = 1.5
        🐢.penUp()
        🐢.setPosition(x: -150, y: 87)
        🐢.heading = 90
        🐢.penDown()
        for _ in 0..<3 {
            side(🐢, length: 300, depth: 4)
            🐢.right(120)
        }
    }

    @MainActor
    private static func side(_ 🐢: Tortoise, length: Double, depth: Int) {
        guard depth > 0 else {
            🐢.forward(length)
            return
        }
        let third = length / 3
        side(🐢, length: third, depth: depth - 1)
        🐢.left(60)
        side(🐢, length: third, depth: depth - 1)
        🐢.right(120)
        side(🐢, length: third, depth: depth - 1)
        🐢.left(60)
        side(🐢, length: third, depth: depth - 1)
    }
}

#Preview("Koch Snowflake") {
    TortoiseCanvas(KochSnowflake.draw)
        .padding()
}
