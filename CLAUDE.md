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

**Linux support:** `TortoiseCore` and `TortoiseSVG` build and pass all tests on Linux — do not introduce Apple-only APIs into them (the CI `linux` job enforces this). `Package.swift` omits the SwiftUI-based `TortoiseUI` product and targets on Linux via `#if !os(Linux)` (a manifest `#if os()` evaluates on the build host), so plain `swift build` / `swift test` work there.

## Key Design Decisions

**`@MainActor @Observable` on `Tortoise` and `CanvasModel`.** `Tortoise` is always created and used on the main actor. `CanvasModel` is internal to `TortoiseUI` and also main-actor-bound.

**`nonisolated static func` for arc math.** `Tortoise.arcCenter()` and `Tortoise.arcEndState()` are pure math helpers shared between `Tortoise` (main-actor) and `CommandPlayer` (non-isolated). They must stay `nonisolated static` — do not add state access to them.

**`TortoiseState.applying(_:)` is the single state-transition reducer.** `Tortoise` applies each command as it records it (via its private `record(_:)`), and `CommandPlayer` replays streams through the same function — never reimplement position/heading/pen state math on either side. The player's switch only derives drawing output (strokes, fills, dots) from the before/after states. `StateConsistencyTests` guards this with a random-program comparison.

**`@MainActor init` + `State(wrappedValue:)` in `TortoiseCanvas`.** This is an intentional violation of the swiftui_way.md rule against assigning `@State` in `init`. It's required so instant-mode programs are visible in static Xcode Previews (where `TimelineView` never fires). The known limitation: if the `Tortoise` *instance* is swapped for a new one with the same `commands.count`, the guard in `task(id:)` won't re-initialize the model.

**Sub-frame animation via `animationProgress`.** `CanvasModel` exposes `animationProgress: Double` (0→1) and `inProgressFrame: PlaybackFrame?`. `TortoiseCanvas` uses these to interpolate tortoise position/heading and draw partial strokes, so the tortoise visibly walks as it draws. Do not collapse this back to per-frame snapping.

**`isFillActive` on `PlaybackFrame`.** Added so SVG and other renderers can defer stroke emission until after `endFill`, placing the fill polygon below its outline strokes. `CommandPlayer` snapshots `fillPoints != nil` at the start of each command iteration to set this flag.

**`[DrawElement]` + `fillInsertionIndex` in `CanvasModel`.** Drawing elements are stored as a single ordered `[DrawElement]` list (not separate arrays per type) to preserve command-execution order. Strokes/dots emitted while `isFillActive` are appended immediately (so they animate live during the fill); `fillInsertionIndex` records the `elements.count` at the moment the fill became active, and on `endFill` the fill polygon is `insert`ed at that index — so it renders below its outline strokes regardless of command order, without delaying those strokes' own appearance.

**`DrawingBounds` computed at init.** `CanvasModel.drawingBounds` is an axis-aligned bounding box of all visible output across all frames, computed once in `init` (not per-tick). Arcs use the full-circle bounding box (center ± radius) — conservative but always correct, and avoids trigonometry over partial arc segments. `ViewportMode.autoFit` consumes this to scale and center the view; it falls back to `.scaleToFit` when `drawingBounds` is `nil` (no visible output). The `transform()` method signature takes `drawingBounds: DrawingBounds?` as a parameter so `TortoiseCanvas` passes the model's precomputed value.

**`@_exported import TortoiseCore` in `TortoiseUI` and `TortoiseSVG`.** Users only write `import TortoiseUI` / `import TortoiseSVG` and still see all Core types. The underscored attribute has no stability guarantee from Swift; if a future toolchain breaks it, the fallback is to drop the re-export and require users to add `import TortoiseCore` themselves — a breaking change to document in the CHANGELOG, not something to work around with tricks.

**`backgroundColor` defaults to `.clear`.** `TortoiseCanvas` skips the background fill when `alpha == 0`, letting SwiftUI's `.background()` modifier control the canvas background. The SVG renderer likewise omits the `<rect>` element when the background is transparent.

## Coordinate System

- **Tortoise space**: center origin, Y-up, heading 0 = north, clockwise positive. Arc angles: 0 = east, CCW positive (standard math).
- **SVG / screen space**: top-left origin, Y-down.
- **Transform** (tortoise → SVG): `svg_x = w/2 + tortoise_x`, `svg_y = h/2 - tortoise_y`
- **Arc sweep-flag in SVG**: tortoise CCW (positive sweep) = CW in SVG (Y-flipped) = `sweep-flag 1`.

## Instant Mode

`isInstantMode(frames:)` in `CanvasModel` returns `true` if any frame with `tortoiseState.speed ≤ 0` appears before the first frame that produces visible output (stroke/arc/fill). When true, `CanvasModel.init` eagerly flushes all frames so static Xcode Previews show the full drawing.

## Testing

Tests live in `Tests/TortoiseCoreTests/`, `Tests/TortoiseSVGTests/`, and `Tests/TortoiseUITests/`. Tests use swift-testing (`@Suite`, `@Test`, `#expect`). `Tortoise` is `@MainActor` so test suites that use it are marked `@MainActor`.

SVG tests avoid raw string literals (`#"..."#`) when the expected string contains `"#` (e.g. hex colors) — use regular strings with escaped quotes instead: `"fill=\"#ff0000\""`.

**Drawing-scenario golden tests.** `Tests/TortoiseTestSupport/` (a non-product target) defines `DrawingScenario.all` — feature-grouped tortoise programs that together cover every `TortoiseCommand` case. Both renderers are verified against the same scenarios via pointfreeco/swift-snapshot-testing:

- `TortoiseSVGTests/DrawingScenarioSVGTests` compares full SVG strings against goldens in `Tests/TortoiseSVGTests/__Snapshots__/`.
- `TortoiseUITests/DrawingScenarioCanvasTests` (macOS-only, `#if os(macOS)`) renders `TortoiseCanvas` via `ImageRenderer` (`scale = 2`, instant mode forced by prepending `speed = 0`) and compares PNGs in `Tests/TortoiseUITests/__Snapshots__/` with `precision: 0.995, perceptualPrecision: 0.98` to absorb OS-level antialiasing drift.

After intentionally changing scenario programs or renderer output, re-record **both** golden sets in the same commit and visually inspect them:

```bash
SNAPSHOT_TESTING_RECORD=all swift test --filter DrawingScenario
```
