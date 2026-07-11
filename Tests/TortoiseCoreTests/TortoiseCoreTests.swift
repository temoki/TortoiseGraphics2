import Testing
@testable import TortoiseCore

// MARK: - Helpers

private let ε = 1e-10

private func isClose(_ a: Double, _ b: Double) -> Bool {
    abs(a - b) < ε
}

private func isClose(_ a: Vec2D, _ b: Vec2D) -> Bool {
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

    @Test("setPenColor appends .penColor")
    func penColorCommand() {
        let t = Tortoise()
        t.setPenColor(.red)
        #expect(t.commands == [.penColor(.red)])
    }

    @Test("setPenWidth appends .penWidth")
    func penWidthCommand() {
        let t = Tortoise()
        t.setPenWidth(3)
        #expect(t.commands == [.penWidth(3)])
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
        #expect(t.commands == [.setPosition(Vec2D(x: 10, y: 20))])
    }

    @Test("setHeading appends .setHeading")
    func setHeadingCommand() {
        let t = Tortoise()
        t.setHeading(270)
        #expect(t.commands == [.setHeading(270)])
    }

    @Test("Python aliases produce same commands as primary API")
    func pythonAliases() {
        let t1 = Tortoise()
        t1.forward(100)
        t1.backward(50)
        t1.right(90)
        t1.left(45)
        t1.penUp()
        t1.penDown()
        t1.hideTurtle()
        t1.showTurtle()

        let t2 = Tortoise()
        t2.fd(100)
        t2.bk(50)
        t2.rt(90)
        t2.lt(45)
        t2.pu()
        t2.pd()
        t2.ht()
        t2.st()

        #expect(t1.commands == t2.commands)
    }

    @Test("goto(x:y:) is alias for setPosition(x:y:)")
    func gotoAlias() {
        let t1 = Tortoise()
        t1.setPosition(x: 5, y: -3)
        let t2 = Tortoise()
        t2.goto(x: 5, y: -3)
        #expect(t1.commands == t2.commands)
    }

    @Test("seth is alias for setHeading")
    func sethAlias() {
        let t1 = Tortoise()
        t1.setHeading(180)
        let t2 = Tortoise()
        t2.seth(180)
        #expect(t1.commands == t2.commands)
    }
}

// MARK: - CommandPlayer

@Suite("CommandPlayer")
struct CommandPlayerTests {
    @Test("forward 100 from origin moves north by 100")
    func forwardNorth() {
        let frames = CommandPlayer.play(commands: [.forward(100)])
        #expect(frames.count == 1)
        let pos = frames[0].turtleState.position
        #expect(isClose(pos, Vec2D(x: 0, y: 100)))
    }

    @Test("rotate 90 then forward moves east")
    func forwardEastAfterRightTurn() {
        let frames = CommandPlayer.play(commands: [.rotate(90), .forward(100)])
        let pos = frames.last!.turtleState.position
        #expect(isClose(pos, Vec2D(x: 100, y: 0)))
    }

    @Test("rotate -90 then forward moves west")
    func forwardWestAfterLeftTurn() {
        let frames = CommandPlayer.play(commands: [.rotate(-90), .forward(100)])
        let pos = frames.last!.turtleState.position
        #expect(isClose(pos, Vec2D(x: -100, y: 0)))
    }

    @Test("rotate 180 then forward moves south")
    func forwardSouth() {
        let frames = CommandPlayer.play(commands: [.rotate(180), .forward(100)])
        let pos = frames.last!.turtleState.position
        #expect(isClose(pos, Vec2D(x: 0, y: -100)))
    }

    @Test("penDown forward produces a stroke")
    func strokeWhenPenDown() {
        let frames = CommandPlayer.play(commands: [.forward(50)])
        #expect(frames[0].newStroke != nil)
        #expect(frames[0].newStroke?.from == Vec2D.zero)
        #expect(isClose(frames[0].newStroke!.to, Vec2D(x: 0, y: 50)))
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
        let frames = CommandPlayer.play(commands: [
            .forward(100),
            .rotate(45),
            .home,
        ])
        let state = frames.last!.turtleState
        #expect(isClose(state.position, Vec2D.zero))
        #expect(isClose(state.heading, 0))
    }

    @Test("home with pen down produces a stroke back to origin")
    func homeDrawsLineWhenPenDown() {
        let frames = CommandPlayer.play(commands: [.forward(100), .home])
        let homeFrame = frames[1]
        #expect(homeFrame.newStroke != nil)
        #expect(isClose(homeFrame.newStroke!.to, Vec2D.zero))
    }

    @Test("setPosition teleports turtle")
    func setPositionMovesTurtle() {
        let target = Vec2D(x: 30, y: -40)
        let frames = CommandPlayer.play(commands: [.setPosition(target)])
        #expect(frames[0].turtleState.position == target)
    }

    @Test("setHeading changes heading without moving")
    func setHeadingChangesHeading() {
        let frames = CommandPlayer.play(commands: [.setHeading(90)])
        let state = frames[0].turtleState
        #expect(isClose(state.heading, 90))
        #expect(state.position == Vec2D.zero)
    }

    @Test("beginFill / forward / endFill produces a Fill with 3 points")
    func fillTriangle() {
        let cmds: [TurtleCommand] = [
            .beginFill,
            .forward(100),
            .rotate(120),
            .forward(100),
            .endFill,
        ]
        let frames = CommandPlayer.play(commands: cmds)
        let fillFrame = frames.last!
        #expect(fillFrame.completedFill != nil)
        #expect(fillFrame.completedFill!.points.count == 3)
    }

    @Test("fill color is taken from fillColor command")
    func fillColorApplied() {
        let cmds: [TurtleCommand] = [
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
        #expect(frames[0].turtleState.speed == 0)
    }

    @Test("penWidth clamped to non-negative")
    func penWidthClamped() {
        let frames = CommandPlayer.play(commands: [.penWidth(-5)])
        #expect(frames[0].turtleState.penWidth == 0)
    }

    @Test("square: 4 forward+rotate produces correct final position")
    func squareEndsAtOrigin() {
        var cmds: [TurtleCommand] = []
        for _ in 1...4 {
            cmds.append(.forward(100))
            cmds.append(.rotate(90))
        }
        let frames = CommandPlayer.play(commands: cmds)
        let pos = frames.last!.turtleState.position
        #expect(isClose(pos, Vec2D.zero))
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

// MARK: - Vec2D

@Suite("Vec2D")
struct Vec2DTests {
    @Test("magnitude of (3, 4) is 5")
    func magnitude() {
        #expect(isClose(Vec2D(x: 3, y: 4).magnitude, 5))
    }

    @Test("distance between two points")
    func distance() {
        let a = Vec2D(x: 0, y: 0)
        let b = Vec2D(x: 3, y: 4)
        #expect(isClose(a.distance(to: b), 5))
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
