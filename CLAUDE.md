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

**Event-sourcing pattern.** `Tortoise` accumulates `[TurtleCommand]` (never mutates past state). Renderers are pure functions that consume the same stream:

```
Tortoise API → [TurtleCommand] → CommandPlayer.play() → [PlaybackFrame]
                                                               ↓
                                               TortoiseUI  (animation)
                                               TortoiseSVG (SVG string)
```

**Module dependency rule:** `TortoiseCore` has no platform dependencies (Foundation only). `TortoiseUI` and `TortoiseSVG` both depend on `TortoiseCore` and never on each other.

## Key Design Decisions

**`@MainActor @Observable` on `Tortoise` and `CanvasModel`.** `Tortoise` is always created and used on the main actor. `CanvasModel` is internal to `TortoiseUI` and also main-actor-bound.

**`nonisolated static func` for arc math.** `Tortoise.arcCenter()` and `Tortoise.arcEndState()` are pure math helpers shared between `Tortoise` (main-actor) and `CommandPlayer` (non-isolated). They must stay `nonisolated static` — do not add state access to them.

**`@MainActor init` + `State(wrappedValue:)` in `TortoiseCanvasView`.** This is an intentional violation of the swiftui_way.md rule against assigning `@State` in `init`. It's required so instant-mode programs are visible in static Xcode Previews (where `TimelineView` never fires). The known limitation: if the `Tortoise` *instance* is swapped for a new one with the same `commands.count`, the guard in `task(id:)` won't re-initialize the model.

**Sub-frame animation via `animationProgress`.** `CanvasModel` exposes `animationProgress: Double` (0→1) and `inProgressFrame: PlaybackFrame?`. `TortoiseCanvasView` uses these to interpolate turtle position/heading and draw partial strokes, so the turtle visibly walks as it draws. Do not collapse this back to per-frame snapping.

**`isFillActive` on `PlaybackFrame`.** Added so SVG and other renderers can defer stroke emission until after `endFill`, placing the fill polygon below its outline strokes. `CommandPlayer` snapshots `fillPoints != nil` at the start of each command iteration to set this flag.

## Coordinate System

- **Turtle space**: center origin, Y-up, heading 0 = north, clockwise positive. Arc angles: 0 = east, CCW positive (standard math).
- **SVG / screen space**: top-left origin, Y-down.
- **Transform** (turtle → SVG): `svg_x = w/2 + turtle_x`, `svg_y = h/2 - turtle_y`
- **Arc sweep-flag in SVG**: turtle CCW (positive sweep) = CW in SVG (Y-flipped) = `sweep-flag 1`.

## Instant Mode

`isInstantMode(frames:)` in `CanvasModel` returns `true` if any frame with `turtleState.speed ≤ 0` appears before the first frame that produces visible output (stroke/arc/fill). When true, `CanvasModel.init` eagerly flushes all frames so static Xcode Previews show the full drawing.

## Testing

Tests live in `Tests/TortoiseCoreTests/` and `Tests/TortoiseSVGTests/`. `TortoiseUI` has no automated tests (GUI animation). Tests use swift-testing (`@Suite`, `@Test`, `#expect`). `Tortoise` is `@MainActor` so test suites that use it are marked `@MainActor`.

SVG tests avoid raw string literals (`#"..."#`) when the expected string contains `"#` (e.g. hex colors) — use regular strings with escaped quotes instead: `"fill=\"#ff0000\""`.
