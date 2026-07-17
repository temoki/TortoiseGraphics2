import SwiftUI
import TortoiseCore
import TortoiseUI

/// SwiftUI declares a `Color` too; in this file we mean the tortoise one.
private typealias Color = TortoiseCore.Color

/// A recursive binary tree: every branch forks into two smaller ones,
/// thick and brown near the trunk, thin and green at the tips.
enum FractalTree {
    @MainActor
    static func draw(_ 🐢: Tortoise) {
        🐢.backgroundColor = .white
        // Recursion produces thousands of commands — draw instantly.
        🐢.speed = 0
        🐢.penUp()
        🐢.setPosition(x: 0, y: -170)
        🐢.penDown()
        branch(🐢, length: 90, depth: 9)
    }

    @MainActor
    private static func branch(_ 🐢: Tortoise, length: Double, depth: Int) {
        guard depth > 0 else { return }
        🐢.penWidth = Double(depth) * 0.8
        🐢.penColor = depth > 3 ? Color(red: 0.35, green: 0.23, blue: 0.11) : .green
        🐢.forward(length)
        🐢.left(25)
        branch(🐢, length: length * 0.75, depth: depth - 1)
        🐢.right(50)
        branch(🐢, length: length * 0.75, depth: depth - 1)
        🐢.left(25)
        🐢.penUp()
        🐢.backward(length)
        🐢.penDown()
    }
}

#Preview("Fractal Tree") {
    TortoiseCanvas(FractalTree.draw)
        .padding()
}
