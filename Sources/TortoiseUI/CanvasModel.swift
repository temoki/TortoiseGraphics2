import Foundation
import Observation
import TortoiseCore

/// Drives incremental playback of a ``TortoiseCommand`` stream for animation.
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
    private(set) var tortoiseState: TortoiseState = .default

    /// Progress (0 → 1) through the animation of the next frame.
    /// Used by the renderer to interpolate tortoise position and partial strokes.
    private(set) var animationProgress: Double = 0.0

    /// Axis-aligned bounding box of all drawing output across all frames, in tortoise coordinates.
    /// `nil` when the command stream produces no visible output.
    let drawingBounds: DrawingBounds?

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
        currentFrameIndex >= 0
            ? frames[currentFrameIndex].tortoiseState.speed
            : TortoiseState.default.speed
    }

    init(commands: [TortoiseCommand], canvasSize: Size) {
        self.frames = CommandPlayer.play(commands: commands)
        self.canvasSize = canvasSize
        if let first = frames.first {
            self.backgroundColor = first.backgroundColor
        }
        self.drawingBounds = Self.computeDrawingBounds(frames: self.frames)
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
            if isFinished {
                animationProgress = 0
                break
            }
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
            if frame.isFillActive {
                pendingFillElements.append(.stroke(s))
            }
            else {
                elements.append(.stroke(s))
            }
        }
        if let a = frame.newArcStroke {
            if frame.isFillActive {
                pendingFillElements.append(.arcStroke(a))
            }
            else {
                elements.append(.arcStroke(a))
            }
        }
        if let d = frame.newDot {
            if frame.isFillActive {
                pendingFillElements.append(.dot(d))
            }
            else {
                elements.append(.dot(d))
            }
        }

        backgroundColor = frame.backgroundColor
        tortoiseState = frame.tortoiseState
        currentFrameIndex = nextIndex
    }

    private static func stepDuration(speed: Double) -> TimeInterval {
        0.5 / max(1, speed)  // speed 1 = 0.5 s/step, speed 10 = 0.05 s/step
    }

    /// Returns true if speed reaches 0 before the first frame that produces visible output.
    private static func isInstantMode(frames: [PlaybackFrame]) -> Bool {
        for frame in frames {
            if frame.tortoiseState.speed <= 0 { return true }
            if frame.newStroke != nil || frame.newArcStroke != nil || frame.completedFill != nil
                || frame.newDot != nil
            {
                return false
            }
        }
        return false
    }

    /// Computes the bounding box of all visible output across all frames.
    private static func computeDrawingBounds(frames: [PlaybackFrame]) -> DrawingBounds? {
        var builder = DrawingBounds.Builder()
        for frame in frames {
            if frame.didClear { builder = DrawingBounds.Builder() }
            if let s = frame.newStroke {
                builder.expand(to: s.from)
                builder.expand(to: s.to)
            }
            if let a = frame.newArcStroke {
                // Use full-circle bbox (center ± radius) — conservative but always correct.
                builder.expand(to: Point(x: a.center.x - a.radius, y: a.center.y - a.radius))
                builder.expand(to: Point(x: a.center.x + a.radius, y: a.center.y + a.radius))
            }
            if let f = frame.completedFill {
                for pt in f.points { builder.expand(to: pt) }
            }
            if let d = frame.newDot {
                let r = d.size / 2
                builder.expand(to: Point(x: d.center.x - r, y: d.center.y - r))
                builder.expand(to: Point(x: d.center.x + r, y: d.center.y + r))
            }
        }
        return builder.build()
    }
}

// MARK: - DrawElement

enum DrawElement {
    case stroke(Stroke)
    case arcStroke(ArcStroke)
    case fill(Fill)
    case dot(Dot)
}

// MARK: - DrawingBounds

/// Axis-aligned bounding box of drawing output in tortoise coordinate space.
struct DrawingBounds {
    let minX, minY, maxX, maxY: Double

    var width: Double { maxX - minX }
    var height: Double { maxY - minY }
    var centerX: Double { (minX + maxX) / 2 }
    var centerY: Double { (minY + maxY) / 2 }

    struct Builder {
        private var minX = Double.infinity
        private var minY = Double.infinity
        private var maxX = -Double.infinity
        private var maxY = -Double.infinity

        mutating func expand(to point: Point) {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        func build() -> DrawingBounds? {
            guard minX <= maxX && minY <= maxY else { return nil }
            return DrawingBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
        }
    }
}
