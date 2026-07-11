# TortoiseGraphics

Swift turtle-graphics library for iOS, macOS, and visionOS.

```swift
let 🐢 = Tortoise()
🐢.penColor = .red
for _ in 1...36 {
    🐢.forward(200)
    🐢.right(170)
}
TortoiseCanvasView(🐢)
```

## Modules

| Module | Description |
|--------|-------------|
| **TortoiseCore** | Turtle API + command stream. Foundation-only; no platform dependencies. |
| **TortoiseUI** | SwiftUI animated canvas view (`TimelineView` + `Canvas`). |
| **TortoiseSVG** | Command stream → static SVG string or file. No platform dependencies. |

The design follows an event-sourcing pattern: `Tortoise` accumulates
`[TurtleCommand]`; rendering is handled by separate, pure-function
consumers that replay the same stream. This makes SVG export, animation,
and testing all share a single source of truth.

## Requirements

- **Swift** 6.2+
- **Xcode** 26+
- **Platforms** iOS 26+ · macOS 26+ · visionOS 26+

## Installation

Add the package in Xcode via **File › Add Package Dependencies**, or add it
to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/temoki/TortoiseGraphics", from: "2.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "TortoiseCore", package: "TortoiseGraphics"),
            .product(name: "TortoiseUI",   package: "TortoiseGraphics"),
            .product(name: "TortoiseSVG",  package: "TortoiseGraphics"),
        ]
    ),
]
```

Import only what you need — `TortoiseCore` alone is sufficient if you're
writing your own renderer.

## Usage

### Animated SwiftUI view

```swift
import TortoiseCore
import TortoiseUI

struct ContentView: View {
    let 🐢: Tortoise = {
        let t = Tortoise()
        t.speed = 5
        for _ in 1...4 {
            t.forward(100)
            t.right(90)
        }
        return t
    }()

    var body: some View {
        TortoiseCanvasView(🐢)
            .frame(width: 400, height: 400)
    }
}
```

`speed` ranges from 1 (slowest) to 10 (fastest). Set it to `0` for instant
rendering — useful for static previews and SVG export.

### SVG export

```swift
import TortoiseCore
import TortoiseSVG

let 🐢 = Tortoise()
🐢.speed = 0
🐢.penColor = .blue
for _ in 1...4 {
    🐢.forward(100)
    🐢.right(90)
}

// As a String
let svg = TortoiseSVG.render(commands: 🐢.commands, canvasSize: 🐢.canvasSize)

// Written directly to a file
try TortoiseSVG.write(commands: 🐢.commands, canvasSize: 🐢.canvasSize,
                      to: URL(filePath: "square.svg"))
```

### Tortoise API quick reference

#### Movement

| Method / Property | Description |
|---|---|
| `forward(_ distance: Double)` | Move forward by `distance` pixels |
| `backward(_ distance: Double)` | Move backward by `distance` pixels |
| `right(_ degrees: Double)` | Rotate clockwise |
| `left(_ degrees: Double)` | Rotate counterclockwise |
| `home()` | Teleport to origin and reset heading to north |
| `setPosition(x:y:)` / `setPosition(_:)` | Teleport to a position (pen draws if down) |
| `setX(_ x: Double)` | Teleport to `(x, y)` keeping current Y |
| `setY(_ y: Double)` | Teleport to `(x, y)` keeping current X |
| `circle(radius:extent:)` | Draw a circular arc (default `extent`: 360°) |
| `dot(size:)` | Draw a filled circle at the current position |

#### Pen

| Method / Property | Description |
|---|---|
| `penDown()` | Lower pen — movements draw lines |
| `penUp()` | Lift pen — movements don't draw |
| `isPenDown: Bool` | Whether the pen is currently down (read-only) |
| `penColor: Color` | Stroke color |
| `penWidth: Double` | Stroke width in logical units |

#### Fill

| Method / Property | Description |
|---|---|
| `beginFill()` | Start collecting fill polygon vertices |
| `endFill()` | Close and draw the fill polygon |
| `fillColor: Color` | Fill color |
| `isFilling: Bool` | Whether a fill region is currently active (read-only) |

#### Query

| Method / Property | Description |
|---|---|
| `position: Point` | Current position in turtle coordinates (read-only) |
| `heading: Double` | Current heading in degrees (0 = north, CW+); settable |
| `towards(x:y:)` / `towards(_:)` | Heading toward a point from current position |
| `distance(x:y:)` / `distance(_:)` | Distance to a point from current position |

#### Appearance

| Method / Property | Description |
|---|---|
| `showTurtle()` | Make the turtle visible |
| `hideTurtle()` | Hide the turtle |
| `isVisible: Bool` | Whether the turtle is visible (read-only) |

#### Canvas

| Method / Property | Description |
|---|---|
| `backgroundColor: Color` | Canvas background color |
| `clear()` | Erase all drawings (turtle state is preserved) |
| `speed: Double` | Animation speed: 1 (slowest) … 10 (fastest), 0 = instant |
| `canvasSize: Size` | Logical canvas dimensions |

## Architecture

```
Tortoise API calls
      │  produces
      ▼
[TurtleCommand]  ── pure value stream ──▶  TortoiseUI  (SwiftUI animation)
  (Sendable)                           ──▶  TortoiseSVG (static SVG export)
                                       ──▶  your own renderer
```

`CommandPlayer.play(commands:)` converts `[TurtleCommand]` into
`[PlaybackFrame]` — a snapshot of turtle state after each command. Both
`TortoiseUI` and `TortoiseSVG` build on top of this pure function.

## License

MIT. See [LICENSE](LICENSE).
