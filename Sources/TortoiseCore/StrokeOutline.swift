import Foundation

/// Outline polygons for tapered strokes.
///
/// A stroke whose pen width changes along its length cannot be drawn by
/// stroking a path at one width, so renderers fill the region the pen sweeps
/// instead. That region is computed here — once, in `TortoiseCore` — so the
/// SVG and canvas renderers cannot disagree about the shape of a taper.
///
/// Polygons come back closed (the first point is not repeated at the end) and
/// wound counter-clockwise in tortoise space. An empty array means there is
/// nothing to fill.
public enum StrokeOutline {
    /// Maximum distance a flattened chord may deviate from the true curve.
    ///
    /// A tenth of a logical unit is a twentieth of a pixel at the 2× scale the
    /// canvas goldens render at, so flattening is invisible while keeping the
    /// point counts small enough to stay cheap per frame.
    public static let defaultTolerance = 0.1

    /// Upper bound on the chords used for any single curved run, so a huge
    /// radius or a pathological tolerance cannot produce an unbounded polygon.
    public static let maxSegments = 512

    // MARK: - Straight strokes

    /// The outline of a straight stroke with round caps.
    ///
    /// The exact result is the convex hull of the two end discs: the sides are
    /// the discs' external tangents, which for a taper are *not* parallel to
    /// the stroke and do not meet the caps at the halfway point. Offsetting
    /// each endpoint along the perpendicular instead would leave a visible
    /// notch where side meets cap, which is why this does the tangent
    /// construction rather than the cheaper approximation.
    public static func polygon(
        for stroke: Stroke, tolerance: Double = defaultTolerance
    ) -> [Point] {
        hull(
            from: stroke.from, radius0: max(0, stroke.width) / 2,
            to: stroke.to, radius1: max(0, stroke.endWidth) / 2,
            tolerance: tolerance)
    }

    /// The convex hull of two discs, as a closed polygon.
    static func hull(
        from p0: Point, radius0 r0: Double, to p1: Point, radius1 r1: Double, tolerance: Double
    ) -> [Point] {
        guard r0 > 0 || r1 > 0 else { return [] }

        let delta = p1 - p0
        let d = delta.magnitude

        // No length: the pen never moved, so the mark is a single disc.
        guard d > .ulpOfOne else {
            return circle(center: p0, radius: max(r0, r1), tolerance: tolerance)
        }

        // One disc swallows the other; there are no external tangents to draw.
        let sinA = (r0 - r1) / d
        guard abs(sinA) < 1 else {
            return r0 > r1
                ? circle(center: p0, radius: r0, tolerance: tolerance)
                : circle(center: p1, radius: r1, tolerance: tolerance)
        }
        let cosA = (1 - sinA * sinA).squareRoot()

        // Tangent directions, as the axis angle rotated by ±(90° - A). Both
        // tangent points on a given side share this direction, which is what
        // makes the sides touch each disc exactly.
        let axis = atan2(delta.y, delta.x)
        let halfOpen = atan2(cosA, sinA)  // = 90° - A, in radians
        let anglePlus = axis + halfOpen
        let angleMinus = axis - halfOpen

        var points: [Point] = []
        // Side one, then the far cap wrapping forward past `p1` …
        points.append(pointOn(center: p0, radius: r0, angle: angleMinus))
        points += arcPoints(
            center: p1, radius: r1, from: angleMinus, sweep: 2 * halfOpen,
            tolerance: tolerance, includingLast: true)
        // … then side two, and the near cap wrapping back past `p0`.
        points += arcPoints(
            center: p0, radius: r0, from: anglePlus, sweep: 2 * (.pi - halfOpen),
            tolerance: tolerance, includingLast: false)
        return points
    }

    // MARK: - Arcs

