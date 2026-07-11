# ``TortoiseCore``

Turtle graphics engine core — platform-independent command stream and API.

## Overview

`TortoiseCore` is the foundation of TortoiseGraphics. It provides:

- **``Tortoise``** — the main API for drawing with a turtle
- **``TurtleCommand``** — `Sendable` value-type commands produced by the API
- **Value types** — ``Color``, ``Vec2D``, ``Angle``

All rendering (SwiftUI canvas, SVG, PNG) consumes the same command stream,
making it trivial to test and extend.

## Topics

### Turtle API

- ``Tortoise``

### Commands

- ``TurtleCommand``

### Value Types

- ``Color``
- ``Vec2D``
- ``Angle``
