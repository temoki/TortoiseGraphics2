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
to fit the actual drawing bounding box. Use `.tortoiseSprite(_:)` to draw the
tortoise as your own image instead of the built-in triangle.

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

### Tortoise sprite

``TortoiseSprite`` controls how the tortoise itself is drawn. The default is
``TortoiseSprite/triangle``; pass ``TortoiseSprite/image(_:size:)`` to use
your own artwork:

```swift
TortoiseCanvas(🐢)
    .tortoiseSprite(.image(Image("Turtle"), size: CGSize(width: 40, height: 40)))
```

The image is centered on the tortoise's position and rotated so its top edge
faces the heading, so supply artwork that points up. `size` is a bounding box
in points at viewport scale 1: the image is scaled to fit inside it with its
aspect ratio preserved, and — like the triangle — scales with the viewport,
clamped to 0.5×–2×. ``ViewportMode/autoFit`` insets the drawing by the
sprite's half-diagonal, so a large sprite never clips at the view edge.

### Drawing the tortoise yourself

Sometimes the tortoise has to be something a `Canvas` cannot draw: a SwiftUI
view above the canvas, a sprite in another engine, a 3-D model standing on a
real table in an immersive space. Three pieces make that possible, and they
are meant to be used together.

```swift
TortoiseCanvas(🐢, player: player)
    .tortoiseSprite(.hidden)          // the canvas draws no cursor

// …and somewhere that already runs once per frame:
if let state = player.currentTortoiseState, state.isVisible {
    let t = ViewportMode.autoFit.transform(
        canvasSize: 🐢.canvasSize, viewSize: viewSize,
        drawingBounds: DrawingBounds.compute(
            from: CommandPlayer.play(commands: 🐢.commands)),
        spriteHalfExtent: TortoiseSprite.hidden.halfExtent)
    let point = CGPoint(x: state.position.x, y: state.position.y).applying(t)
    // …draw your own tortoise at `point`, rotated by `state.heading`.
}
```

- ``TortoiseSprite/hidden`` stops the canvas drawing its own cursor. It is a
  property of one view, unlike `hideTortoise()`, which records a command and
  so travels with the drawing into every renderer and every saved stream.
- ``TortoisePlayer/currentTortoiseState`` is where the tortoise is *right
  now*, interpolated between commands — so a cursor of your own walks with
  the line instead of jumping a command at a time. It changes on every
  display frame, which is why it wants to be read from a per-frame context
  rather than observed from a SwiftUI `body`.
- ``ViewportMode/transform(canvasSize:viewSize:drawingBounds:spriteHalfExtent:)``
  maps tortoise coordinates onto the view, so the cursor lands exactly where
  the built-in sprite would have. Reimplementing that mapping is the thing
  worth avoiding: it agrees on the day it is written, and drifts silently
  afterwards.

With ``TortoiseSprite/hidden`` the `.autoFit` inset becomes zero — there is no
sprite to keep clear of the edge — so the drawing runs edge to edge and any
margin is yours to add.

## Topics

### Views

- ``TortoiseCanvas``

### Playback Control

- ``TortoisePlayer``

### Viewport

- ``ViewportMode``

### Appearance

- ``TortoiseSprite``
