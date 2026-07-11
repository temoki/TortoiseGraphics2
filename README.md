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

### Turtle API quick reference

```swift
🐢.forward(100)          // move forward
🐢.backward(50)          // move backward
🐢.right(90)             // rotate clockwise
🐢.left(45)              // rotate counterclockwise
🐢.penUp()               // lift pen (no drawing)
🐢.penDown()             // lower pen (resume drawing)
🐢.penColor = .red       // pen color
🐢.penWidth = 2          // stroke width
🐢.fillColor = .yellow
🐢.beginFill()
🐢.circle(radius: 50)    // filled circle
🐢.endFill()
🐢.home()                // return to origin, heading north
🐢.speed = 0             // instant (no animation)
🐢.backgroundColor = .black
```

Python-style shorthand aliases (`fd`, `bk`, `rt`, `lt`, `pu`, `pd`, `ht`,
`st`, `goto`, `seth`) are also available.

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
