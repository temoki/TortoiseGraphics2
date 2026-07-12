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
/// TortoiseCanvasView(tortoise)
///     .tortoiseViewport(.autoFit(padding: 16))
///
/// // Closure form
/// TortoiseCanvasView { t in
///     t.speed = 0
///     for _ in 1...4 {
///         t.forward(100)
///         t.right(90)
///     }
/// }
/// ```
public struct TortoiseCanvasView: View {
    private let tortoise: Tortoise

    @State private var model: CanvasModel
    @Environment(\.tortoiseViewport) private var viewportMode

    /// Creates a canvas view for the given tortoise.
    ///
    /// Commands already in the tortoise at construction time are reflected
    /// immediately. Commands added after the view appears are picked up
    /// automatically via a `task(id:)` observer.
    @MainActor
    public init(_ tortoise: Tortoise) {
        self.tortoise = tortoise
        self._model = State(
            wrappedValue: CanvasModel(commands: tortoise.commands, canvasSize: tortoise.canvasSize)
        )
    }

    /// Creates a canvas view by configuring a new ``Tortoise`` inside the closure.
    ///
    /// The closure runs once at init time. Use `speed(0)` to make the drawing
    /// visible in static Xcode Previews.
    @MainActor
    public init(_ draw: @MainActor (Tortoise) -> Void) {
        let tortoise = Tortoise()
        draw(tortoise)
        self.tortoise = tortoise
        self._model = State(
            wrappedValue: CanvasModel(commands: tortoise.commands, canvasSize: tortoise.canvasSize)
        )
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = viewportMode.transform(
                    canvasSize: model.canvasSize, viewSize: size,
                    drawingBounds: model.drawingBounds)
                let s = (t.a * t.a + t.b * t.b).squareRoot()
                drawBackground(&ctx, size: size)
                drawElements(&ctx, transform: t, scale: s)
                drawTortoise(&ctx, transform: t, scale: s)
            }
            .onChange(of: timeline.date) { _, date in
                model.tick(date: date)
            }
        }
        .task(id: tortoise.commands.count) {
            // Guard: init already created a model with the current commands;
            // only recreate when new commands have been appended after appear.
            guard tortoise.commands.count != model.frames.count else { return }
            model = CanvasModel(commands: tortoise.commands, canvasSize: tortoise.canvasSize)
        }
    }

    // MARK: - Drawing

    private func drawBackground(_ ctx: inout GraphicsContext, size: CGSize) {
        guard model.backgroundColor.alpha > 0 else { return }
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(SwiftUI.Color(model.backgroundColor)))
    }

    private func drawElements(
        _ ctx: inout GraphicsContext, transform t: CGAffineTransform, scale s: Double
    ) {
        for element in model.elements {
            switch element {
            case .fill(let fill):
                guard fill.points.count >= 3, let first = fill.points.first else { continue }
                var path = Path()
                path.move(to: CGPoint(x: first.x, y: first.y).applying(t))
                for pt in fill.points.dropFirst() {
                    path.addLine(to: CGPoint(x: pt.x, y: pt.y).applying(t))
                }
                path.closeSubpath()
                ctx.fill(path, with: .color(SwiftUI.Color(fill.color)))

            case .stroke(let stroke):
                var path = Path()
                path.move(to: CGPoint(x: stroke.from.x, y: stroke.from.y).applying(t))
                path.addLine(to: CGPoint(x: stroke.to.x, y: stroke.to.y).applying(t))
                ctx.stroke(
                    path, with: .color(SwiftUI.Color(stroke.color)), lineWidth: stroke.width * s)

            case .arcStroke(let arc):
                ctx.stroke(
                    arcPath(arc, sweep: arc.sweep, transform: t),
                    with: .color(SwiftUI.Color(arc.color)), lineWidth: arc.width * s)

            case .dot(let dot):
                let center = CGPoint(x: dot.center.x, y: dot.center.y).applying(t)
                let r = dot.size / 2 * s
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(SwiftUI.Color(dot.color)))
            }
        }

        if let next = model.inProgressFrame, model.animationProgress > 0 {
            let p = model.animationProgress
            if let stroke = next.newStroke {
                var path = Path()
                let from = CGPoint(x: stroke.from.x, y: stroke.from.y).applying(t)
                let partialTo = CGPoint(
                    x: stroke.from.x + p * (stroke.to.x - stroke.from.x),
                    y: stroke.from.y + p * (stroke.to.y - stroke.from.y)
                ).applying(t)
                path.move(to: from)
                path.addLine(to: partialTo)
                ctx.stroke(
                    path, with: .color(SwiftUI.Color(stroke.color)), lineWidth: stroke.width * s)
            }
            if let arc = next.newArcStroke {
                ctx.stroke(
                    arcPath(arc, sweep: arc.sweep * p, transform: t),
                    with: .color(SwiftUI.Color(arc.color)), lineWidth: arc.width * s)
            }
        }
    }

    /// Builds a polyline approximating an arc (1 segment per 3°).
    private func arcPath(_ arc: ArcStroke, sweep: Double, transform t: CGAffineTransform) -> Path {
        guard abs(sweep) > 0 else { return Path() }
        let steps = max(1, Int(abs(sweep) / 3.0))
        let stepAngle = sweep / Double(steps)
        var path = Path()
        for i in 0...steps {
            let angleRad = (arc.startAngle + Double(i) * stepAngle) * (.pi / 180)
            let pt = CGPoint(
                x: arc.center.x + arc.radius * cos(angleRad),
                y: arc.center.y + arc.radius * sin(angleRad)
            ).applying(t)
            if i == 0 {
                path.move(to: pt)
            }
            else {
                path.addLine(to: pt)
            }
        }
        return path
    }

    private func drawTortoise(
        _ ctx: inout GraphicsContext, transform t: CGAffineTransform, scale rawScale: Double
    ) {
        guard model.tortoiseState.isVisible else { return }

        let pos: Point
        let heading: Double
        if let next = model.inProgressFrame, model.animationProgress > 0 {
            let p = model.animationProgress
            let from = model.tortoiseState
            let to = next.tortoiseState
            pos = Point(
                x: from.position.x + p * (to.position.x - from.position.x),
                y: from.position.y + p * (to.position.y - from.position.y)
            )
            // Normalize heading delta to [-180, 180] so rotation takes the short arc.
            var delta = to.heading - from.heading
            while delta > 180 { delta -= 360 }
            while delta < -180 { delta += 360 }
            heading = from.heading + p * delta
        }
        else {
            pos = model.tortoiseState.position
            heading = model.tortoiseState.heading
        }

        let s = min(max(rawScale, tortoiseScaleMin), tortoiseScaleMax)
        let tortoiseSize = tortoiseBaseSize * s

        // Triangle pointing north (tip at -Y in screen space = up on screen).
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -tortoiseSize))
        path.addLine(to: CGPoint(x: -tortoiseSize * 0.6, y: tortoiseSize * 0.5))
        path.addLine(to: CGPoint(x: tortoiseSize * 0.6, y: tortoiseSize * 0.5))
        path.closeSubpath()

        let position = CGPoint(x: pos.x, y: pos.y).applying(t)
        var tortoiseCtx = ctx
        tortoiseCtx.translateBy(x: position.x, y: position.y)
        // heading 0 = north (tip already points up), heading 90 = east (CW 90°).
        // SwiftUI rotate(by:) is CW-positive in Y-down space, matching tortoise heading.
        tortoiseCtx.rotate(by: .degrees(heading))
        tortoiseCtx.fill(path, with: .color(.green.opacity(0.7)))
        tortoiseCtx.stroke(path, with: .color(.green), lineWidth: 1.5)
    }
}

// MARK: - Viewport modifier

extension EnvironmentValues {
    @Entry var tortoiseViewport: ViewportMode = .scaleToFit
}

extension View {
    /// Sets the viewport mode for any ``TortoiseCanvasView`` in the view hierarchy.
    public func tortoiseViewport(_ mode: ViewportMode) -> some View {
        environment(\.tortoiseViewport, mode)
    }
}

// MARK: - Preview

#Preview("Tortoise Star") {
    TortoiseCanvasView { t in
        t.speed = 0
        t.backward(100)
        for _ in 1...36 {
            t.forward(200)
            t.right(170)
        }
    }
    .tortoiseViewport(.autoFit)
    .padding()
    .frame(width: 400, height: 400)
}
