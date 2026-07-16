import Testing

@testable import TortoiseCore

// MARK: - Helpers

private let epsilon = 1e-10

private func isClose(_ a: Double, _ b: Double) -> Bool {
    abs(a - b) < epsilon
}

private func isClose(_ a: Point, _ b: Point) -> Bool {
    isClose(a.x, b.x) && isClose(a.y, b.y)
}

// MARK: - Tortoise API

@Suite("Tortoise API")
@MainActor
struct TortoiseAPITests {
    @Test("forward appends .forward command")
    func forwardCommand() {
        let t = Tortoise()
        t.forward(100)
        #expect(t.commands == [.forward(100)])
    }

    @Test("backward appends .forward with negated distance")
    func backwardCommand() {
        let t = Tortoise()
        t.backward(50)
        #expect(t.commands == [.forward(-50)])
    }

    @Test("right appends positive .rotate")
    func rightCommand() {
        let t = Tortoise()
        t.right(90)
        #expect(t.commands == [.rotate(90)])
    }

    @Test("left appends negative .rotate")
    func leftCommand() {
        let t = Tortoise()
        t.left(45)
        #expect(t.commands == [.rotate(-45)])
    }

    @Test("penUp / penDown append correct commands")
    func penCommands() {
        let t = Tortoise()
        t.penUp()
        t.penDown()
        #expect(t.commands == [.penUp, .penDown])
    }

    @Test("penColor property getter and setter")
    func penColorProperty() {
        let t = Tortoise()
        t.penColor = .red
        #expect(t.commands == [.penColor(.red)])
        #expect(t.penColor == .red)
    }

    @Test("penWidth property getter and setter")
    func penWidthProperty() {
        let t = Tortoise()
        t.penWidth = 3
        #expect(t.commands == [.penWidth(3)])
        #expect(t.penWidth == 3)
    }

    @Test("fillColor property getter and setter")
    func fillColorProperty() {
        let t = Tortoise()
        t.fillColor = .blue
        #expect(t.commands == [.fillColor(.blue)])
        #expect(t.fillColor == .blue)
    }

    @Test("heading property getter and setter appends .setHeading")
    func headingProperty() {
        let t = Tortoise()
        t.heading = 270
        #expect(t.commands == [.setHeading(270)])
        #expect(t.heading == 270)
    }

    @Test("speed property getter and setter")
    func speedProperty() {
        let t = Tortoise()
        t.speed = 3
        #expect(t.commands == [.speed(3)])
        #expect(t.speed == 3)
    }

    @Test("backgroundColor property getter and setter")
    func backgroundColorProperty() {
        let t = Tortoise()
        t.backgroundColor = .cyan
        #expect(t.commands == [.backgroundColor(.cyan)])
        #expect(t.backgroundColor == .cyan)
    }

    @Test("beginFill / endFill append correct commands")
    func fillCommands() {
        let t = Tortoise()
        t.beginFill()
        t.endFill()
        #expect(t.commands == [.beginFill, .endFill])
    }

    @Test("clear during fill resets isFilling")
    func clearResetsIsFilling() {
        let t = Tortoise()
        t.beginFill()
        #expect(t.isFilling)
        t.clear()
        #expect(!t.isFilling)
    }

    @Test("reset discards commands and restores the initial state")
    func resetRestoresInitialState() {
        let t = Tortoise(canvasSize: Size(width: 300, height: 200))
        t.penColor = .red
        t.penWidth = 4
        t.fillColor = .cyan
        t.speed = 9
        t.backgroundColor = .black
        t.penUp()
        t.hideTortoise()
        t.forward(100)
        t.right(90)
        t.reset()
        #expect(t.commands.isEmpty)
        #expect(t.position == .zero)
        #expect(t.heading == 0)
        #expect(t.isPenDown)
        #expect(t.penColor == .black)
        #expect(t.penWidth == 1)
        #expect(t.fillColor == .black)
        #expect(t.isVisible)
        #expect(t.speed == 5)
        #expect(t.backgroundColor == .white)
        #expect(t.canvasSize == Size(width: 300, height: 200))
    }

