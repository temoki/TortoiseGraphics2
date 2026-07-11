import Foundation

/// Replays a sequence of ``TurtleCommand`` values into ``PlaybackFrame`` values.
///
/// This is a pure function: the same input always produces the same output,
/// with no side effects. All rendering backends (SwiftUI, SVG, PNG) call this.
public struct CommandPlayer {
    public static func play(
        commands: [TurtleCommand],
        initialTurtle: TurtleState = .default,
        initialBackgroundColor: Color = .white
    ) -> [PlaybackFrame] {
        var frames: [PlaybackFrame] = []
        frames.reserveCapacity(commands.count)

        var turtle = initialTurtle
        var bgColor = initialBackgroundColor
        var fillPoints: [Vec2D]? = nil

        for (index, command) in commands.enumerated() {
            let isFillActive = fillPoints != nil
            var newStroke: Stroke? = nil
            var newArcStroke: ArcStroke? = nil
            var completedFill: Fill? = nil
            var newDot: Dot? = nil
            var didClear = false

            switch command {
            case .forward(let distance):
                let next = turtle.position.moved(distance: distance, heading: turtle.heading)
                if turtle.isPenDown {
                    newStroke = Stroke(
                        from: turtle.position, to: next,
                        color: turtle.penColor, width: turtle.penWidth
                    )
                }
                fillPoints?.append(next)
                turtle.position = next

            case .rotate(let degrees):
                turtle.heading = (turtle.heading + degrees).truncatingRemainder(dividingBy: 360)

            case .home:
                let next = Vec2D.zero
                if turtle.isPenDown {
                    newStroke = Stroke(
                        from: turtle.position, to: next,
                        color: turtle.penColor, width: turtle.penWidth
                    )
                }
                fillPoints?.append(next)
                turtle.position = next
                turtle.heading = 0

            case .setPosition(let pos):
                if turtle.isPenDown {
                    newStroke = Stroke(
                        from: turtle.position, to: pos,
                        color: turtle.penColor, width: turtle.penWidth
                    )
                }
                fillPoints?.append(pos)
                turtle.position = pos

            case .setHeading(let degrees):
                turtle.heading = degrees.truncatingRemainder(dividingBy: 360)

            case .penDown:
                turtle.isPenDown = true

            case .penUp:
                turtle.isPenDown = false

            case .penColor(let color):
                turtle.penColor = color

            case .penWidth(let width):
                turtle.penWidth = max(0, width)

            case .fillColor(let color):
                turtle.fillColor = color

            case .beginFill:
                fillPoints = [turtle.position]

            case .endFill:
                if let points = fillPoints, points.count >= 3 {
                    completedFill = Fill(points: points, color: turtle.fillColor)
                }
                fillPoints = nil

            case .showTurtle:
                turtle.isVisible = true

            case .hideTurtle:
                turtle.isVisible = false

            case .speed(let s):
                turtle.speed = max(0, s)

            case .backgroundColor(let color):
                bgColor = color

            case .clear:
                didClear = true

            case .dot(let size):
                newDot = Dot(center: turtle.position, size: size, color: turtle.penColor)

            case .arc(let radius, let extent):
                let center = Tortoise.arcCenter(position: turtle.position, heading: turtle.heading, radius: radius)
                let dx = turtle.position.x - center.x
                let dy = turtle.position.y - center.y
                let startAngleDeg = atan2(dy, dx) * (180 / .pi)
                let endAngleRad = (startAngleDeg + extent) * (.pi / 180)
                let newPos = Vec2D(
                    x: center.x + radius * cos(endAngleRad),
                    y: center.y + radius * sin(endAngleRad)
                )

                if turtle.isPenDown {
                    newArcStroke = ArcStroke(
                        center: center,
                        radius: radius,
                        startAngle: startAngleDeg,
                        sweep: extent,
                        color: turtle.penColor,
                        width: turtle.penWidth
                    )
                }
                fillPoints?.append(newPos)
                turtle.position = newPos
                turtle.heading = (turtle.heading - extent).truncatingRemainder(dividingBy: 360)
            }

            frames.append(PlaybackFrame(
                commandIndex: index,
                turtleState: turtle,
                backgroundColor: bgColor,
                newStroke: newStroke,
                newArcStroke: newArcStroke,
                completedFill: completedFill,
                newDot: newDot,
                didClear: didClear,
                isFillActive: isFillActive
            ))
        }

        return frames
    }

}
