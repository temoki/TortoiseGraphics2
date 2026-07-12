# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build                                      # build all targets
swift test                                       # run all tests
swift test --filter TortoiseCore                 # run one test suite
swift test --filter "forward with pen down"      # run one test by name
swift package generate-documentation             # build DocC
```

## Architecture

**Event-sourcing pattern.** `Tortoise` accumulates `[TortoiseCommand]` (never mutates past state). Renderers are pure functions that consume the same stream:

```
Tortoise API → [TortoiseCommand] → CommandPlayer.play() → [PlaybackFrame]
                                                               ↓
                                               TortoiseUI  (animation)
                                               TortoiseSVG (SVG string)
```

**Module dependency rule:** `TortoiseCore` has no platform dependencies (Foundation only). `TortoiseUI` and `TortoiseSVG` both depend on `TortoiseCore` and never on each other.

## Key Design Decisions

**`@MainActor @Observable` on `Tortoise` and `CanvasModel`.** `Tortoise` is always created and used on the main actor. `CanvasModel` is internal to `TortoiseUI` and also main-actor-bound.

**`nonisolated static func` for arc math.** `Tortoise.arcCenter()` and `Tortoise.arcEndState()` are pure math helpers shared between `Tortoise` (main-actor) and `CommandPlayer` (non-isolated). They must stay `nonisolated static` — do not add state access to them.

**`@MainActor init` + `State(wrappedValue:)` in `TortoiseCanvas`.** This is an intentional violation of the swiftui_way.md rule against assigning `@State` in `init`. It's required so instant-mode programs are visible in static Xcode Previews (where `TimelineView` never fires). The known limitation: if the `Tortoise` *instance* is swapped for a new one with the same `commands.count`, the guard in `task(id:)` won't re-initialize the model.

**Sub-frame animation via `animationProgress`.** `CanvasModel` exposes `animationProgress: Double` (0→1) and `inProgressFrame: PlaybackFrame?`. `TortoiseCanvas` uses these to interpolate tortoise position/heading and draw partial strokes, so the tortoise visibly walks as it draws. Do not collapse this back to per-frame snapping.

**`isFillActive` on `PlaybackFrame`.** Added so SVG and other renderers can defer stroke emission until after `endFill`, placing the fill polygon below its outline strokes. `CommandPlayer` snapshots `fillPoints != nil` at the start of each command iteration to set this flag.

**`[DrawElement]` + `pendingFillElements` in `CanvasModel`.** Drawing elements are stored as a single ordered `[DrawElement]` list (not separate arrays per type) to preserve command-execution order. Strokes/dots emitted while `isFillActive` are buffered in `pendingFillElements`; on `endFill` the fill polygon is appended first, then the buffered elements are flushed on top — so the fill polygon always renders below its outline strokes regardless of command order.

**`DrawingBounds` computed at init.** `CanvasModel.drawingBounds` is an axis-aligned bounding box of all visible output across all frames, computed once in `init` (not per-tick). Arcs use the full-circle bounding box (center ± radius) — conservative but always correct, and avoids trigonometry over partial arc segments. `ViewportMode.autoFit` consumes this to scale and center the view; it falls back to `.scaleToFit` when `drawingBounds` is `nil` (no visible output). The `transform()` method signature takes `drawingBounds: DrawingBounds?` as a parameter so `TortoiseCanvas` passes the model's precomputed value.

**`backgroundColor` defaults to `.clear`.** `TortoiseCanvas` skips the background fill when `alpha == 0`, letting SwiftUI's `.background()` modifier control the canvas background. The SVG renderer likewise omits the `<rect>` element when the background is transparent.

## Coordinate System

- **Tortoise space**: center origin, Y-up, heading 0 = north, clockwise positive. Arc angles: 0 = east, CCW positive (standard math).
- **SVG / screen space**: top-left origin, Y-down.
- **Transform** (tortoise → SVG): `svg_x = w/2 + tortoise_x`, `svg_y = h/2 - tortoise_y`
- **Arc sweep-flag in SVG**: tortoise CCW (positive sweep) = CW in SVG (Y-flipped) = `sweep-flag 1`.

## Instant Mode

`isInstantMode(frames:)` in `CanvasModel` returns `true` if any frame with `tortoiseState.speed ≤ 0` appears before the first frame that produces visible output (stroke/arc/fill). When true, `CanvasModel.init` eagerly flushes all frames so static Xcode Previews show the full drawing.

## Testing

Tests live in `Tests/TortoiseCoreTests/` and `Tests/TortoiseSVGTests/`. `TortoiseUI` has no automated tests (GUI animation). Tests use swift-testing (`@Suite`, `@Test`, `#expect`). `Tortoise` is `@MainActor` so test suites that use it are marked `@MainActor`.

SVG tests avoid raw string literals (`#"..."#`) when the expected string contains `"#` (e.g. hex colors) — use regular strings with escaped quotes instead: `"fill=\"#ff0000\""`.
