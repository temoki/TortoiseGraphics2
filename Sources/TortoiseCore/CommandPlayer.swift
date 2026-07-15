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

            // State transitions go through the shared reducer (the same one
            // Tortoise uses); the switch below only derives drawing output.
            let before = tortoise
            tortoise = tortoise.applying(command)

            switch command {
            case .forward, .home, .setPosition:
                if before.isPenDown {
                    newStroke = Stroke(
                        from: before.position, to: tortoise.position,
                        color: before.penColor, width: before.penWidth
                    )
                }
                fillPoints?.append(tortoise.position)

            case .arc(let radius, let extent):
                if before.isPenDown {
                    let center = Tortoise.arcCenter(
                        position: before.position, heading: before.heading, radius: radius)
                    let dx = before.position.x - center.x
                    let dy = before.position.y - center.y
                    // A negative radius mirrors the arc; renderers receive an
                    // absolute radius with the sweep direction flipped instead.
                    newArcStroke = ArcStroke(
                        center: center,
                        radius: abs(radius),
                        startAngle: atan2(dy, dx) * (180 / .pi),
                        sweep: radius < 0 ? -extent : extent,
                        color: before.penColor,
                        width: before.penWidth
                    )
                }
                fillPoints?.append(tortoise.position)

            case .beginFill:
                fillPoints = [tortoise.position]

            case .endFill:
                if let points = fillPoints, points.count >= 3 {
                    completedFill = Fill(points: points, color: tortoise.fillColor)
                }
                fillPoints = nil

            case .backgroundColor(let color):
                bgColor = color

            case .clear:
                didClear = true
                // Matching Python turtle: clear() discards an in-progress fill,
                // so a later endFill does not resurrect pre-clear vertices.
                fillPoints = nil

            case .dot(let size):
                newDot = Dot(center: tortoise.position, size: size, color: tortoise.penColor)

            case .rotate, .setHeading, .penDown, .penUp, .penColor, .penWidth,
                .fillColor, .showTortoise, .hideTortoise, .speed:
                break  // State-only commands: no drawing output.
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