    @Test("reset during fill discards the fill like clear")
    func resetDuringFillDiscardsFill() {
        let t = Tortoise()
        t.beginFill()
        t.forward(50)
        t.right(120)
        t.forward(50)
        t.reset()
        #expect(!t.isFilling)
        t.endFill()  // Stray endFill with no beginFill in the stream.
        let frames = CommandPlayer.play(commands: t.commands)
        #expect(frames.allSatisfy { $0.completedFill == nil })
    }

    @Test("mutationCount increases on every record and on reset")
    func mutationCountIsMonotonic() {
        let t = Tortoise()
        #expect(t.mutationCount == 0)
        t.forward(10)
        t.right(90)
        #expect(t.mutationCount == 2)
        t.reset()
        #expect(t.mutationCount == 3)
        // Re-recording a same-length program must not revisit an earlier
        // value: TortoiseCanvas watches this key, so reset + same-count
        // reinjection still triggers a rebuild (commands.count would miss it).
        t.forward(10)
        t.right(90)
        #expect(t.mutationCount == 5)
        #expect(t.commands.count == 2)
    }

    @Test("home appends .home")
    func homeCommand() {
        let t = Tortoise()
        t.home()
        #expect(t.commands == [.home])
    }

    @Test("setPosition(x:y:) appends .setPosition")
    func setPositionCommand() {
        let t = Tortoise()
        t.setPosition(x: 10, y: 20)
        #expect(t.commands == [.setPosition(Point(x: 10, y: 20))])
    }

    @Test("position read-only property reflects movements")
    func positionProperty() {
        let t = Tortoise()
        t.forward(100)
        #expect(isClose(t.position, Point(x: 0, y: 100)))
    }

    @Test("default canvasSize is 400×400")
    func defaultCanvasSize() {
        let t = Tortoise()
        #expect(t.canvasSize == Size(width: 400, height: 400))
    }

    @Test("custom canvasSize is preserved")
    func customCanvasSize() {
        let t = Tortoise(canvasSize: Size(width: 800, height: 600))
        #expect(t.canvasSize == Size(width: 800, height: 600))
    }

    @Test("circle() appends .arc(radius:extent:360)")
    func circleFullCommand() {
        let t = Tortoise()
        t.circle(radius: 100)
        #expect(t.commands == [.arc(radius: 100, extent: 360)])
    }

    @Test("circle(radius:extent:) appends .arc with given extent")
    func circleArcCommand() {
        let t = Tortoise()
        t.circle(radius: 50, extent: 90)
        #expect(t.commands == [.arc(radius: 50, extent: 90)])
    }

    @Test("full circle returns tortoise to start position")
    func fullCircleReturnsHome() {
        let t = Tortoise()
        t.circle(radius: 100)
        #expect(isClose(t.position, Point.zero))
    }

    @Test("quarter circle moves tortoise to correct position")
    func quarterCirclePosition() {
        let t = Tortoise()
        t.circle(radius: 100, extent: 90)
        // Starting at (0,0) heading north: center = (-100, 0)
        // After 90° CCW arc: end = (-100, 100), heading = 270°
        #expect(isClose(t.position, Point(x: -100, y: 100)))
        #expect(isClose(t.heading, 270))
    }

    @Test("negative radius mirrors the arc to the tortoise's right")
    func negativeRadiusQuarterCircle() {
        let t = Tortoise()
        t.circle(radius: -100, extent: 90)
        // Starting at (0,0) heading north: center = (100, 0)
        // After 90° CW arc (Python-turtle style): end = (100, 100), heading = 90°
        #expect(isClose(t.position, Point(x: 100, y: 100)))
        #expect(isClose(t.heading, 90))
    }

    @Test("negative radius full circle returns to start")
    func negativeRadiusFullCircle() {
        let t = Tortoise()
        t.circle(radius: -50)
        #expect(isClose(t.position, Point.zero))
        #expect(isClose(t.heading, 0))
    }

