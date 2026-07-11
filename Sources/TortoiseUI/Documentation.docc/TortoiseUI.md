# ``TortoiseUI``

SwiftUI rendering and animation for TortoiseGraphics.

## Overview

`TortoiseUI` animates a ``TurtleCommand`` stream as a SwiftUI view using
`TimelineView` and `Canvas`. The turtle walks to each destination in real
time — `forward()` draws the line progressively and `circle()` traces the
arc, matching the classic turtle-graphics feel.

```swift
TortoiseCanvasView(🐢)
    .frame(width: 400, height: 400)
```

### Speed

Playback speed is set per-program via `Tortoise.speed` (or the
``TurtleCommand/speed(_:)`` command):

| Value | Effect |
|-------|--------|
| 1 | Slowest — 0.5 s per command |
| 5 | Default |
| 10 | Fastest — 0.05 s per command |
| 0 | Instant — all drawing appears immediately |

`speed(0)` is detected before the first visible drawing command and flushes
the entire program in the model's `init`, so instant-mode programs are
visible even in static Xcode Previews.

### Viewport modes

``ViewportMode`` controls how the logical canvas maps to the view's bounds:

- **`.scaleToFit`** (default) — fits the logical canvas inside the view,
  letterboxed. Matches the SVG `viewBox`.
- **`.original`** — 1 px = 1 logical unit, origin centered. The visible
  area grows as the window grows.

## Topics

### Views

- ``TortoiseCanvasView``

### Viewport

- ``ViewportMode``
