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
        let model = CanvasModel(commands: [], canvasSize: .defaultCanvas, sourceKey: nil)
        #expect(model.isFinished)
    }

    @Test("instant mode is finished at init without any ticks")
    func instantModeIsFinishedAtInit() {
        let tortoise = Tortoise()
        tortoise.speed = 0
        tortoise.forward(100)
        let model = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)
        #expect(model.isFinished)
        #expect(model.elements.count == 1)
    }

    @Test("animated playback finishes after enough ticks")
    func animatedPlaybackFinishes() {
        let tortoise = Tortoise()
        tortoise.forward(100)
        tortoise.right(90)
        tortoise.forward(100)
        let model = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)
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

    @Test("fill aborted by clear does not misplace a later fill")
    func fillAfterAbortedFillInsertsAtCorrectIndex() {
        let tortoise = Tortoise()
        tortoise.speed = 0
        tortoise.beginFill()
        tortoise.forward(50)
        tortoise.clear()
        tortoise.endFill()  // No-op: the fill was discarded by clear().
        tortoise.forward(60)  // Stroke drawn before the second fill begins.
        tortoise.beginFill()
        tortoise.right(120)
        tortoise.forward(60)
        tortoise.right(120)
        tortoise.forward(60)
        tortoise.endFill()
        let model = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)

        // Expected order: pre-fill stroke, then the fill polygon below its
        // own outline strokes — not below the unrelated earlier stroke.
        #expect(model.elements.count == 4)
        guard model.elements.count == 4 else { return }
        guard case .stroke = model.elements[0] else {
            Issue.record("elements[0] should be the pre-fill stroke")
            return
        }
        guard case .fill = model.elements[1] else {
            Issue.record("elements[1] should be the fill polygon")
            return
        }
    }

    @Test("change key detects reset + same-length reinjection")
    func changeKeyDetectsResetReinjection() {
        let tortoise = Tortoise()
        tortoise.forward(50)
        tortoise.right(90)
        let model = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize,
            sourceKey: TortoiseChangeKey(tortoise))

        tortoise.reset()
        tortoise.forward(80)
        tortoise.right(120)

        // A count-based key sees no change here — this is exactly the case
        // the TortoiseCanvas rebuild guard must catch via mutationCount.
        #expect(tortoise.commands.count == model.frames.count)
        #expect(TortoiseChangeKey(tortoise) != model.sourceKey)
    }

    @Test("change key detects swapping in a different Tortoise instance")
    func changeKeyDetectsInstanceSwap() {
        let original = Tortoise()
        original.forward(50)
        let model = CanvasModel(
            commands: original.commands, canvasSize: original.canvasSize,
            sourceKey: TortoiseChangeKey(original))

        // Same program, same mutationCount — only the instance differs.
        // A mutation-count-only key would miss this swap.
        let replacement = Tortoise()
        replacement.forward(50)
        #expect(replacement.mutationCount == original.mutationCount)
        #expect(TortoiseChangeKey(replacement) != model.sourceKey)
    }

    @Test("ticking a finished model changes nothing")
    func tickAfterFinishedIsNoOp() {
        let tortoise = Tortoise()
        tortoise.speed = 0
        tortoise.forward(100)
        let model = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)
        #expect(model.isFinished)

        let indexBefore = model.currentFrameIndex
        model.tick(date: Date())
        model.tick(date: Date().addingTimeInterval(1))
        #expect(model.currentFrameIndex == indexBefore)
        #expect(model.isFinished)
    }
}
