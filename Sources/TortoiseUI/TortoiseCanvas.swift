import SwiftUI
import TortoiseCore

/// A SwiftUI view that renders and animates tortoise-graphics commands.
///
/// Pass a ``Tortoise`` instance, or describe the drawing inline with a closure.
/// The view plays back the command stream using `TimelineView` and `Canvas`.
/// Use `.tortoiseViewport(_:)` to control how the drawing maps onto the view.
///
/// ```swift
/// // Existing-instance form
/// TortoiseCanvas(🐢)
///
/// // Closure form
/// TortoiseCanvas { 🐢 in
///     🐢.speed = 0
///     for _ in 1...4 {
///         🐢.forward(100)
///         🐢.right(90)
///     }
/// }
/// ```
public struct TortoiseCanvas: View {
    private let tortoise: Tortoise
    private let player: TortoisePlayer?

    @State private var model: CanvasModel

    /// Creates a canvas view for the given tortoise.
    ///
    /// Commands already in the tortoise at construction time are reflected
    /// immediately. Commands added after the view appears are picked up
    /// automatically via a `task(id:)` observer.
    @MainActor
    public init(_ tortoise: Tortoise) {
        self.init(tortoise, player: nil)
    }

    /// Creates a canvas view whose playback is controlled by `player`.
    ///
    /// The player provides pause/resume, single-step, seek, and a viewer-side
    /// speed override, and exposes the current playback position for
    /// observation. See ``TortoisePlayer``.
    @MainActor
    public init(_ tortoise: Tortoise, player: TortoisePlayer) {
        self.init(tortoise, player: Optional(player))
    }

    /// Creates a canvas view by configuring a new ``Tortoise`` inside the closure.
    ///
    /// The closure runs once at init time. Use `speed(0)` to make the drawing
    /// visible in static Xcode Previews.
    @MainActor
    public init(_ draw: @MainActor (Tortoise) -> Void) {
        let tortoise = Tortoise()
        draw(tortoise)
        self.init(tortoise, player: nil)
    }

    @MainActor
    private init(_ tortoise: Tortoise, player: TortoisePlayer?) {
        self.tortoise = tortoise
        self.player = player
        self._model = State(
            wrappedValue: CanvasModel(
                commands: tortoise.commands, canvasSize: tortoise.canvasSize,
                sourceKey: TortoiseChangeKey(tortoise))
        )
    }

    public var body: some View {
        // Two stacked Canvases so committed output doesn't re-render at
        // display refresh rate (#35): rebuilding every element's Path each
        // frame is O(elements) and visibly stutters at a few hundred
        // commands. Both layers must agree on the viewport transform — the
        // ZStack proposes the same size to each, and the transform is a pure
        // function of (canvasSize, viewSize, drawingBounds).
        ZStack {
            CommittedLayer(model: model)
            AnimationLayer(model: model, player: player)
        }
        .task(id: TortoiseChangeKey(tortoise)) {
            // Guard: init already created a model for the current content;
            // only recreate when the tortoise has been mutated since
            // (commands appended, or reset() — even if commands.count is back
            // to the same value afterwards) or swapped for another instance.
            if TortoiseChangeKey(tortoise) != model.sourceKey {
                model = CanvasModel(
                    commands: tortoise.commands, canvasSize: tortoise.canvasSize,
                    sourceKey: TortoiseChangeKey(tortoise))
            }
            // (Re)attach the player to the model that is actually on screen.
            player?.model = model
        }
    }
}

// MARK: - Layers

/// Background + all committed drawing elements. Lives outside the
/// `TimelineView` so it re-renders only when a frame commits, not on every
/// animation tick.
private struct CommittedLayer: View {
    let model: CanvasModel
    @Environment(\.tortoiseViewport) private var viewportMode

    var body: some View {
        // Snapshot the committed properties during body evaluation: these
        // reads register observation at the body level, so the layer
        // invalidates exactly when a frame commits (or step/seek/clear
        // rebuilds elements) — without relying on tracking inside the
        // Canvas rendering closure.
        let elements = model.elements
        let background = model.backgroundColor
        Canvas { ctx, size in
            let t = viewportMode.transform(
                canvasSize: model.canvasSize, viewSize: size,
                drawingBounds: model.drawingBounds)
            let s = (t.a * t.a + t.b * t.b).squareRoot()
            CanvasRenderer.drawBackground(&ctx, size: size, color: background)
            CanvasRenderer.drawElements(&ctx, elements: elements, transform: t, scale: s)
        }
    }
}

/// The stroke/arc currently being animated and the tortoise sprite — the
/// only content that changes every display frame. Hosts the `TimelineView`
/// that drives playback ticks.
private struct AnimationLayer: View {
    let model: CanvasModel
    let player: TortoisePlayer?
    @Environment(\.tortoiseViewport) private var viewportMode

    var body: some View {
        // Pause the schedule once playback finishes (or while the player is
        // paused) so the view stops redrawing at display refresh rate;
        // replacing the model (via task(id:)) or resuming the player restarts it.
        TimelineView(.animation(paused: model.isFinished || (player?.isPaused ?? false))) {
            timeline in
            Canvas { ctx, size in
                let t = viewportMode.transform(
                    canvasSize: model.canvasSize, viewSize: size,
                    drawingBounds: model.drawingBounds)
                let s = (t.a * t.a + t.b * t.b).squareRoot()
                if let next = model.inProgressFrame, model.animationProgress > 0 {
                    CanvasRenderer.drawInProgress(
                        &ctx, frame: next, progress: model.animationProgress,
                        transform: t, scale: s)
                }
                CanvasRenderer.drawTortoise(
                    &ctx, state: model.tortoiseState,
                    interpolatingTo: model.inProgressFrame?.tortoiseState,
                    progress: model.animationProgress,
                    transform: t, scale: s)
            }
            .onChange(of: timeline.date) { _, date in
                model.tick(date: date, speedOverride: player?.speedOverride)
            }
        }
    }
}

// MARK: - Viewport modifier

extension EnvironmentValues {
    @Entry var tortoiseViewport: ViewportMode = .autoFit
}

extension View {
    /// Sets the viewport mode for any ``TortoiseCanvas`` in the view hierarchy.
    public func tortoiseViewport(_ mode: ViewportMode) -> some View {
        environment(\.tortoiseViewport, mode)
    }
}

// MARK: - Preview

#Preview("Tortoise Star") {
    TortoiseCanvas { 🐢 in
        🐢.penColor = .orange
        🐢.penWidth = 2
        for _ in 1...36 {
            🐢.forward(200)
            🐢.right(170)
        }
    }
}

#Preview("Animated Square") {
    TortoiseCanvas { 🐢 in
        🐢.speed = 5
        🐢.penColor = .blue
        for _ in 1...4 {
            🐢.forward(100)
            🐢.right(90)
        }
    }
}