    @Test("negative radius zero-extent arc does not move the tortoise")
    func negativeRadiusZeroExtent() {
        let t = Tortoise()
        t.circle(radius: -50, extent: 0)
        #expect(isClose(t.position, Point.zero))
    }

    @Test("heading is always normalized to [0, 360)")
    func headingNormalized() {
        let t = Tortoise()
        t.left(90)
        #expect(isClose(t.heading, 270))
        t.heading = -450
        #expect(isClose(t.heading, 270))
        #expect(t.commands.last == .setHeading(270))
        t.right(720)
        #expect(isClose(t.heading, 270))
        t.heading = 360
        #expect(isClose(t.heading, 0))
    }
}

// MARK: - CommandPlayer

@Suite("CommandPlayer")
struct CommandPlayerTests {
    @Test("forward 100 from origin moves north by 100")
    func forwardNorth() {
        let frames = CommandPlayer.play(commands: [.forward(100)])
        #expect(frames.count == 1)
        #expect(isClose(frames[0].tortoiseState.position, Point(x: 0, y: 100)))
    }

    @Test("rotate 90 then forward moves east")
    func forwardEastAfterRightTurn() {
        let frames = CommandPlayer.play(commands: [.rotate(90), .forward(100)])
        #expect(isClose(frames.last!.tortoiseState.position, Point(x: 100, y: 0)))
    }

    @Test("rotate -90 then forward moves west")
    func forwardWestAfterLeftTurn() {
        let frames = CommandPlayer.play(commands: [.rotate(-90), .forward(100)])
        #expect(isClose(frames.last!.tortoiseState.position, Point(x: -100, y: 0)))
    }

    @Test("rotate 180 then forward moves south")
    func forwardSouth() {
        let frames = CommandPlayer.play(commands: [.rotate(180), .forward(100)])
        #expect(isClose(frames.last!.tortoiseState.position, Point(x: 0, y: -100)))
    }

    @Test("penDown forward produces a stroke")
    func strokeWhenPenDown() {
        let frames = CommandPlayer.play(commands: [.forward(50)])
        #expect(frames[0].newStroke != nil)
        #expect(frames[0].newStroke?.from == Point.zero)
        #expect(isClose(frames[0].newStroke!.to, Point(x: 0, y: 50)))
    }

    @Test("penUp forward produces no stroke")
    func noStrokeWhenPenUp() {
        let frames = CommandPlayer.play(commands: [.penUp, .forward(50)])
        #expect(frames[0].newStroke == nil)
        #expect(frames[1].newStroke == nil)
    }

    @Test("stroke inherits pen color and width")
    func strokeStyle() {
        let frames = CommandPlayer.play(commands: [
            .penColor(.red),
            .penWidth(3),
            .forward(100),
        ])
        let stroke = frames.last!.newStroke
        #expect(stroke?.color == .red)
        #expect(stroke?.width == 3)
    }

    @Test("home moves to origin and resets heading")
    func homeResetsPositionAndHeading() {
        let frames = CommandPlayer.play(commands: [.forward(100), .rotate(45), .home])
        let state = frames.last!.tortoiseState
        #expect(isClose(state.position, Point.zero))
        #expect(isClose(state.heading, 0))
    }

    @Test("home with pen down produces a stroke back to origin")
    func homeDrawsLineWhenPenDown() {
        let frames = CommandPlayer.play(commands: [.forward(100), .home])
        #expect(isClose(frames[1].newStroke!.to, Point.zero))
    }

    @Test("setPosition teleports tortoise")
    func setPositionMovesTortoise() {
        let target = Point(x: 30, y: -40)
        let frames = CommandPlayer.play(commands: [.setPosition(target)])
        #expect(frames[0].tortoiseState.position == target)
    }

    @Test("setHeading changes heading without moving")
    func setHeadingChangesHeading() {
        let frames = CommandPlayer.play(commands: [.setHeading(90)])
        let state = frames[0].tortoiseState
        #expect(isClose(state.heading, 90))
        #expect(state.position == Point.zero)
    }

