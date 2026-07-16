# ``TortoiseUI``

SwiftUI rendering and animation for TortoiseGraphics.

## Overview

`TortoiseUI` animates a ``TortoiseCommand`` stream as a SwiftUI view using
`TimelineView` and `Canvas`. The tortoise walks to each destination in real
time — `forward()` draws the line progressively and `circle()` traces the
arc, matching the classic tortoise-graphics feel.

```swift
// Closure form — configures a new Tortoise inline
TortoiseCanvas { 🐢 in
    🐢.speed = 5
    for _ in 1...4 {
        🐢.forward(100)
        🐢.right(90)
    }
}

// Instance form — pass an existing Tortoise
TortoiseCanvas(🐢)
```

Use the `.tortoiseViewport(_:)` modifier to change how the drawing maps onto
the view. The default is ``ViewportMode/autoFit``, which scales and centers
to fit the actual drawing bounding box.

### Speed

Playback speed is set per-program via `Tortoise.speed` (or the
``TortoiseCommand/speed(_:)`` command):

| Value | Effect |
|-------|--------|
| 1 | Slowest — 0.5 s per command |
| 5 | Default |
| 10 | Fastest — 0.05 s per command |
| 0 | Instant — all drawing appears immediately |

`speed(0)` is detected before the first visible drawing command and flushes
the entire program in the model's `init`, so instant-mode programs are
visible even in static Xcode Previews.

### Playback control

Pass a ``TortoisePlayer`` to ``TortoiseCanvas/init(_:player:)`` to pause,
resume, single-step, seek, and override the playback speed from your own UI:

```swift
@State private var player = TortoisePlayer()

var body: some View {
    TortoiseCanvas(🐢, player: player)
    Toggle("Pause", systemImage: "pause.fill", isOn: $player.isPaused)
    Button("Step", systemImage: "forward.frame.fill") { player.step() }
}
```

``TortoisePlayer/currentCommandIndex`` and ``TortoisePlayer/isFinished`` are
observable, so UI such as a "currently executing command" highlight can bind
to them directly.

Speed has two layers: `.speed()` commands in the stream are the *author's*
tempo (part of the drawing), while ``TortoisePlayer/speedOverride`` is the
*viewer's* control — while non-nil it takes precedence over every `.speed()`
command, and changing it never rewinds playback.

### Viewport modes

``ViewportMode`` controls how the logical canvas maps to the view's bounds:

- **`.autoFit`** (default) — scales and centers to fit the actual drawing
  bounding box. Use SwiftUI's `.padding()` to add space around the drawing.
- **`.scaleToFit`** — fits the full logical canvas inside the view, letterboxed.
- **`.original`** — 1 tortoise unit = 1 point, origin at view center.

## Topics

### Views

- ``TortoiseCanvas``

### Playback Control

- ``TortoisePlayer``

### Viewport

- ``ViewportMode``
