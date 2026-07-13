import TortoiseCore

extension DrawingScenario {
    /// Feature-grouped scenarios that together cover every `TortoiseCommand` case.
    public static let all: [DrawingScenario] = [
        linesAndTurns,
        penStyles,
        arcs,
        filledShapes,
        fillWithArc,
        dots,
        teleportAndHome,
        backgroundAndColors,
        clearAndRedraw,
        hiddenTortoise,
        showAfterHide,
        speedChanges,
        showcase,
    ]

    /// Covers `forward` and `rotate` (via forward/backward/right/left).
    public static let linesAndTurns = DrawingScenario("linesAndTurns") { t in
        for _ in 0..<4 {
            t.forward(100)
            t.right(90)
        }
        t.left(45)
        t.forward(60)
        t.backward(30)
        t.left(90)
        t.forward(60)
    }

    /// Covers `penDown`, `penUp`, `penColor`, and `penWidth`.
    public static let penStyles = DrawingScenario("penStyles") { t in
        let styles: [(color: Color, width: Double)] = [
            (.red, 1), (.green, 3), (.blue, 5), (.orange, 7), (.purple, 9),
        ]
        for (index, style) in styles.enumerated() {
            t.penColor = style.color
            t.penWidth = style.width
            t.heading = Double(index * 30 - 60)
            t.forward(120)
            t.penUp()
            t.home()
            t.penDown()
        }
        t.penColor = .black
        t.penWidth = 3
        t.heading = 180
        for _ in 0..<4 {
            t.penDown()
            t.forward(20)
            t.penUp()
            t.forward(15)
        }
    }

    /// Covers `arc`: full circle, half circle (CCW), and negative extent (CW).
    public static let arcs = DrawingScenario("arcs") { t in
        t.circle(radius: 60)
        t.penUp()
        t.setPosition(x: -100, y: 60)
        t.penDown()
        t.circle(radius: 40, extent: 180)
        t.penUp()
        t.setPosition(x: 100, y: -80)
        t.penDown()
        t.circle(radius: 40, extent: -120)
    }

    /// Covers `fillColor`, `beginFill`, and `endFill` (with and without outline).
    public static let filledShapes = DrawingScenario("filledShapes") { t in
        t.penColor = .red
        t.penWidth = 2
        t.fillColor = .yellow
        t.beginFill()
        for _ in 0..<3 {
            t.forward(100)
            t.right(120)
        }
        t.endFill()
        t.penUp()
        t.setPosition(x: 60, y: -120)
        t.fillColor = .cyan
        t.beginFill()
        for _ in 0..<4 {
            t.forward(80)
            t.right(90)
        }
        t.endFill()
    }

    /// Documents the fill-with-arc semantics (fill polygon passes through arc endpoints).
    public static let fillWithArc = DrawingScenario("fillWithArc") { t in
        t.penColor = .purple
        t.penWidth = 2
        t.fillColor = .magenta
        t.penUp()
        t.setPosition(x: -50, y: -50)
        t.penDown()
        t.beginFill()
        t.circle(radius: 50, extent: 180)
        t.forward(100)
        t.endFill()
    }

    /// Covers `dot`, including the default size derived from the pen width.
    public static let dots = DrawingScenario("dots") { t in
        t.penUp()
        let dotStyles: [(color: Color, size: Double)] = [(.red, 4), (.green, 10), (.blue, 24)]
        for style in dotStyles {
            t.penColor = style.color
            t.dot(size: style.size)
            t.forward(50)
        }
        t.penColor = .orange
        t.penWidth = 6
        t.dot()
    }

    /// Covers `setPosition` (also via setX/setY), `setHeading`, and `home`.
    public static let teleportAndHome = DrawingScenario("teleportAndHome") { t in
        t.setPosition(x: -120, y: 120)
        t.forward(40)
        t.setX(120)
        t.setY(-120)
        t.heading = 90
        t.forward(40)
        t.home()
    }

    /// Covers `backgroundColor`.
    public static let backgroundAndColors = DrawingScenario("backgroundAndColors") { t in
        t.backgroundColor = .black
        t.penWidth = 2
        for step in 1...12 {
            t.penColor = step.isMultiple(of: 2) ? .yellow : .white
            t.forward(Double(step) * 12)
            t.right(90)
        }
    }

    /// Covers `clear`: only the shape drawn after clearing may remain.
    public static let clearAndRedraw = DrawingScenario("clearAndRedraw") { t in
        t.penColor = .red
        for _ in 0..<4 {
            t.forward(80)
            t.right(90)
        }
        t.clear()
        t.penColor = .blue
        for _ in 0..<3 {
            t.forward(80)
            t.right(120)
        }
    }

    /// Covers `hideTortoise`: the canvas snapshot must not show the tortoise sprite.
    public static let hiddenTortoise = DrawingScenario("hiddenTortoise") { t in
        t.hideTortoise()
        t.penColor = .green
        t.penWidth = 3
        for _ in 0..<5 {
            t.forward(80)
            t.right(72)
        }
    }

    /// Covers `showTortoise`: the sprite must reappear at the final pose.
    public static let showAfterHide = DrawingScenario("showAfterHide") { t in
        t.hideTortoise()
        t.penColor = .purple
        for _ in 0..<4 {
            t.forward(90)
            t.right(90)
        }
        t.showTortoise()
    }

    /// Covers `speed`: speed changes must not affect the final rendered output.
    public static let speedChanges = DrawingScenario("speedChanges") { t in
        t.speed = 0
        t.forward(100)
        t.right(90)
        t.forward(100)
        t.speed = 8
        t.right(90)
        t.forward(100)
        t.right(90)
        t.forward(100)
    }

    /// Kitchen-sink regression scene combining fills, arcs, dots, and teleports.
    public static let showcase = DrawingScenario("showcase") { t in
        t.backgroundColor = Color(red: 0.9, green: 0.95, blue: 1)
        t.penColor = .orange
        t.penWidth = 2
        t.fillColor = .yellow
        t.beginFill()
        for _ in 0..<5 {
            t.forward(140)
            t.right(144)
        }
        t.endFill()
        t.penUp()
        t.setPosition(x: -100, y: -120)
        t.penDown()
        t.penColor = .blue
        t.circle(radius: 40)
        t.penUp()
        t.setPosition(x: 120, y: -120)
        t.penColor = .red
        t.dot(size: 16)
        t.hideTortoise()
    }
}
