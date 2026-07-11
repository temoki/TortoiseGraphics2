# ``TortoiseCore``

Turtle-graphics engine — platform-independent API and command stream.

## Overview

`TortoiseCore` is the foundation of TortoiseGraphics. Create a ``Tortoise``,
call drawing methods on it, then pass ``Tortoise/commands`` to any renderer.

```swift
let 🐢 = Tortoise()
🐢.penColor = .red
for _ in 1...4 {
    🐢.forward(100)
    🐢.right(90)
}
// 🐢.commands is a [TurtleCommand] ready for TortoiseUI, TortoiseSVG, or your own renderer.
```

The design follows an **event-sourcing pattern**: the turtle accumulates
``TurtleCommand`` values; rendering is handled by separate consumers
(`TortoiseUI`, `TortoiseSVG`) that replay the same stream as a pure function.
This means animation, SVG export, and unit tests all share a single source of truth.

``CommandPlayer`` converts a command stream into ``PlaybackFrame`` values —
a snapshot of turtle state after each command — which renderers step through
to produce output.

### Coordinate system

- **Origin** — center of the logical canvas.
- **Y axis** — up (positive Y = north). Renderers handle the flip to screen coordinates.
- **Heading** — 0 = north, clockwise positive.
- **Arc angles** — 0 = east, counterclockwise positive (standard math convention).

## Topics

### Turtle API

- ``Tortoise``

### Commands

- ``TurtleCommand``

### Playback

- ``CommandPlayer``
- ``PlaybackFrame``

### Drawing Output

- ``Stroke``
- ``ArcStroke``
- ``Fill``

### Value Types

- ``Color``
- ``Vec2D``
- ``Size2D``
- ``Angle``
- ``TurtleState``
