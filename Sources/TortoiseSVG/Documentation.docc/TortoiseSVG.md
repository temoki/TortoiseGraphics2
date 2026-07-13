# ``TortoiseSVG``

SVG export for TortoiseGraphics.

## Overview

`TortoiseSVG` converts a ``Tortoise`` command stream into a self-contained,
static SVG document. It is a **pure function** — no platform APIs, no side effects.

```swift
import TortoiseSVG

let 🐢 = Tortoise()
🐢.penColor = .blue
for _ in 1...4 {
    🐢.forward(100)
    🐢.right(90)
}

let svg = TortoiseSVG.render(🐢)
// or equivalently:
let svg = 🐢.svg()

// Write to a file using Swift's built-in String method
try svg.write(to: URL(filePath: "drawing.svg"), atomically: true, encoding: .utf8)
```

By default (`fit: true`), the SVG `viewBox` is cropped to the actual drawing
bounding box, producing a tight output. Pass `fit: false` to keep the full
logical canvas size as the `viewBox`.

### What is supported

| Feature | SVG element |
|---------|-------------|
| Line strokes | `<line stroke-linecap="round">` |
| Arc strokes | `<path d="M… A…">` |
| Filled polygons (`beginFill`/`endFill`) | `<polygon>` |
| Background color | `<rect>` |
| Semi-transparent colors | `rgba(r,g,b,a)` |
| `clear` command | Removes all prior elements |

Fill polygons are rendered **below** their outline strokes in the SVG output,
matching the visual behavior of ``TortoiseCanvas``.

## Topics

### Export

- ``TortoiseSVG``
- ``Tortoise/svg(fit:)``
