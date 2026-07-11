import Foundation
import Observation
import TortoiseCore

/// Drives incremental playback of a ``TurtleCommand`` stream for animation.
///
/// Call ``tick(date:)`` on every `TimelineView` update. The model advances
/// one frame per tick (or multiple frames for speed 0 / instant mode).
@Observable
@MainActor
final class CanvasModel {
    let frames: [PlaybackFrame]
    let canvasSize: Size2D

    private(set) var currentFrameIndex: Int = -1
    private(set) var strokes: [Stroke] = []
    private(set) var arcStrokes: [ArcStroke] = []
    private(set) var fills: [Fill] = []
    private(set) var backgroundColor: TortoiseCore.Color = .white
    private(set) var turtleState: TurtleState = .default

    private var lastTickDate: Date?
    private var timeUntilNextFrame: TimeInterval = 0

    var isFinished: Bool { frames.isEmpty || currentFrameIndex >= frames.count - 1 }

    init(commands: [TurtleCommand], canvasSize: Size2D) {
        self.frames = CommandPlayer.play(commands: commands)
        self.canvasSize = canvasSize
        if let first = frames.first {
            self.backgroundColor = first.backgroundColor
        }
    }

    func tick(date: Date) {
        guard !isFinished else { return }
        guard let last = lastTickDate else {
            lastTickDate = date
            advanceWhileReady()
            return
        }
        let elapsed = date.timeIntervalSince(last)
        lastTickDate = date
        timeUntilNextFrame -= elapsed
        if timeUntilNextFrame <= 0 {
            advanceWhileReady()
        }
    }

    // MARK: - Private helpers

    private func advanceWhileReady() {
        repeat {
            advance()
        } while !isFinished && turtleState.speed <= 0

        timeUntilNextFrame = isFinished ? 0 : Self.stepDuration(speed: turtleState.speed)
    }

    private func advance() {
        let nextIndex = currentFrameIndex + 1
        guard nextIndex < frames.count else { return }
        let frame = frames[nextIndex]
        if frame.didClear {
            strokes.removeAll()
            arcStrokes.removeAll()
            fills.removeAll()
        }
        if let s = frame.newStroke { strokes.append(s) }
        if let a = frame.newArcStroke { arcStrokes.append(a) }
        if let f = frame.completedFill { fills.append(f) }
        backgroundColor = frame.backgroundColor
        turtleState = frame.turtleState
        currentFrameIndex = nextIndex
    }

    private static func stepDuration(speed: Double) -> TimeInterval {
        0.5 / max(1, speed)  // speed 1 = 0.5 s/step, speed 10 = 0.05 s/step
    }
}