    /// The outline of a circular arc stroke with round caps.
    ///
    /// The pen sweeps an annulus whose inner and outer edges are at
    /// `radius ∓ penWidth(t)/2`. With a varying width those edges are spirals
    /// rather than circles, so they are flattened to chords; the true envelope
    /// additionally leans by `d(width)/d(angle)`, which is below `tolerance`
    /// for any width ramp a pen plausibly makes over an arc.
    ///
    /// A pen wider than twice the arc radius would invert the inner edge
    /// through the center; it is clamped at the center instead, so the shape
    /// degenerates to a filled disc sector rather than turning inside out.
    public static func polygon(
        for arc: ArcStroke, tolerance: Double = defaultTolerance
    ) -> [Point] {
        let r0 = max(0, arc.width) / 2
        let r1 = max(0, arc.endWidth) / 2
        guard r0 > 0 || r1 > 0 else { return [] }

        let sweep = arc.sweep * .pi / 180
        guard abs(sweep) > .ulpOfOne else {
            // No sweep: the pen sat still, leaving its cap behind.
            return circle(
                center: pointOn(
                    center: arc.center, radius: arc.radius,
                    angle: arc.startAngle * .pi / 180),
                radius: r0, tolerance: tolerance)
        }

        let start = arc.startAngle * .pi / 180
        let end = start + sweep
        let steps = segmentCount(
            radius: arc.radius + max(r0, r1), sweep: sweep, tolerance: tolerance)

        func width(at t: Double) -> Double { r0 + (r1 - r0) * t }
        func angle(at t: Double) -> Double { start + sweep * t }

        var points: [Point] = []
        // Outer edge, start → end.
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            points.append(
                pointOn(center: arc.center, radius: arc.radius + width(at: t), angle: angle(at: t)))
        }
        // Cap at the far end, bulging along the direction of travel.
        let capSweep: Double = sweep > 0 ? .pi : -.pi
        points += arcPoints(
            center: pointOn(center: arc.center, radius: arc.radius, angle: end),
            radius: r1, from: end, sweep: capSweep, tolerance: tolerance, includingLast: false)
        // Inner edge, end → start.
        for i in 0...steps {
            let t = 1 - Double(i) / Double(steps)
            let inner = max(0, arc.radius - width(at: t))
            points.append(pointOn(center: arc.center, radius: inner, angle: angle(at: t)))
        }
        // Cap at the near end, bulging against the direction of travel.
        points += arcPoints(
            center: pointOn(center: arc.center, radius: arc.radius, angle: start),
            radius: r0, from: start + .pi, sweep: capSweep, tolerance: tolerance,
            includingLast: false)
        // A clockwise arc is traced outer-edge-backwards, which winds the
        // polygon the other way; flip it so callers get one convention.
        return sweep > 0 ? points : points.reversed()
    }

    // MARK: - Primitives

    static func circle(center: Point, radius: Double, tolerance: Double) -> [Point] {
        guard radius > 0 else { return [] }
        return arcPoints(
            center: center, radius: radius, from: 0, sweep: 2 * .pi, tolerance: tolerance,
            includingLast: false)
    }

    /// Flattens a circular arc to chords. `includingLast` controls whether the
    /// final point is emitted, so runs can be concatenated without duplicates.
    static func arcPoints(
        center: Point, radius: Double, from startAngle: Double, sweep: Double,
        tolerance: Double, includingLast: Bool
    ) -> [Point] {
        guard radius > 0 else { return includingLast ? [center] : [] }
        let steps = segmentCount(radius: radius, sweep: sweep, tolerance: tolerance)
        let upper = includingLast ? steps : steps - 1
        guard upper >= 0 else { return [] }
        return (0...upper).map { i in
            pointOn(
                center: center, radius: radius,
                angle: startAngle + sweep * (Double(i) / Double(steps)))
        }
    }

    /// Chord count for a given sagitta tolerance: the error of a chord
    /// subtending `Δ` on radius `r` is `r(1 - cos(Δ/2))`.
    static func segmentCount(radius: Double, sweep: Double, tolerance: Double) -> Int {
        let absSweep = abs(sweep)
        guard absSweep > .ulpOfOne else { return 1 }
        let tol = max(tolerance, 1e-6)
        guard radius > tol else { return 1 }
        let maxStep = 2 * acos((1 - tol / radius).clamped(to: -1...1))
        guard maxStep > .ulpOfOne else { return maxSegments }
        return min(maxSegments, max(1, Int((absSweep / maxStep).rounded(.up))))
    }

    static func pointOn(center: Point, radius: Double, angle: Double) -> Point {
        Point(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
