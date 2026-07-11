# Changelog

## 2.0.0-beta1

Version 2 of [TortoiseGraphics](https://github.com/temoki/TortoiseGraphics), rewritten from scratch for Swift 6 strict concurrency and SwiftUI.

### New in v2

**Swift 6 & modern SwiftUI**
- Full strict concurrency compliance (`@MainActor`, `Sendable`)
- `TortoiseCanvasView` built on `TimelineView` + `Canvas` for smooth animation

**Event-sourcing architecture**
- `Tortoise` accumulates `[TortoiseCommand]` as an immutable stream; all renderers consume the same stream
- `CommandPlayer.play(commands:)` is a pure function shared by both renderers

**TortoiseUI**
- Sub-frame animation: the tortoise visibly walks as it draws, with position and heading interpolated between frames
- Three viewport modes: `.scaleToFit`, `.original`, `.autoFit(padding:)`

**TortoiseSVG** (new module)
- Export drawings as SVG string or file — no platform dependencies

**API additions**
- `dot(size:)`, `setX(_:)`, `setY(_:)`, `towards(x:y:)`, `distance(x:y:)`, `isFilling`
- `Size` and `Point` as first-class public types

**Breaking changes from v1**
- Renamed: `Vec2D` → `Point`, `Size2D` → `Size`, `Turtle`/`turtle` → `Tortoise`/`tortoise` throughout
- Removed: Python-style shorthand aliases (`fd`, `bk`, `rt`, `lt`, `pu`, `pd`, etc.)
- Requires Swift 6.2+ / Xcode 26+ / iOS 26+ · macOS 26+ · visionOS 26+
