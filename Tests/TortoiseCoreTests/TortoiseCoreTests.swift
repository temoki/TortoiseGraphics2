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
        #expect(isClose(t.heading, -90))
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
        #expect(isClose(state.heading, -90))
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

// MARK: - Angle

@Suite("Angle")
struct AngleTests {
    @Test("degrees ↔ radians round-trip")
    func degreesRadians() {
        let a = Angle(degrees: 90)
        #expect(isClose(a.radians, .pi / 2))
        let b = Angle(radians: .pi)
        #expect(isClose(b.degrees, 180))
    }

    @Test("angle addition")
    func addition() {
        let a = Angle(degrees: 45) + Angle(degrees: 45)
        #expect(isClose(a.degrees, 90))
    }

    @Test("angle negation")
    func negation() {
        let a = -Angle(degrees: 30)
        #expect(isClose(a.degrees, -30))
    }
}
