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
    let canvasSize: Size

    private(set) var currentFrameIndex: Int = -1
    /// Drawing elements in command-execution order.
    /// Fill polygons are inserted before their outline strokes so they render below them.
    private(set) var elements: [DrawElement] = []
    private(set) var backgroundColor: TortoiseCore.Color = .white
    private(set) var turtleState: TurtleState = .default

    /// Progress (0 → 1) through the animation of the next frame.
    /// Used by the renderer to interpolate turtle position and partial strokes.
    private(set) var animationProgress: Double = 0.0

    private var lastTickDate: Date?
    // Strokes/dots produced while isFillActive are held here until endFill,
    // then flushed after the fill polygon so the polygon renders below its outlines.
    private var pendingFillElements: [DrawElement] = []

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

    init(commands: [TurtleCommand], canvasSize: Size) {
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
            elements.removeAll()
            pendingFillElements.removeAll()
        }

        // endFill: insert the polygon first, then flush pending strokes/dots above it.
        if let f = frame.completedFill {
            elements.append(.fill(f))
            elements.append(contentsOf: pendingFillElements)
            pendingFillElements.removeAll()
        }

        if let s = frame.newStroke {
            if frame.isFillActive { pendingFillElements.append(.stroke(s)) }
            else                  { elements.append(.stroke(s)) }
        }
        if let a = frame.newArcStroke {
            if frame.isFillActive { pendingFillElements.append(.arcStroke(a)) }
            else                  { elements.append(.arcStroke(a)) }
        }
        if let d = frame.newDot {
            if frame.isFillActive { pendingFillElements.append(.dot(d)) }
            else                  { elements.append(.dot(d)) }
        }

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

// MARK: - DrawElement

enum DrawElement {
    case stroke(Stroke)
    case arcStroke(ArcStroke)
    case fill(Fill)
    case dot(Dot)
}
