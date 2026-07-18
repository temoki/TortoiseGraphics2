import SwiftUI
import TortoiseCore

/// Pure drawing routines shared by ``TortoiseCanvas``'s two layers
/// (committed elements below, in-progress stroke + tortoise sprite above).
enum CanvasRenderer {

    static func drawBackground(
        _ ctx: inout GraphicsContext, size: CGSize, color: TortoiseCore.Color
    ) {
        guard color.alpha > 0 else { return }
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(SwiftUI.Color(color)))
    }

    static func drawElements(
        _ ctx: inout GraphicsContext, elements: [DrawElement],
        transform t: CGAffineTransform, scale s: Double
    ) {
        for element in elements {
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
                    path, with: .color(SwiftUI.Color(stroke.color)),
                    style: strokeStyle(width: stroke.width * s))

            case .arcStroke(let arc):
                ctx.stroke(
                    arcPath(arc, sweep: arc.sweep, transform: t),
                    with: .color(SwiftUI.Color(arc.color)),
                    style: strokeStyle(width: arc.width * s))

            case .dot(let dot):
                let center = CGPoint(x: dot.center.x, y: dot.center.y).applying(t)
                let r = dot.size / 2 * s
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(SwiftUI.Color(dot.color)))
            }
        }
    }

    /// Draws the partial stroke/arc of the frame currently being animated,
    /// advanced to `progress` (0 → 1).
    static func drawInProgress(
        _ ctx: inout GraphicsContext, frame: PlaybackFrame, progress p: Double,
        transform t: CGAffineTransform, scale s: Double
    ) {
        if let stroke = frame.newStroke {
            var path = Path()
            let from = CGPoint(x: stroke.from.x, y: stroke.from.y).applying(t)
            let partialTo = CGPoint(
                x: stroke.from.x + p * (stroke.to.x - stroke.from.x),
                y: stroke.from.y + p * (stroke.to.y - stroke.from.y)
            ).applying(t)
            path.move(to: from)
            path.addLine(to: partialTo)
            ctx.stroke(
                path, with: .color(SwiftUI.Color(stroke.color)),
                style: strokeStyle(width: stroke.width * s))
        }
        if let arc = frame.newArcStroke {
            ctx.stroke(
                arcPath(arc, sweep: arc.sweep * p, transform: t),
                with: .color(SwiftUI.Color(arc.color)),
                style: strokeStyle(width: arc.width * s))
        }
    }

    /// Draws the tortoise sprite at `state`, or interpolated toward `next`
    /// when a frame is mid-animation (`progress` > 0).
    static func drawTortoise(
        _ ctx: inout GraphicsContext, state: TortoiseState,
        interpolatingTo next: TortoiseState?, progress: Double,
        transform t: CGAffineTransform, scale rawScale: Double
    ) {
        guard state.isVisible else { return }

        let pos: Point
        let heading: Double
        if let next, progress > 0 {
            pos = Point(
                x: state.position.x + progress * (next.position.x - state.position.x),
                y: state.position.y + progress * (next.position.y - state.position.y)
            )
            // Normalize heading delta to [-180, 180] so rotation takes the short arc.
            var delta = next.heading - state.heading
            while delta > 180 { delta -= 360 }
            while delta < -180 { delta += 360 }
            heading = state.heading + progress * delta
        }
        else {
            pos = state.position
            heading = state.heading
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

    // MARK: - Private helpers

    /// Strokes are drawn one per command, so consecutive segments are
    /// independent paths. Round caps overlap at the shared endpoint, making
    /// joints look connected — matching the SVG renderer's
    /// `stroke-linecap="round"`.
    private static func strokeStyle(width: Double) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    /// Builds a polyline approximating an arc (1 segment per 3°).
    private static func arcPath(
        _ arc: ArcStroke, sweep: Double, transform t: CGAffineTransform
    ) -> Path {
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
}
