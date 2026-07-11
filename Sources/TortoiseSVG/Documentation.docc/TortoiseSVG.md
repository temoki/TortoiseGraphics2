# ``TortoiseSVG``

SVG export for TortoiseGraphics.

## Overview

`TortoiseSVG` converts a ``TurtleCommand`` stream into a self-contained,
static SVG document. It is a **pure function** — no platform APIs, no side
effects, no Foundation URL types required for the core `render` path.

```swift
// Render to a String
let svg = TortoiseSVG.render(commands: 🐢.commands, canvasSize: 🐢.canvasSize)

// Write directly to a file
try TortoiseSVG.write(commands: 🐢.commands,
                      canvasSize: 🐢.canvasSize,
                      to: URL(filePath: "drawing.svg"))
```

The SVG `viewBox` matches the logical canvas size, so the output scales
losslessly in any browser or vector editor.

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
matching the visual behavior of `TortoiseCanvasView`.

## Topics

### Export

- ``TortoiseSVG``
