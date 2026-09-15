# ``TortoiseCore``

Tortoise-graphics engine — platform-independent API and command stream.

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
// 🐢.commands is a [TortoiseCommand] ready for TortoiseUI, TortoiseSVG, or your own renderer.
```

The design follows an **event-sourcing pattern**: the tortoise accumulates
``TortoiseCommand`` values; rendering is handled by separate consumers
(`TortoiseUI`, `TortoiseSVG`) that replay the same stream as a pure function.
This means animation, SVG export, and unit tests all share a single source of truth.

``CommandPlayer`` converts a command stream into ``PlaybackFrame`` values —
a snapshot of tortoise state after each command — which renderers step through
to produce output.

### Pen-width taper

``Tortoise/forward(_:widthTo:steps:)`` and
``Tortoise/circle(radius:extent:widthTo:steps:)`` ramp the pen width across a
move:

```swift
🐢.penWidth = 1
🐢.forward(200, widthTo: 12)   // a stroke that thickens as it is drawn
```

There is no variable-width stroke primitive — the move is subdivided into
sub-segments of constant width, so the result is an ordinary command stream that
every renderer already understands and that serializes unchanged. The step count
is chosen from the *width* change, not the distance, and a taper whose end width
equals its start width records a single plain move.

### Coordinate system

- **Origin** — center of the logical canvas.
- **Y axis** — up (positive Y = north). Renderers handle the flip to screen coordinates.
- **Heading** — 0 = north, clockwise positive.
- **Arc angles** — 0 = east, counterclockwise positive (standard math convention).

## Topics

### Tortoise API

- ``Tortoise``

### Commands

- ``TortoiseCommand``

### Playback

- ``CommandPlayer``
- ``PlaybackFrame``

### Drawing Output

- ``Stroke``
- ``ArcStroke``
- ``Fill``
- ``Dot``

### Geometry

- ``DrawingBounds``

### Value Types

- ``Color``
- ``Point``
- ``Size``
- ``TortoiseState``

### Serialization

- <doc:CommandSerialization>
