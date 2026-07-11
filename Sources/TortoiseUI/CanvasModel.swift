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
    private(set) var dots: [Dot] = []
    private(set) var backgroundColor: TortoiseCore.Color = .white
    private(set) var turtleState: TurtleState = .default

    /// Progress (0 → 1) through the animation of the next frame.
    /// Used by the renderer to interpolate turtle position and partial strokes.
    private(set) var animationProgress: Double = 0.0

    private var lastTickDate: Date?

    var isFinished: Bool { frames.isEmpty || currentFrameIndex >= frames.count - 1 }

    /// The frame currently being animated toward; nil when playback is finished.
    var inProgressFrame: PlaybackFrame? {
        guard !isFinished else { return nil }
        return frames[currentFrameIndex + 1]
    }

    /// Playback speed of the last committed frame (governs animation timing).
    private var committedSpeed: Double {
        currentFrameIndex >= 0 ? frames[currentFrameIndex].turtleState.speed
                               : TurtleState.default.speed
    }

    init(commands: [TurtleCommand], canvasSize: Size2D) {
        self.frames = CommandPlayer.play(commands: commands)
        self.canvasSize = canvasSize
        if let first = frames.first {
            self.backgroundColor = first.backgroundColor
        }
        // Eagerly flush all frames when the program is in instant mode (speed=0
        // is established before the first visible drawing command). This makes
        // instant-mode programs visible in static Xcode Previews where
        // TimelineView never fires and tick() is never called.
        if Self.isInstantMode(frames: frames) {
            while !isFinished { advance() }
        }
    }

    func tick(date: Date) {
        guard !isFinished else { return }
        guard let last = lastTickDate else {
            lastTickDate = date
            return
        }
        let elapsed = date.timeIntervalSince(last)
        lastTickDate = date

        // Instant mode: flush all consecutive instant frames and bail out.
        if committedSpeed <= 0 {
            while !isFinished && committedSpeed <= 0 { advance() }
            animationProgress = 0
            return
        }

        let stepDur = Self.stepDuration(speed: committedSpeed)
        animationProgress += elapsed / stepDur

        while animationProgress >= 1.0 && !isFinished {
            animationProgress -= 1.0
            advance()
            // After committing, flush any trailing instant frames.
            while !isFinished && committedSpeed <= 0 { advance() }
            if isFinished { animationProgress = 0; break }
        }
        animationProgress = min(animationProgress, 1.0)
    }

    // MARK: - Private helpers

    private func advance() {
        let nextIndex = currentFrameIndex + 1
        guard nextIndex < frames.count else { return }
        let frame = frames[nextIndex]
        if frame.didClear {
            strokes.removeAll()
            arcStrokes.removeAll()
            fills.removeAll()
            dots.removeAll()
        }
        if let s = frame.newStroke { strokes.append(s) }
        if let a = frame.newArcStroke { arcStrokes.append(a) }
        if let f = frame.completedFill { fills.append(f) }
        if let d = frame.newDot { dots.append(d) }
        backgroundColor = frame.backgroundColor
        turtleState = frame.turtleState
        currentFrameIndex = nextIndex
    }

    private static func stepDuration(speed: Double) -> TimeInterval {
        0.5 / max(1, speed)  // speed 1 = 0.5 s/step, speed 10 = 0.05 s/step
    }

    /// Returns true if speed reaches 0 before the first frame that produces visible output.
    private static func isInstantMode(frames: [PlaybackFrame]) -> Bool {
        for frame in frames {
            if frame.turtleState.speed <= 0 { return true }
            if frame.newStroke != nil || frame.newArcStroke != nil || frame.completedFill != nil || frame.newDot != nil {
                return false
            }
        }
        return false
    }
}
