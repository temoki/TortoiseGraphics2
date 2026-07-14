import Foundation

/// Replays a sequence of ``TortoiseCommand`` values into ``PlaybackFrame`` values.
///
/// This is a pure function: the same input always produces the same output,
/// with no side effects. All rendering backends (SwiftUI, SVG, PNG) call this.
public struct CommandPlayer {
    public static func play(
        commands: [TortoiseCommand],
        initialTortoise: TortoiseState = .default,
        initialBackgroundColor: Color = .clear
    ) -> [PlaybackFrame] {
        var frames: [PlaybackFrame] = []
        frames.reserveCapacity(commands.count)

        var tortoise = initialTortoise
        var bgColor = initialBackgroundColor
        var fillPoints: [Point]? = nil

        for (index, command) in commands.enumerated() {
            let isFillActive = fillPoints != nil
            var newStroke: Stroke? = nil
            var newArcStroke: ArcStroke? = nil
            var completedFill: Fill? = nil
            var newDot: Dot? = nil
            var didClear = false

            switch command {
            case .forward(let distance):
                let next = tortoise.position.moved(distance: distance, heading: tortoise.heading)
                if tortoise.isPenDown {
                    newStroke = Stroke(
                        from: tortoise.position, to: next,
                        color: tortoise.penColor, width: tortoise.penWidth
                    )
                }
                fillPoints?.append(next)
                tortoise.position = next

            case .rotate(let degrees):
                tortoise.heading = (tortoise.heading + degrees).truncatingRemainder(dividingBy: 360)

            case .home:
                let next = Point.zero
                if tortoise.isPenDown {
                    newStroke = Stroke(
                        from: tortoise.position, to: next,
                        color: tortoise.penColor, width: tortoise.penWidth
                    )
                }
                fillPoints?.append(next)
                tortoise.position = next
                tortoise.heading = 0

            case .setPosition(let pos):
                if tortoise.isPenDown {
                    newStroke = Stroke(
                        from: tortoise.position, to: pos,
                        color: tortoise.penColor, width: tortoise.penWidth
                    )
                }
                fillPoints?.append(pos)
                tortoise.position = pos

            case .setHeading(let degrees):
                tortoise.heading = degrees.truncatingRemainder(dividingBy: 360)

            case .penDown:
                tortoise.isPenDown = true

            case .penUp:
                tortoise.isPenDown = false

            case .penColor(let color):
                tortoise.penColor = color

            case .penWidth(let width):
                tortoise.penWidth = max(0, width)

            case .fillColor(let color):
                tortoise.fillColor = color

            case .beginFill:
                fillPoints = [tortoise.position]

            case .endFill:
                if let points = fillPoints, points.count >= 3 {
                    completedFill = Fill(points: points, color: tortoise.fillColor)
                }
                fillPoints = nil

            case .showTortoise:
                tortoise.isVisible = true

            case .hideTortoise:
                tortoise.isVisible = false

            case .speed(let s):
                tortoise.speed = max(0, s)

            case .backgroundColor(let color):
                bgColor = color

            case .clear:
                didClear = true
                // Matching Python turtle: clear() discards an in-progress fill,
                // so a later endFill does not resurrect pre-clear vertices.
                fillPoints = nil

            case .dot(let size):
                newDot = Dot(center: tortoise.position, size: size, color: tortoise.penColor)

            case .arc(let radius, let extent):
                let center = Tortoise.arcCenter(
                    position: tortoise.position, heading: tortoise.heading, radius: radius)
                let dx = tortoise.position.x - center.x
                let dy = tortoise.position.y - center.y
                let startAngleDeg = atan2(dy, dx) * (180 / .pi)
                let endAngleRad = (startAngleDeg + extent) * (.pi / 180)
                let newPos = Point(
                    x: center.x + radius * cos(endAngleRad),
                    y: center.y + radius * sin(endAngleRad)
                )

                if tortoise.isPenDown {
                    newArcStroke = ArcStroke(
                        center: center,
                        radius: radius,
                        startAngle: startAngleDeg,
                        sweep: extent,
                        color: tortoise.penColor,
                        width: tortoise.penWidth
                    )
                }
                fillPoints?.append(newPos)
                tortoise.position = newPos
                tortoise.heading = (tortoise.heading - extent).truncatingRemainder(dividingBy: 360)
            }

            frames.append(
                PlaybackFrame(
                    commandIndex: index,
                    tortoiseState: tortoise,
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
