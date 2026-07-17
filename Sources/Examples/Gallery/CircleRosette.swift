import SwiftUI
import TortoiseCore
import TortoiseUI

/// SwiftUI declares a `Color` too; in this file we mean the tortoise one.
private typealias Color = TortoiseCore.Color

/// Twelve overlapping circles, each rotated 30° from the last —
/// the classic turtle-graphics flower.
enum CircleRosette {
    @MainActor
    static func draw(_ 🐢: Tortoise) {
        🐢.backgroundColor = .white
        🐢.speed = 10
        🐢.penWidth = 1.5
        let petals: [Color] = [.red, .orange, .magenta, .purple]
        for i in 0..<12 {
            🐢.penColor = petals[i % petals.count]
            🐢.circle(radius: 80)
            🐢.right(30)
        }
    }
}

#Preview("Circle Rosette") {
    TortoiseCanvas(CircleRosette.draw)
        .padding()
}
