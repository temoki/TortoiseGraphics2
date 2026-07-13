import Foundation
@_exported import TortoiseCore

/// SVG export for TortoiseGraphics.
///
/// Converts a ``Tortoise`` command stream into a static SVG document.
/// Pure function; no platform-specific dependencies.
///
/// ```swift
/// let 🐢 = Tortoise()
/// 🐢.penColor = .blue
/// for _ in 1...4 {
///     🐢.forward(100)
///     🐢.right(90)
/// }
/// let svg = TortoiseSVG.render(🐢)
/// // or:
/// let svg = 🐢.svg()
/// ```
public enum TortoiseSVG {
    /// Renders a tortoise's drawing as a static SVG string.
    ///
    /// When `fit` is `true` (the default), the SVG `viewBox` is cropped to the
    /// actual drawing bounding box, producing a tight SVG. Set `fit` to `false`
    /// to keep the full logical canvas size as the `viewBox`.
    @MainActor
    public static func render(_ tortoise: Tortoise, fit: Bool = true) -> String {
        let frames = CommandPlayer.play(commands: tortoise.commands)
        let bounds = fit ? DrawingBounds.compute(from: frames) : nil
        return SVGBuilder(frames: frames, canvasSize: tortoise.canvasSize, fittedBounds: bounds)
            .build()
    }

    static func render(commands: [TortoiseCommand], canvasSize: Size) -> String {
        let frames = CommandPlayer.play(commands: commands)
        return SVGBuilder(frames: frames, canvasSize: canvasSize, fittedBounds: nil).build()
    }
}

// MARK: - Tortoise extension

extension Tortoise {
    /// Returns the tortoise's drawing as a static SVG string.
    ///
    /// When `fit` is `true` (the default), the `viewBox` is cropped to the
    /// actual drawing bounding box. Declared as a function rather than a
    /// computed property because SVG generation has non-trivial cost.
    public func svg(fit: Bool = true) -> String {
        TortoiseSVG.render(self, fit: fit)
    }
}

// MARK: - SVGBuilder

private struct SVGBuilder {
    let frames: [PlaybackFrame]
    let canvasSize: Size
    let fittedBounds: DrawingBounds?

    private var w: Double { canvasSize.width }
    private var h: Double { canvasSize.height }

    func build() -> String {
        var elements: [SVGElement] = []
        var bgColor: Color = .clear
        // Strokes/arcs drawn while isFillActive are held here until endFill,
        // then flushed AFTER the fill polygon so the polygon renders below its outline.
        var pendingFillStrokes: [SVGElement] = []

        for frame in frames {
            if frame.didClear {
                elements.removeAll()
                pendingFillStrokes.removeAll()
            }
            bgColor = frame.backgroundColor

            if let f = frame.completedFill {
                elements.append(.fill(f))
                elements.append(contentsOf: pendingFillStrokes)
                pendingFillStrokes.removeAll()
            }
            if let s = frame.newStroke {
                if frame.isFillActive {
                    pendingFillStrokes.append(.stroke(s))
                }
                else {
                    elements.append(.stroke(s))
                }
            }
            if let a = frame.newArcStroke {
                if frame.isFillActive {
                    pendingFillStrokes.append(.arcStroke(a))
                }
                else {
                    elements.append(.arcStroke(a))
                }
            }
            if let d = frame.newDot {
                if frame.isFillActive {
                    pendingFillStrokes.append(.dot(d))
                }
                else {
                    elements.append(.dot(d))
                }
            }
        }
        // Flush any unclosed fill (endFill missing)
        elements.append(contentsOf: pendingFillStrokes)

        var lines: [String] = []
        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)

