import Foundation
import Testing

@testable import TortoiseCore

/// Signed area; positive means counter-clockwise in a y-up space.
private func signedArea(_ polygon: [Point]) -> Double {
    guard polygon.count >= 3 else { return 0 }
    var total = 0.0
    for i in polygon.indices {
        let a = polygon[i]
        let b = polygon[(i + 1) % polygon.count]
        total += a.x * b.y - b.x * a.y
    }
    return total / 2
}

/// Distance from `p` to the segment `a`–`b`.
private func distance(_ p: Point, toSegment a: Point, _ b: Point) -> Double {
    let ab = b - a
    let lengthSquared = ab.x * ab.x + ab.y * ab.y
    guard lengthSquared > 0 else { return p.distance(to: a) }
    var t = ((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / lengthSquared
    t = min(max(t, 0), 1)
    return p.distance(to: Point(x: a.x + t * ab.x, y: a.y + t * ab.y))
}

@Suite("Stroke outline geometry")
struct StrokeOutlineTests {
    private let tolerance = StrokeOutline.defaultTolerance

    // MARK: Straight strokes

    @Test("an untapered stroke outlines to a stadium of the right width")
    func untaperedIsStadium() {
        let stroke = Stroke(
            from: Point(x: -50, y: 0), to: Point(x: 50, y: 0), color: .black, width: 8)
        let polygon = StrokeOutline.polygon(for: stroke)

        // Every vertex sits on the boundary: exactly half a pen width from the
        // spine, within flattening tolerance.
        for p in polygon {
            let d = distance(p, toSegment: stroke.from, stroke.to)
            #expect(abs(d - 4) <= tolerance)
        }
        // And the extremes are the caps, half a width beyond each end.
        #expect(abs(polygon.map(\.x).min()! - -54) <= tolerance)
        #expect(abs(polygon.map(\.x).max()! - 54) <= tolerance)
    }

    @Test("a tapered stroke is half its start width at one end and its end width at the other")
    func taperedWidthsAtEnds() {
        let from = Point(x: 0, y: 0)
        let to = Point(x: 100, y: 0)
        let stroke = Stroke(from: from, to: to, color: .black, width: 2, endWidth: 20)
        let polygon = StrokeOutline.polygon(for: stroke)

        // Widest extent across the spine, near each endpoint.
        let nearStart = polygon.filter { $0.x < 1 }.map { abs($0.y) }.max() ?? 0
        let nearEnd = polygon.filter { $0.x > 99 }.map { abs($0.y) }.max() ?? 0
        #expect(abs(nearStart - 1) <= tolerance)
        #expect(abs(nearEnd - 10) <= tolerance)
    }

    /// The tangent construction is what distinguishes this from offsetting the
    /// endpoints perpendicular to the spine; on a taper the sides must lean.
    @Test("the sides of a taper are the discs' external tangents")
    func sidesAreExternalTangents() {
        let from = Point(x: 0, y: 0)
        let to = Point(x: 100, y: 0)
        let r0 = 1.0
        let r1 = 10.0
        let polygon = StrokeOutline.polygon(
            for: Stroke(from: from, to: to, color: .black, width: r0 * 2, endWidth: r1 * 2))

        // The four tangent points are exact, so assert them outright. Note the
        // sign of sinA: when the pen widens, the small end's tangent leans
        // *backwards* past `from` — a perpendicular offset would have put it at
        // (0, r0) and left a notch where the side meets the cap.
        let sinA = (r0 - r1) / 100
        let cosA = (1 - sinA * sinA).squareRoot()
        let expected = [
            Point(x: r0 * sinA, y: r0 * cosA),
            Point(x: r0 * sinA, y: -r0 * cosA),
            Point(x: 100 + r1 * sinA, y: r1 * cosA),
            Point(x: 100 + r1 * sinA, y: -r1 * cosA),
        ]
        for point in expected {
            #expect(
                polygon.contains { $0.distance(to: point) <= 1e-9 },
                "missing tangent point \(point)")
        }
        #expect(sinA < 0)

        // No vertex may fall inside either end disc — that is what "hull" means.
        for p in polygon {
            #expect(p.distance(to: from) >= r0 - tolerance)
            #expect(p.distance(to: to) >= r1 - tolerance)
        }
    }

    @Test("a zero-length stroke outlines to a disc")
    func zeroLengthIsDisc() {
        let p = Point(x: 5, y: -3)
        let polygon = StrokeOutline.polygon(
            for: Stroke(from: p, to: p, color: .black, width: 6))
        #expect(!polygon.isEmpty)
        for q in polygon { #expect(abs(q.distance(to: p) - 3) <= tolerance) }
    }

    @Test("when one end disc swallows the other the outline is that disc")
    func containedDiscCollapses() {
        // A 40-wide pen moving 3 units to a 2-wide pen: the start disc contains
        // everything the pen sweeps.
        let from = Point(x: 0, y: 0)
        let polygon = StrokeOutline.polygon(
            for: Stroke(from: from, to: Point(x: 3, y: 0), color: .black, width: 40, endWidth: 2))
        for q in polygon { #expect(abs(q.distance(to: from) - 20) <= tolerance) }
    }

    @Test("a zero-width stroke outlines to nothing")
    func zeroWidthIsEmpty() {
        let polygon = StrokeOutline.polygon(
            for: Stroke(from: .zero, to: Point(x: 10, y: 0), color: .black, width: 0))
        #expect(polygon.isEmpty)
    }

    @Test("outlines are closed, non-degenerate and counter-clockwise")
    func windingAndClosure() {
        let cases = [
            Stroke(from: .zero, to: Point(x: 100, y: 0), color: .black, width: 6),
            Stroke(from: .zero, to: Point(x: 100, y: 0), color: .black, width: 2, endWidth: 16),
            Stroke(from: .zero, to: Point(x: -40, y: 70), color: .black, width: 12, endWidth: 3),
        ]
        for stroke in cases {
            let polygon = StrokeOutline.polygon(for: stroke)
            #expect(polygon.count >= 3)
            // Closed means "not explicitly repeated" — renderers close it.
            #expect(polygon.first != polygon.last)
            #expect(signedArea(polygon) > 0)
        }
    }

    @Test("a taper and its reverse enclose the same area")
    func reversalIsSymmetric() {
        let a = StrokeOutline.polygon(
            for: Stroke(from: .zero, to: Point(x: 80, y: 0), color: .black, width: 3, endWidth: 14))
        let b = StrokeOutline.polygon(
            for: Stroke(from: Point(x: 80, y: 0), to: .zero, color: .black, width: 14, endWidth: 3))
        #expect(abs(signedArea(a) - signedArea(b)) < 0.01)
    }

    // MARK: Arcs

    @Test("an untapered arc outlines to an annulus sector")
    func untaperedArcIsAnnulus() {
        let arc = ArcStroke(
            center: .zero, radius: 50, startAngle: 0, sweep: 90, color: .black, width: 10)
        let polygon = StrokeOutline.polygon(for: arc)

        // Every vertex is either on an edge (45 or 55 from center) or on a cap.
        let capCenters = [Point(x: 50, y: 0), Point(x: 0, y: 50)]
        for p in polygon {
            let radial = p.distance(to: .zero)
            let onEdge = abs(radial - 45) <= tolerance || abs(radial - 55) <= tolerance
            let onCap = capCenters.contains { abs(p.distance(to: $0) - 5) <= tolerance }
            #expect(onEdge || onCap)
        }
    }

    @Test("a tapered arc's edges follow the ramping width")
    func taperedArcEdges() {
        let arc = ArcStroke(
            center: .zero, radius: 60, startAngle: 0, sweep: 180, color: .black, width: 4,
            endWidth: 16)
        let polygon = StrokeOutline.polygon(for: arc)

        // Outer edge never exceeds radius + half the widest width, and the
        // whole shape stays within the widest cap.
        for p in polygon { #expect(p.distance(to: .zero) <= 60 + 8 + tolerance) }
        // At the start the band is 4 wide; at the end, 16.
        let atStart = polygon.filter { abs($0.y) < 0.5 && $0.x > 0 }.map { $0.distance(to: .zero) }
        #expect(abs((atStart.max() ?? 0) - (atStart.min() ?? 0) - 4) <= 2 * tolerance)
    }

    @Test("a wide pen clamps the inner edge at the centre instead of inverting")
    func widePenClampsInnerEdge() {
        let arc = ArcStroke(
            center: .zero, radius: 10, startAngle: 0, sweep: 120, color: .black, width: 60)
        let polygon = StrokeOutline.polygon(for: arc)
        // Nothing crosses to a negative radius, which is what inversion would do.
        for p in polygon { #expect(p.distance(to: .zero) <= 10 + 30 + tolerance) }
        #expect(polygon.contains { $0.distance(to: .zero) <= tolerance })
    }

    @Test("a zero-sweep arc outlines to the cap left behind")
    func zeroSweepArcIsDisc() {
        let arc = ArcStroke(
            center: .zero, radius: 40, startAngle: 0, sweep: 0, color: .black, width: 8)
        let polygon = StrokeOutline.polygon(for: arc)
        for p in polygon { #expect(abs(p.distance(to: Point(x: 40, y: 0)) - 4) <= tolerance) }
    }

    @Test("arc outlines are counter-clockwise for either sweep direction")
    func arcWinding() {
        for sweep in [90.0, -90.0, 270.0, -270.0] {
            let polygon = StrokeOutline.polygon(
                for: ArcStroke(
                    center: .zero, radius: 50, startAngle: 30, sweep: sweep, color: .black,
                    width: 6, endWidth: 12))
            #expect(polygon.count >= 3)
            #expect(signedArea(polygon) > 0, "sweep \(sweep) wound backwards")
        }
    }

    // MARK: Flattening

    @Test("segment count follows the sagitta tolerance")
    func segmentCountFollowsTolerance() {
        let coarse = StrokeOutline.segmentCount(radius: 100, sweep: .pi, tolerance: 1)
        let fine = StrokeOutline.segmentCount(radius: 100, sweep: .pi, tolerance: 0.01)
        #expect(fine > coarse)

        // The realised sagitta must actually respect the tolerance.
        let steps = StrokeOutline.segmentCount(radius: 100, sweep: .pi, tolerance: 0.1)
        let sagitta = 100 * (1 - cos(.pi / Double(steps) / 2))
        #expect(sagitta <= 0.1 + 1e-9)
    }

    @Test("flattening is bounded however absurd the inputs")
    func flatteningIsBounded() {
        #expect(
            StrokeOutline.segmentCount(radius: 1e9, sweep: 2 * .pi, tolerance: 1e-9)
                == StrokeOutline.maxSegments)
        #expect(StrokeOutline.segmentCount(radius: 0, sweep: .pi, tolerance: 0.1) == 1)
        #expect(StrokeOutline.segmentCount(radius: 10, sweep: 0, tolerance: 0.1) == 1)
    }

    @Test("outlines are deterministic")
    func deterministic() {
        let stroke = Stroke(
            from: .zero, to: Point(x: 70, y: 20), color: .black, width: 3, endWidth: 11)
        #expect(StrokeOutline.polygon(for: stroke) == StrokeOutline.polygon(for: stroke))
    }
}
