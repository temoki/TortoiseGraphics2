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
        // Index loop rather than `for element in elements` so a run of
        // strokes can be consumed in one step (see the `.stroke` case).
        var i = elements.startIndex
        while i < elements.endIndex {
            switch elements[i] {
            case .fill(let fill):
                i += 1
                guard fill.points.count >= 3, let first = fill.points.first else { continue }
                var path = Path()
                path.move(to: CGPoint(x: first.x, y: first.y).applying(t))
                for pt in fill.points.dropFirst() {
                    path.addLine(to: CGPoint(x: pt.x, y: pt.y).applying(t))
                }
                path.closeSubpath()
                ctx.fill(path, with: .color(SwiftUI.Color(fill.color)))

            case .stroke(let first):
                // Merge the maximal run of same-color, same-width strokes into
                // one multi-subpath `Path` and stroke it once. Round caps are
                // applied per subpath, so the drawing is unchanged, but the
                // per-element `Path` allocation + `ctx.stroke` call — the
                // dominant cost at thousands of elements — is paid once per run.
                // Translucent strokes are excluded: overlapping segments must
                // blend once per stroke to match the SVG renderer, which emits
                // one `<line>` per stroke.
                let batchable = first.color.alpha >= 1
                var path = Path()
                var j = i
                while j < elements.endIndex, case .stroke(let next) = elements[j],
                    next.color == first.color, next.width == first.width
                {
                    path.move(to: CGPoint(x: next.from.x, y: next.from.y).applying(t))
                    path.addLine(to: CGPoint(x: next.to.x, y: next.to.y).applying(t))
                    j += 1
                    if !batchable { break }
                }
                ctx.stroke(
                    path, with: .color(SwiftUI.Color(first.color)),
                    style: strokeStyle(width: first.width * s))
                i = j

            case .arcStroke(let arc):
                i += 1
                ctx.stroke(
                    arcPath(arc, sweep: arc.sweep, transform: t),
                    with: .color(SwiftUI.Color(arc.color)),
                    style: strokeStyle(width: arc.width * s))

            case .dot(let dot):
                i += 1
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
        sprite: TortoiseSprite,
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

        let position = CGPoint(x: pos.x, y: pos.y).applying(t)
        var tortoiseCtx = ctx
        tortoiseCtx.translateBy(x: position.x, y: position.y)
        // heading 0 = north (the sprite is authored pointing up), heading 90 =
        // east (CW 90°). SwiftUI rotate(by:) is CW-positive in Y-down space,
        // matching tortoise heading.
        tortoiseCtx.rotate(by: .degrees(heading))
        switch sprite {
        case .triangle:
            drawTriangleSprite(&tortoiseCtx, size: tortoiseBaseSize * s)
        case .image(let image, let size):
            drawImageSprite(&tortoiseCtx, image: image, size: size, scale: s)
        }
    }

    // MARK: - Private helpers

    /// Draws the built-in triangle, centered on the (already translated and
    /// rotated) context's origin and pointing north — tip at -Y in screen
    /// space, which is up on screen.
    private static func drawTriangleSprite(_ ctx: inout GraphicsContext, size: Double) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -size))
        path.addLine(to: CGPoint(x: -size * 0.6, y: size * 0.5))
        path.addLine(to: CGPoint(x: size * 0.6, y: size * 0.5))
        path.closeSubpath()
        ctx.fill(path, with: .color(.green.opacity(0.7)))
        ctx.stroke(path, with: .color(.green), lineWidth: 1.5)
    }

    /// Draws a custom sprite image centered on the (already translated and
    /// rotated) context's origin, scaled to fit inside `size` × `scale`
    /// without distorting its aspect ratio.
    private static func drawImageSprite(
        _ ctx: inout GraphicsContext, image: Image, size: CGSize, scale s: Double
    ) {
        let box = CGSize(width: size.width * s, height: size.height * s)
        guard box.width > 0, box.height > 0 else { return }
        // Resolving is what exposes the image's intrinsic size, which the
        // aspect fit needs. A `ResolvedImage` belongs to the context that
        // produced it, so this cannot be hoisted out of the per-frame draw.
        let resolved = ctx.resolve(image)
        let intrinsic = resolved.size
        guard intrinsic.width > 0, intrinsic.height > 0 else { return }
        let fit = min(box.width / intrinsic.width, box.height / intrinsic.height)
        let width = intrinsic.width * fit
        let height = intrinsic.height * fit
        ctx.draw(
            resolved,
            in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
    }

    /// Strokes are recorded one per command, so consecutive segments are
    /// separate subpaths. Round caps overlap at the shared endpoint, making
    /// joints look connected — matching the SVG renderer's
    /// `stroke-linecap="round"`. Caps are applied per subpath, so this holds
    /// whether segments are stroked individually or batched into one `Path`.
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