    @Test("beginFill / forward / endFill produces a Fill with 3 points")
    func fillTriangle() {
        let cmds: [TortoiseCommand] = [
            .beginFill,
            .forward(100),
            .rotate(120),
            .forward(100),
            .endFill,
        ]
        let frames = CommandPlayer.play(commands: cmds)
        #expect(frames.last!.completedFill != nil)
        #expect(frames.last!.completedFill!.points.count == 3)
    }

    @Test("fill color is taken from fillColor command")
    func fillColorApplied() {
        let cmds: [TortoiseCommand] = [
            .fillColor(.blue),
            .beginFill,
            .forward(100),
            .rotate(120),
            .forward(100),
            .endFill,
        ]
        let frames = CommandPlayer.play(commands: cmds)
        #expect(frames.last!.completedFill?.color == .blue)
    }

    @Test("clear sets didClear flag")
    func clearSetsFlag() {
        let frames = CommandPlayer.play(commands: [.forward(100), .clear])
        #expect(frames.last!.didClear)
        #expect(!frames.first!.didClear)
    }

    @Test("clear during fill discards the fill (matching Python turtle)")
    func clearDiscardsInProgressFill() {
        let cmds: [TortoiseCommand] = [
            .beginFill,
            .forward(100),
            .rotate(120),
            .forward(100),
            .clear,
            .endFill,
        ]
        let frames = CommandPlayer.play(commands: cmds)
        #expect(frames.allSatisfy { $0.completedFill == nil })
    }

    @Test("fill started after clear contains only post-clear points")
    func fillAfterClearStartsFresh() {
        let cmds: [TortoiseCommand] = [
            .beginFill,
            .forward(100),
            .clear,
            .endFill,
            .beginFill,
            .forward(100),
            .rotate(120),
            .forward(100),
            .endFill,
        ]
        let frames = CommandPlayer.play(commands: cmds)
        let fill = frames.last!.completedFill
        #expect(fill != nil)
        #expect(fill?.points.count == 3)
    }

    @Test("backgroundColor command updates background color")
    func backgroundColorUpdates() {
        let frames = CommandPlayer.play(commands: [.backgroundColor(.cyan)])
        #expect(frames[0].backgroundColor == .cyan)
    }

    @Test("speed clamped to non-negative")
    func speedClamped() {
        let frames = CommandPlayer.play(commands: [.speed(-1)])
        #expect(frames[0].tortoiseState.speed == 0)
    }

    @Test("penWidth clamped to non-negative")
    func penWidthClamped() {
        let frames = CommandPlayer.play(commands: [.penWidth(-5)])
        #expect(frames[0].tortoiseState.penWidth == 0)
    }

    @Test("square: 4 forward+rotate produces correct final position")
    func squareEndsAtOrigin() {
        var cmds: [TortoiseCommand] = []
        for _ in 1...4 {
            cmds.append(.forward(100))
            cmds.append(.rotate(90))
        }
        let frames = CommandPlayer.play(commands: cmds)
        #expect(isClose(frames.last!.tortoiseState.position, Point.zero))
    }

    @Test("full circle arc returns tortoise to start position")
    func fullArcReturnsToStart() {
        let frames = CommandPlayer.play(commands: [.arc(radius: 100, extent: 360)])
        #expect(isClose(frames.last!.tortoiseState.position, Point.zero))
    }

    @Test("quarter circle arc moves tortoise to correct position and heading")
    func quarterArcPosition() {
        let frames = CommandPlayer.play(commands: [.arc(radius: 100, extent: 90)])
        let state = frames.last!.tortoiseState
        #expect(isClose(state.position, Point(x: -100, y: 100)))
        #expect(isClose(state.heading, 270))
    }

    @Test("negative radius arc emits an absolute radius with flipped sweep")
    func negativeRadiusArcStroke() {
        let frames = CommandPlayer.play(commands: [.arc(radius: -40, extent: 90)])
        let arc = frames.last!.newArcStroke!
        // Center (40, 0) is on the tortoise's right; the stroke is normalized
        // to a positive radius with the sweep direction flipped.
        #expect(isClose(arc.center, Point(x: 40, y: 0)))
        #expect(isClose(arc.radius, 40))
        #expect(isClose(arc.startAngle, 180))
        #expect(isClose(arc.sweep, -90))
        let state = frames.last!.tortoiseState
        #expect(isClose(state.position, Point(x: 40, y: 40)))
        #expect(isClose(state.heading, 90))
    }

