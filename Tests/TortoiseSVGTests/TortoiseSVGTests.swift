import Testing
import TortoiseCore

@testable import TortoiseSVG

// MARK: - Helpers

private let canvas400 = Size(width: 400, height: 400)

/// Returns the rendered SVG for the given command array on a 400×400 canvas.
private func svg(_ commands: TortoiseCommand...) -> String {
    TortoiseSVG.render(commands: commands, canvasSize: canvas400)
}

// MARK: - Tests

@Suite("TortoiseSVG")
struct TortoiseSVGTests {

    // MARK: SVG structure

    @Test("SVG document starts with XML declaration")
    func xmlDeclaration() {
        let out = svg()
        #expect(out.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
    }

    @Test("SVG element reflects canvas size in viewBox and dimensions")
    func svgDimensions() {
        let out = TortoiseSVG.render(commands: [], canvasSize: Size(width: 300, height: 200))
        #expect(out.contains("viewBox=\"0 0 300 200\""))
        #expect(out.contains("width=\"300\""))
        #expect(out.contains("height=\"200\""))
    }

    // MARK: Background

    @Test("default background is white, matching a fresh Tortoise (#44)")
    func defaultBackground() {
        let out = svg()
        #expect(out.contains("<rect"))
        #expect(out.contains("fill=\"#ffffff\""))
    }

    @Test("an explicitly transparent background emits no rect element")
    func clearBackground() {
        let out = svg(.backgroundColor(.clear))
        #expect(!out.contains("<rect"))
    }

    @Test("backgroundColor command changes the background rect fill")
    func customBackground() {
        let out = svg(.backgroundColor(.red))
        #expect(out.contains("fill=\"#ff0000\""))
    }

    @Test("last backgroundColor wins when set multiple times")
    func lastBackgroundWins() {
        let out = svg(.backgroundColor(.red), .backgroundColor(.blue))
        #expect(out.contains("fill=\"#0000ff\""))
        #expect(!out.contains("fill=\"#ff0000\""))
    }

    // MARK: Line strokes

    @Test("forward with pen down produces a line element")
    func lineStroke() {
        // Default: pen is down, start (0,0) heading north → end (0,100)
        // SVG 400×400: start (200,200), end (200,100)
        let out = svg(.forward(100))
        #expect(out.contains("<line"))
        #expect(out.contains("x1=\"200\""))
        #expect(out.contains("y1=\"200\""))
        #expect(out.contains("x2=\"200\""))
        #expect(out.contains("y2=\"100\""))
    }

    @Test("penUp suppresses line output")
    func penUpSuppressesLine() {
        let out = svg(.penUp, .forward(100))
        #expect(!out.contains("<line"))
    }

    @Test("line element carries pen color")
    func lineColor() {
        let out = svg(.penColor(.blue), .forward(100))
        #expect(out.contains("stroke=\"#0000ff\""))
    }

    @Test("line element carries pen width")
    func lineWidth() {
        let out = svg(.penWidth(3), .forward(100))
        #expect(out.contains("stroke-width=\"3\""))
    }

    @Test("line element uses round linecap")
    func lineLinecap() {
        let out = svg(.forward(100))
        #expect(out.contains("stroke-linecap=\"round\""))
    }

    // MARK: Arc strokes

    @Test("arc with pen down produces an SVG path with A command")
    func arcPath() {
        let out = svg(.arc(radius: 50, extent: 90))
        #expect(out.contains("<path"))
        #expect(out.contains(" A "))
    }

    @Test("full-circle arc (extent=360) uses two A commands to avoid degenerate arc")
    func fullCircleArc() {
        let out = svg(.arc(radius: 50, extent: 360))
        let count = out.components(separatedBy: " A ").count - 1
        #expect(count == 2)
    }

    @Test("arc with large extent uses large-arc-flag=1")
    func largeArcFlag() {
        // extent=270° > 180° → large-arc-flag should be 1
        let out = svg(.arc(radius: 50, extent: 270))
        #expect(out.contains("0 1,"))
    }

    @Test("arc with small extent uses large-arc-flag=0")
    func smallArcFlag() {
        // extent=90° < 180° → large-arc-flag should be 0
        let out = svg(.arc(radius: 50, extent: 90))
        #expect(out.contains("0 0,"))
    }

    @Test("arc path carries pen color and width")
    func arcStyle() {
        let out = svg(.penColor(.red), .penWidth(2), .arc(radius: 50, extent: 90))
        #expect(out.contains("stroke=\"#ff0000\""))
        #expect(out.contains("stroke-width=\"2\""))
    }

    // MARK: Fills

    @Test("beginFill / endFill with polygon produces polygon element")
    func fillPolygon() {
        // Equilateral triangle
        let commands: [TortoiseCommand] = [
            .beginFill,
            .forward(100), .rotate(120),
            .forward(100), .rotate(120),
            .forward(100),
            .endFill,
        ]
        let out = TortoiseSVG.render(commands: commands, canvasSize: canvas400)
        #expect(out.contains("<polygon"))
        #expect(out.contains("points="))
    }

    @Test("fill polygon carries fill color")
    func fillColor() {
        let commands: [TortoiseCommand] = [
            .fillColor(.blue),
            .beginFill,
            .forward(100), .rotate(90),
            .forward(100), .rotate(90),
            .forward(100), .rotate(90),
            .forward(100),
            .endFill,
        ]
        let out = TortoiseSVG.render(commands: commands, canvasSize: canvas400)
        #expect(out.contains("fill=\"#0000ff\""))
    }

