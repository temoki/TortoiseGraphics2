import SwiftUI
import TortoiseCore

/// A SwiftUI view that renders and animates turtle-graphics commands.
///
/// Pass a ``Tortoise`` instance and the view plays back its command stream
/// using `TimelineView` and `Canvas`. The animation respects each command's
/// speed; `speed(0)` renders all drawing instantly.
///
/// ```swift
/// let 🐢 = Tortoise()
/// 🐢.penColor = .red
/// for _ in 1...4 {
///     🐢.forward(100)
///     🐢.right(90)
/// }
/// TortoiseCanvasView(🐢)
/// ```
public struct TortoiseCanvasView: View {
    private let tortoise: Tortoise
    private let viewportMode: ViewportMode

    @State private var model = CanvasModel(commands: [], canvasSize: .defaultCanvas)

    public init(_ tortoise: Tortoise, viewport viewportMode: ViewportMode = .scaleToFit) {
        self.tortoise = tortoise
        self.viewportMode = viewportMode
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                drawBackground(&ctx, size: size)
                drawFills(&ctx, size: size)
                drawStrokes(&ctx, size: size)
                drawTurtle(&ctx, size: size)
            }
            .onChange(of: timeline.date) { _, date in
                model.tick(date: date)
            }
        }
        .task(id: tortoise.commands.count) {
            model = CanvasModel(commands: tortoise.commands, canvasSize: tortoise.canvasSize)
        }
    }

    // MARK: - Drawing

    private func viewTransform(size: CGSize) -> CGAffineTransform {
        viewportMode.transform(canvasSize: model.canvasSize, viewSize: size)
    }

    /// Converts a turtle-space point to SwiftUI Canvas coordinates.
    private func toScreen(_ v: Vec2D, size: CGSize) -> CGPoint {
        CGPoint(x: v.x, y: v.y).applying(viewTransform(size: size))
    }

    /// Uniform scale factor from the viewport transform (turtle units → points).
    private func scale(size: CGSize) -> Double {
        let t = viewTransform(size: size)
        return (t.a * t.a + t.b * t.b).squareRoot()
    }

    private func drawBackground(_ ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .color(SwiftUI.Color(model.backgroundColor)))
    }

    private func drawFills(_ ctx: inout GraphicsContext, size: CGSize) {
        for fill in model.fills {
            guard fill.points.count >= 3, let first = fill.points.first else { continue }
            var path = Path()
            path.move(to: toScreen(first, size: size))
            for pt in fill.points.dropFirst() {
                path.addLine(to: toScreen(pt, size: size))
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(SwiftUI.Color(fill.color)))
        }
    }

    private func drawStrokes(_ ctx: inout GraphicsContext, size: CGSize) {
        for stroke in model.strokes {
            var path = Path()
            path.move(to: toScreen(stroke.from, size: size))
            path.addLine(to: toScreen(stroke.to, size: size))
            ctx.stroke(path, with: .color(SwiftUI.Color(stroke.color)), lineWidth: stroke.width)
        }

        let s = scale(size: size)
        for arc in model.arcStrokes {
            // Approximate the arc with line segments (1 segment per 3°).
            // Points are computed in turtle space then projected via viewTransform,
            // so the Y-flip is handled automatically.
            let steps = max(12, Int(abs(arc.sweep) / 3.0))
            let stepAngle = arc.sweep / Double(steps)
            var path = Path()
            for i in 0...steps {
                let angleDeg = arc.startAngle + Double(i) * stepAngle
                let angleRad = angleDeg * (.pi / 180)
                // turtle space: east = 0°, north = 90°, CCW positive
                let pt = Vec2D(
                    x: arc.center.x + arc.radius * cos(angleRad),
                    y: arc.center.y + arc.radius * sin(angleRad)
                )
                let screenPt = toScreen(pt, size: size)
                if i == 0 { path.move(to: screenPt) } else { path.addLine(to: screenPt) }
            }
            ctx.stroke(path, with: .color(SwiftUI.Color(arc.color)),
                       lineWidth: arc.width * s)
        }
    }

    private func drawTurtle(_ ctx: inout GraphicsContext, size: CGSize) {
        guard model.turtleState.isVisible, model.currentFrameIndex >= 0 else { return }

        let s = min(max(scale(size: size), 0.5), 2.0)
        let turtleSize = 10.0 * s

        // Triangle pointing north (tip at -Y in screen space = up on screen)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -turtleSize))
        path.addLine(to: CGPoint(x: -turtleSize * 0.6, y: turtleSize * 0.5))
        path.addLine(to: CGPoint(x: turtleSize * 0.6, y: turtleSize * 0.5))
        path.closeSubpath()

        let position = toScreen(model.turtleState.position, size: size)
        var turtleCtx = ctx
        // Translate to turtle's screen position, then rotate by heading.
        // heading 0 = north (tip already points up), heading 90 = east (CW 90°).
        // SwiftUI rotate(by:) is CW-positive in Y-down space, matching turtle heading.
        turtleCtx.translateBy(x: position.x, y: position.y)
        turtleCtx.rotate(by: .degrees(model.turtleState.heading))
        turtleCtx.fill(path, with: .color(.green.opacity(0.7)))
        turtleCtx.stroke(path, with: .color(.green), lineWidth: 1.5)
    }
}

// MARK: - Preview

#Preview("Turtle Star") {
    @MainActor
    func turtleStar() -> TortoiseCanvasView {
        let 🐢 = Tortoise()
        🐢.speed = 0  // draw instantly
        for _ in 1...36 {
            🐢.forward(200)
            🐢.right(170)
        }
        return TortoiseCanvasView(🐢)
    }
    return turtleStar()
        .frame(width: 400, height: 400)
}
