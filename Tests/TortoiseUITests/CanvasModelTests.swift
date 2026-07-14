import Foundation
import Testing
import TortoiseCore

@testable import TortoiseUI

// These tests pin down `isFinished`, which TortoiseCanvas uses to pause its
// TimelineView schedule once playback completes.
@Suite("CanvasModel playback")
@MainActor
struct CanvasModelTests {
    @Test("empty command stream is finished at init")
    func emptyStreamIsFinished() {
        let model = CanvasModel(commands: [], canvasSize: .defaultCanvas)
        #expect(model.isFinished)
    }

    @Test("instant mode is finished at init without any ticks")
    func instantModeIsFinishedAtInit() {
        let tortoise = Tortoise()
        tortoise.speed = 0
        tortoise.forward(100)
        let model = CanvasModel(commands: tortoise.commands, canvasSize: tortoise.canvasSize)
        #expect(model.isFinished)
        #expect(model.elements.count == 1)
    }

    @Test("animated playback finishes after enough ticks")
    func animatedPlaybackFinishes() {
        let tortoise = Tortoise()
        tortoise.forward(100)
        tortoise.right(90)
        tortoise.forward(100)
        let model = CanvasModel(commands: tortoise.commands, canvasSize: tortoise.canvasSize)
        #expect(!model.isFinished)

        // Default speed 5 → 0.1 s per step; 3 commands ≈ 0.3 s of animation.
        var date = Date(timeIntervalSinceReferenceDate: 0)
        model.tick(date: date)  // First tick only establishes the time baseline.
        for _ in 0..<20 {
            date = date.addingTimeInterval(0.05)
            model.tick(date: date)
        }

        #expect(model.isFinished)
        #expect(model.elements.count == 2)  // Two strokes; rotate draws nothing.
        #expect(model.animationProgress == 0)
    }

    @Test("ticking a finished model changes nothing")
    func tickAfterFinishedIsNoOp() {
        let tortoise = Tortoise()
        tortoise.speed = 0
        tortoise.forward(100)
        let model = CanvasModel(commands: tortoise.commands, canvasSize: tortoise.canvasSize)
        #expect(model.isFinished)

        let indexBefore = model.currentFrameIndex
        model.tick(date: Date())
        model.tick(date: Date().addingTimeInterval(1))
        #expect(model.currentFrameIndex == indexBefore)
        #expect(model.isFinished)
    }
}