    // MARK: Drawing order

    @Test("fill is emitted before subsequent strokes in SVG output")
    func fillBeforeStroke() {
        // Draw a fill polygon, then a line on top
        let commands: [TortoiseCommand] = [
            .beginFill,
            .forward(50), .rotate(90), .forward(50), .rotate(90),
            .forward(50), .rotate(90), .forward(50),
            .endFill,
            .penColor(.red), .forward(100),
        ]
        let out = TortoiseSVG.render(commands: commands, canvasSize: canvas400)
        let polygonIdx = out.range(of: "<polygon")?.lowerBound
        let lineIdx = out.range(of: "<line")?.lowerBound
        #expect(polygonIdx != nil)
        #expect(lineIdx != nil)
        if let p = polygonIdx, let l = lineIdx { #expect(p < l) }
    }

    // MARK: Clear

    @Test("clear removes all prior strokes from the SVG output")
    func clearRemovesStrokes() {
        // Draw a line, then clear — no line should appear in output
        let out = svg(.forward(100), .clear)
        #expect(!out.contains("<line"))
    }

    @Test("strokes after clear appear in the SVG output")
    func strokesAfterClear() {
        // Clear, then draw — the post-clear line should appear
        let out = svg(.forward(100), .clear, .forward(50))
        #expect(out.contains("<line"))
        // Only one line (the post-clear one)
        let lineCount = out.components(separatedBy: "<line").count - 1
        #expect(lineCount == 1)
    }

    // MARK: Semi-transparent colors

    @Test("semi-transparent color uses rgba() format")
    func semiTransparentColor() {
        let halfRed = Color(red: 1, green: 0, blue: 0, alpha: 0.5)
        let out = svg(.penColor(halfRed), .forward(100))
        #expect(out.contains("rgba(255,0,0,0.5)"))
    }
}

// MARK: - Tapered strokes

@Suite("Tapered stroke SVG")
@MainActor
struct TaperedStrokeSVGTests {
    @Test("a tapered stroke becomes a single filled polygon")
    func taperedStrokeIsOnePolygon() {
        let t = Tortoise()
        t.penWidth = 1
        t.forward(150, widthTo: 14)
        let svg = t.svg()

        #expect(svg.components(separatedBy: "<polygon").count - 1 == 1)
        #expect(!svg.contains("<line"))
    }

    @Test("an untapered stroke is still a line")
    func untaperedStrokeIsStillALine() {
        let t = Tortoise()
        t.penWidth = 4
        t.forward(150)
        let svg = t.svg()

        #expect(svg.contains("<line"))
        #expect(!svg.contains("<polygon"))
        #expect(svg.contains("stroke-width=\"4\""))
    }

    @Test("a taper to the same width is still a line")
    func sameWidthTaperIsStillALine() {
        let t = Tortoise()
        t.penWidth = 4
        t.forward(150, widthTo: 4)
        let svg = t.svg()

        #expect(svg.contains("<line"))
        #expect(!svg.contains("<polygon"))
    }

    /// The seam problem the expansion-based taper had: overlapping round caps
    /// blended twice and darkened. One polygon has no interior seams at all.
    @Test("a translucent taper is one polygon, so it cannot seam")
    func translucentTaperHasNoSeams() {
        let t = Tortoise()
        t.penColor = Color(red: 0, green: 0.4, blue: 0.2, alpha: 0.35)
        t.penWidth = 2
        t.forward(200, widthTo: 24)
        let svg = t.svg()

        #expect(svg.components(separatedBy: "<polygon").count - 1 == 1)
        #expect(svg.contains("rgba(0,102,51,0.35)"))
    }

    @Test("a tapered arc becomes a single filled polygon")
    func taperedArcIsOnePolygon() {
        let t = Tortoise()
        t.penWidth = 2
        t.circle(radius: 60, extent: 270, widthTo: 18)
        let svg = t.svg()

        #expect(svg.components(separatedBy: "<polygon").count - 1 == 1)
        #expect(!svg.contains("<path"))
    }

    @Test("an untapered arc is still a stroked path")
    func untaperedArcIsStillAPath() {
        let t = Tortoise()
        t.penWidth = 2
        t.circle(radius: 60, extent: 270)
        let svg = t.svg()

        #expect(svg.contains("<path"))
        #expect(!svg.contains("<polygon"))
    }

    /// A zero-extent arc has always drawn nothing; tapering must not change that.
    @Test("a zero-extent tapered arc draws nothing")
    func zeroExtentTaperedArcDrawsNothing() {
        let t = Tortoise()
        t.penWidth = 2
        t.circle(radius: 60, extent: 0, widthTo: 18)
        let svg = t.svg()

        #expect(!svg.contains("<polygon"))
        #expect(!svg.contains("<path"))
    }

    @Test("the polygon is filled with the pen colour and has no stroke")
    func polygonUsesPenColour() {
        let t = Tortoise()
        t.penColor = Color(red: 1, green: 0, blue: 0)
        t.penWidth = 1
        t.forward(100, widthTo: 10)
        let svg = t.svg()

        #expect(svg.contains("fill=\"#ff0000\""))
        #expect(!svg.contains("stroke-width"))
    }

    @Test("a taper with the pen up emits nothing")
    func penUpTaperEmitsNothing() {
        let t = Tortoise()
        t.penUp()
        t.forward(100, widthTo: 10)
        #expect(!t.svg().contains("<polygon"))
    }
}
