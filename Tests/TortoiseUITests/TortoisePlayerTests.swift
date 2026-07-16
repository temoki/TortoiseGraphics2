import Foundation
import Observation
import Testing
import TortoiseCore

@testable import TortoiseUI

@Suite("TortoisePlayer / playback control")
@MainActor
struct TortoisePlayerTests {
    /// Four strokes at the default animated speed (5).
    private func makeSquareModel() -> CanvasModel {
        let tortoise = Tortoise()
        for _ in 0..<4 {
            tortoise.forward(100)
            tortoise.right(90)
        }
        return CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)
    }

    // MARK: - step

    @Test("step commits exactly one command instantly")
    func stepCommitsOneCommand() {
        let model = makeSquareModel()
        #expect(model.currentFrameIndex == -1)

        model.step()
        #expect(model.currentFrameIndex == 0)
        #expect(model.elements.count == 1)  // First forward stroke, in full.
        #expect(model.animationProgress == 0)

        model.step()
        #expect(model.currentFrameIndex == 1)  // The rotate: no new element.
        #expect(model.elements.count == 1)
    }

    @Test("step after the last command does nothing")
    func stepAtEndIsNoOp() {
        let model = makeSquareModel()
        for _ in 0..<10 { model.step() }
        #expect(model.isFinished)
        #expect(model.currentFrameIndex == model.frames.count - 1)
    }

    // MARK: - seek

    @Test("seek jumps forward and backward, rebuilding elements")
    func seekForwardAndBackward() {
        let model = makeSquareModel()

        model.seek(to: 4)  // forward, rotate, forward, rotate, forward
        #expect(model.currentFrameIndex == 4)
        #expect(model.elements.count == 3)

        model.seek(to: 0)  // Backward: only the first stroke remains.
        #expect(model.currentFrameIndex == 0)
        #expect(model.elements.count == 1)

        model.seek(to: -1)  // Rewind to before the first command.
        #expect(model.currentFrameIndex == -1)
        #expect(model.elements.isEmpty)
        #expect(model.tortoiseState == .default)
    }

    @Test("seek clamps out-of-range indices")
    func seekClamps() {
        let model = makeSquareModel()
        model.seek(to: 100)
        #expect(model.currentFrameIndex == model.frames.count - 1)
        #expect(model.isFinished)
        model.seek(to: -100)
        #expect(model.currentFrameIndex == -1)
    }

    @Test("seek across a fill preserves fill z-order")
    func seekRebuildsFillOrdering() {
        let tortoise = Tortoise()
        tortoise.beginFill()
        for _ in 0..<3 {
            tortoise.forward(80)
            tortoise.right(120)
        }
        tortoise.endFill()
        let model = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)

        // Seek into the middle of the fill, then to the end: the completed
        // fill polygon must still be inserted below its outline strokes.
        model.seek(to: 3)
        model.seek(to: model.frames.count - 1)
        #expect(model.elements.count == 4)  // fill + 3 strokes
        guard case .fill = model.elements.first else {
            Issue.record("elements[0] should be the fill polygon (below its outline)")
            return
        }
    }

    // MARK: - speedOverride

    @Test("speedOverride 0 flushes playback instantly")
    func speedOverrideZeroIsInstant() {
        let model = makeSquareModel()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        model.tick(date: t0, speedOverride: 0)  // Establishes the baseline…
        model.tick(date: t0.addingTimeInterval(0.001), speedOverride: 0)  // …then flushes.
        #expect(model.isFinished)
    }

    @Test("speedOverride takes precedence over the stream speed")
    func speedOverrideTakesPrecedence() {
        // At the stream's speed 1 (0.5 s per command) the ticks below can
        // commit at most the .speed frame itself — no stroke appears; with
        // an override of 10 (0.05 s per command) the strokes are committed.
        let tortoise = Tortoise()
        tortoise.speed = 1
        tortoise.forward(100)
        tortoise.forward(100)
        let t0 = Date(timeIntervalSinceReferenceDate: 0)

        let slow = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)
        slow.tick(date: t0)
        slow.tick(date: t0.addingTimeInterval(0.12))
        slow.tick(date: t0.addingTimeInterval(0.24))
        #expect(slow.elements.isEmpty)

        let overridden = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)
        overridden.tick(date: t0, speedOverride: 10)
        overridden.tick(date: t0.addingTimeInterval(0.12), speedOverride: 10)
        overridden.tick(date: t0.addingTimeInterval(0.24), speedOverride: 10)
        #expect(!overridden.elements.isEmpty)
    }

    @Test("changing speedOverride preserves the playback position")
    func speedOverrideChangeDoesNotRewind() {
        let model = makeSquareModel()
        var date = Date(timeIntervalSinceReferenceDate: 0)
        model.tick(date: date, speedOverride: 10)
        for _ in 0..<4 {
            date = date.addingTimeInterval(0.06)
            model.tick(date: date, speedOverride: 10)
        }
        let position = model.currentFrameIndex
        #expect(position > -1)

        date = date.addingTimeInterval(0.06)
        model.tick(date: date, speedOverride: 1)  // Live slow-down…
        #expect(model.currentFrameIndex >= position)  // …never rewinds.
    }

    // MARK: - pause / resume

    @Test("resetTickBaseline swallows the time spent paused")
    func resetTickBaselinePreventsJumpAfterPause() {
        let model = makeSquareModel()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        model.tick(date: t0)
        model.tick(date: t0.addingTimeInterval(0.12))  // Speed 5 → one command.
        let positionAtPause = model.currentFrameIndex
        #expect(positionAtPause == 0)

        // Paused for 100 s (no ticks), then resumed: the first tick must only
        // re-establish the baseline instead of replaying 100 s at once.
        model.resetTickBaseline()
        model.tick(date: t0.addingTimeInterval(100))
        #expect(model.currentFrameIndex == positionAtPause)

        model.tick(date: t0.addingTimeInterval(100.12))  // Normal cadence resumes.
        #expect(model.currentFrameIndex == positionAtPause + 1)
    }

    // MARK: - TortoisePlayer forwarding

    @Test("detached player reports defaults and ignores commands")
    func detachedPlayerIsInert() {
        let player = TortoisePlayer()
        #expect(player.currentCommandIndex == -1)
        #expect(!player.isFinished)
        player.step()
        player.seek(to: 3)
        player.isPaused = true
        player.isPaused = false
    }

    @Test("attached player mirrors and controls the model")
    func attachedPlayerControlsModel() {
        let model = makeSquareModel()
        let player = TortoisePlayer()
        player.model = model

        #expect(player.currentCommandIndex == -1)
        player.step()
        #expect(player.currentCommandIndex == 0)
        player.seek(to: model.frames.count - 1)
        #expect(player.isFinished)
        player.seek(to: -1)
        #expect(player.currentCommandIndex == -1)
        #expect(!player.isFinished)
    }

    @Test("currentCommandIndex participates in observation")
    func currentCommandIndexIsObservable() async {
        let model = makeSquareModel()
        let player = TortoisePlayer()
        player.model = model

        await confirmation("observation fires") { fired in
            withObservationTracking {
                _ = player.currentCommandIndex
            } onChange: {
                fired()
            }
            player.step()
        }
    }
}
