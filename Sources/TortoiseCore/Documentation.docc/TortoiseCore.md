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

### Tapered strokes

A pen can change width across a single move, so a stroke thickens or thins as
the tortoise lays it down:

```swift
🐢.penWidth = 1
🐢.forward(200, widthTo: 12)
🐢.circle(radius: 70, extent: 270, widthTo: 10)
```

Each is one ``TortoiseCommand`` — ``TortoiseCommand/taperedForward(distance:widthTo:)``
and ``TortoiseCommand/taperedArc(radius:extent:widthTo:)`` — so a taper occupies
a single ``PlaybackFrame`` and animates in the same time as the untapered move
it replaces. After the call ``Tortoise/penWidth`` is the width you asked for.

Renderers cannot express a varying width by stroking a path at one width, so
they fill the region the pen sweeps instead. ``StrokeOutline`` computes that
region, and both bundled renderers fill the same polygon, so they cannot
disagree about the shape of a taper. A stroke whose end width equals its start
width is not tapered at all (``Stroke/isTapered``) and is drawn the ordinary
way.

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
- ``StrokeOutline``

### Value Types

- ``Color``
- ``Point``
- ``Size``
- ``TortoiseState``

### Serialization

- <doc:CommandSerialization>
