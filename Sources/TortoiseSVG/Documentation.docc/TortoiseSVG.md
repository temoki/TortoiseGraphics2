# ``TortoiseSVG``

SVG export for TortoiseGraphics.

## Overview

`TortoiseSVG` walks a ``TurtleCommand`` stream and builds an SVG document
as a pure function — no platform APIs, no side effects.

Supported features:
- Pen color and stroke width
- `beginFill` / `endFill` filled polygons
- Background color
- Center-origin to SVG coordinate conversion

## Topics

### Export

- ``SVGRenderer``