        if let bb = fittedBounds {
            // viewBox cropped to the actual drawing bounding box in SVG space.
            let vx = n(x(bb.minX))
            let vy = n(y(bb.maxY))
            let vw = n(bb.width)
            let vh = n(bb.height)
            lines.append(
                #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="\#(vx) \#(vy) \#(vw) \#(vh)" width="\#(vw)" height="\#(vh)">"#
            )
            if bgColor.alpha > 0 {
                lines.append(
                    #"  <rect x="\#(vx)" y="\#(vy)" width="\#(vw)" height="\#(vh)" fill="\#(color(bgColor))"/>"#
                )
            }
        }
        else {
            lines.append(
                #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \#(n(w)) \#(n(h))" width="\#(n(w))" height="\#(n(h))">"#
            )
            if bgColor.alpha > 0 {
                lines.append(
                    #"  <rect width="\#(n(w))" height="\#(n(h))" fill="\#(color(bgColor))"/>"#)
            }
        }

        for element in elements {
            switch element {
            case .fill(let fill): lines.append(svgFill(fill))
            case .stroke(let stroke): lines.append(svgStroke(stroke))
            case .arcStroke(let arc): lines.append(svgArc(arc))
            case .dot(let dot): lines.append(svgDot(dot))
            }
        }

        lines.append("</svg>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Element renderers

    private func svgFill(_ fill: Fill) -> String {
        let pts = fill.points
            .map { "\(n(x($0.x))),\(n(y($0.y)))" }
            .joined(separator: " ")
        return #"  <polygon points="\#(pts)" fill="\#(color(fill.color))"/>"#
    }

    private func svgDot(_ dot: Dot) -> String {
        let cx = n(x(dot.center.x))
        let cy = n(y(dot.center.y))
        let r = n(dot.size / 2)
        return #"  <circle cx="\#(cx)" cy="\#(cy)" r="\#(r)" fill="\#(color(dot.color))"/>"#
    }

    private func svgStroke(_ stroke: Stroke) -> String {
        let x1 = n(x(stroke.from.x))
        let y1 = n(y(stroke.from.y))
        let x2 = n(x(stroke.to.x))
        let y2 = n(y(stroke.to.y))
        return
            #"  <line x1="\#(x1)" y1="\#(y1)" x2="\#(x2)" y2="\#(y2)" stroke="\#(color(stroke.color))" stroke-width="\#(n(stroke.width))" stroke-linecap="round"/>"#
    }

    private func svgArc(_ arc: ArcStroke) -> String {
        let absSwep = abs(arc.sweep)
        guard absSwep > 0 else { return "" }

        let cx = x(arc.center.x)
        let cy = y(arc.center.y)
        let r = arc.radius
        let strokeAttrs =
            #"stroke="\#(color(arc.color))" stroke-width="\#(n(arc.width))" fill="none" stroke-linecap="round""#

        let startRad = arc.startAngle * .pi / 180

        if absSwep >= 360 {
            // Full circle: split into two 180° arcs because SVG A can't share start==end
            let sx = cx + r * cos(startRad)
            let sy = cy - r * sin(startRad)
            let mx = cx - r * cos(startRad)
            let my = cy + r * sin(startRad)
            let sf = arc.sweep >= 0 ? 1 : 0
            let d =
                "M \(n(sx)),\(n(sy)) A \(n(r)),\(n(r)) 0 0,\(sf) \(n(mx)),\(n(my)) A \(n(r)),\(n(r)) 0 0,\(sf) \(n(sx)),\(n(sy))"
            return #"  <path d="\#(d)" \#(strokeAttrs)/>"#
        }

        let endRad = (arc.startAngle + arc.sweep) * .pi / 180
        let sx = cx + r * cos(startRad)
        let sy = cy - r * sin(startRad)
        let ex = cx + r * cos(endRad)
        let ey = cy - r * sin(endRad)
        let largeArc = absSwep > 180 ? 1 : 0
        let sf = arc.sweep >= 0 ? 1 : 0
        let d = "M \(n(sx)),\(n(sy)) A \(n(r)),\(n(r)) 0 \(largeArc),\(sf) \(n(ex)),\(n(ey))"
        return #"  <path d="\#(d)" \#(strokeAttrs)/>"#
    }

    // MARK: - Coordinate transform (tortoise → SVG)
    // Tortoise: center origin, Y-up. SVG: top-left origin, Y-down.

    private func x(_ tortoise: Double) -> Double { w / 2 + tortoise }
    private func y(_ tortoise: Double) -> Double { h / 2 - tortoise }

    // MARK: - Formatting helpers

    private func color(_ c: Color) -> String {
        let r = Int((c.red * 255).rounded())
        let g = Int((c.green * 255).rounded())
        let b = Int((c.blue * 255).rounded())
        if c.alpha >= 1 {
            return String(format: "#%02x%02x%02x", r, g, b)
        }
        return "rgba(\(r),\(g),\(b),\(n(c.alpha)))"
    }

    /// Format a Double as a compact string rounded to 2 decimal places.
    private func n(_ v: Double) -> String {
        let rounded = (v * 100).rounded() / 100
        if rounded == 0 { return "0" }
        var s = String(format: "%.2f", rounded)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}

// MARK: - Private types

private enum SVGElement {
    case fill(Fill)
    case stroke(Stroke)
    case arcStroke(ArcStroke)
    case dot(Dot)
}