    @Test("rotate and setHeading normalize heading to [0, 360)")
    func headingNormalizedOnReplay() {
        let counterclockwise = CommandPlayer.play(commands: [.rotate(-90)])
        #expect(isClose(counterclockwise.last!.tortoiseState.heading, 270))
        let wrapped = CommandPlayer.play(commands: [.setHeading(-450), .rotate(720)])
        #expect(isClose(wrapped.last!.tortoiseState.heading, 270))
    }

    @Test("arc with pen down produces an ArcStroke")
    func arcProducesArcStroke() {
        let frames = CommandPlayer.play(commands: [.arc(radius: 50, extent: 180)])
        #expect(frames.last!.newArcStroke != nil)
        #expect(frames.last!.newStroke == nil)
    }

    @Test("arc with pen up produces no stroke")
    func arcPenUpNoStroke() {
        let frames = CommandPlayer.play(commands: [.penUp, .arc(radius: 50, extent: 90)])
        #expect(frames.last!.newArcStroke == nil)
    }
}

// MARK: - Tortoise / CommandPlayer consistency

@Suite("Tortoise / CommandPlayer consistency")
@MainActor
struct StateConsistencyTests {
    @Test("random program: recorded state matches CommandPlayer replay")
    func randomProgramMatchesReplay() {
        // Deterministic LCG so failures are reproducible.
        var seed: UInt64 = 0x5DEE_CE66_D123_4567
        func nextDouble(_ range: ClosedRange<Double>) -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let unit = Double(seed >> 11) * (1.0 / 9_007_199_254_740_992.0)  // ÷ 2^53
            return range.lowerBound + unit * (range.upperBound - range.lowerBound)
        }

        let t = Tortoise()
        for step in 0..<300 {
            switch step % 10 {
            case 0: t.forward(nextDouble(-150...150))
            case 1: t.right(nextDouble(-720...720))
            case 2: t.left(nextDouble(0...360))
            case 3: t.circle(radius: nextDouble(-120...120), extent: nextDouble(-400...400))
            case 4: t.setPosition(x: nextDouble(-200...200), y: nextDouble(-200...200))
            case 5: t.heading = nextDouble(-720...720)
            case 6: t.penWidth = nextDouble(-2...9)
            case 7:
                if step % 20 == 7 {
                    t.penUp()
                }
                else {
                    t.penDown()
                }
            case 8: t.speed = nextDouble(-1...10)
            default: t.home()
            }
        }

        let replayed = CommandPlayer.play(commands: t.commands).last!.tortoiseState
        #expect(isClose(t.position, replayed.position))
        #expect(isClose(t.heading, replayed.heading))
        #expect(t.isPenDown == replayed.isPenDown)
        #expect(t.penWidth == replayed.penWidth)
        #expect(t.speed == replayed.speed)
    }
}

// MARK: - Color

@Suite("Color")
struct ColorTests {
    @Test("components clamped to 0...1")
    func clampComponents() {
        let c = Color(red: -0.5, green: 1.5, blue: 0.5)
        #expect(c.red == 0)
        #expect(c.green == 1)
        #expect(c.blue == 0.5)
    }

    @Test("Color equality")
    func equality() {
        #expect(Color.red == Color(red: 1, green: 0, blue: 0))
        #expect(Color.red != Color.blue)
    }
}

// MARK: - Point

@Suite("Point")
struct PointTests {
    @Test("magnitude of (3, 4) is 5")
    func magnitude() {
        #expect(isClose(Point(x: 3, y: 4).magnitude, 5))
    }

    @Test("distance between two points")
    func distance() {
        #expect(isClose(Point(x: 0, y: 0).distance(to: Point(x: 3, y: 4)), 5))
    }
}
