# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build                                      # build all targets
swift test                                       # run all tests
swift test --filter TortoiseCore                 # run one test suite
swift test --filter "forward with pen down"      # run one test by name
swift package generate-documentation             # build DocC
swift run ExamplesRunner                         # regenerate docs/examples/*.svg (README gallery)

xcrun swift-format lint --recursive --strict Sources Tests    # what CI enforces
xcrun swift-format format --in-place --recursive Sources Tests
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

**Examples target layout is load-bearing (#31).** The gallery drawings live in the `ExamplesGallery` *library* target at `Sources/Examples/Gallery/`, with `ExamplesRunner` (executable, `Sources/Examples/Runner/`) regenerating `docs/examples/*.svg` from the same code. Do not fold the drawings back into the executable or move them out of `Sources/`: Xcode refuses to preview executable targets without `ENABLE_DEBUG_DYLIB`, which SwiftPM cannot set, and both targets must stay exposed as products for previews to work. `Gallery.drawings` lists the examples in README order — add new examples there too, or the runner won't emit their SVG.

## Key Design Decisions

**`@MainActor @Observable` on `Tortoise` and `CanvasModel`.** `Tortoise` is always created and used on the main actor. `CanvasModel` is internal to `TortoiseUI` and also main-actor-bound.

**`nonisolated static func` for arc math.** `Tortoise.arcCenter()` and `Tortoise.arcEndState()` are pure math helpers shared between `Tortoise` (main-actor) and `CommandPlayer` (non-isolated). They must stay `nonisolated static` — do not add state access to them.

**`TortoiseState.applying(_:)` is the single state-transition reducer.** `Tortoise` applies each command as it records it (via its private `record(_:)`), and `CommandPlayer` replays streams through the same function — never reimplement position/heading/pen state math on either side. The player's switch only derives drawing output (strokes, fills, dots) from the before/after states. `StateConsistencyTests` guards this with a random-program comparison.

**`@MainActor init` + `State(wrappedValue:)` in `TortoiseCanvas`.** This is an intentional violation of the swiftui_way.md rule against assigning `@State` in `init`. It's required so instant-mode programs are visible in static Xcode Previews (where `TimelineView` never fires).

**`TortoiseChangeKey` (instance identity + `Tortoise.mutationCount`) is the change-detection key.** `TortoiseCanvas` watches `task(id: TortoiseChangeKey(tortoise))` — not `commands.count` — because `reset()` followed by re-recording the same number of commands leaves the count unchanged, and swapping in a different `Tortoise` instance can leave even `mutationCount` unchanged; the composite key catches both. The counter (package-level, no public API) increments on every `record(_:)` and on `reset()`; `CanvasModel.sourceKey` remembers what the model was built from so the guard can skip the initial task firing.

**Sub-frame animation via `animationProgress`.** `CanvasModel` exposes `animationProgress: Double` (0→1) and `inProgressFrame: PlaybackFrame?`. `TortoiseCanvas` uses these to interpolate tortoise position/heading and draw partial strokes, so the tortoise visibly walks as it draws. Do not collapse this back to per-frame snapping.

**Two-layer rendering in `TortoiseCanvas` (#35).** Committed elements draw in `CommittedLayer`, a `Canvas` *outside* the `TimelineView`; only the in-progress stroke/arc and the tortoise sprite (`AnimationLayer`) render at display refresh rate. Do not move committed-element drawing back inside the `TimelineView` — that is O(elements) Path-building per display frame and stutters at a few hundred commands. `CommittedLayer` reads `model.elements` / `backgroundColor` during *body* evaluation (snapshotted into the Canvas closure) so Observation invalidates it exactly on frame commits and step/seek/clear — keep those reads at body level rather than relying on tracking inside the Canvas rendering closure. Drawing primitives shared by both layers live in `CanvasRenderer`.

**Stroke batching in `CanvasRenderer.drawElements` (#37).** A maximal run of consecutive `.stroke` elements sharing `color` and `width` is merged into one multi-subpath `Path` and drawn with a single `ctx.stroke` — the per-element `Path` + draw-call overhead (~0.37µs) dominates committed-layer redraw, not rasterization, so this is ~6× at 10,000 strokes. Round caps apply per subpath, so the output is unchanged. Two invariants to preserve: **translucent strokes (`color.alpha < 1`) must not be batched** — overlapping segments have to blend once per stroke to match the SVG renderer's one `<line>` per stroke (`translucentOverlaps` scenario guards this) — and **`.fill` / `.arcStroke` / `.dot` are never batched**, so element order and z-order (and therefore `fillInsertionIndex`) are untouched. Batching does change antialiasing where strokes overlap (one rasterization instead of two blends), which is why the canvas goldens were re-recorded.

**`isFillActive` on `PlaybackFrame`.** Added so SVG and other renderers can defer stroke emission until after `endFill`, placing the fill polygon below its outline strokes. `CommandPlayer` snapshots `fillPoints != nil` at the start of each command iteration to set this flag.

**`[DrawElement]` + `fillInsertionIndex` in `CanvasModel`.** Drawing elements are stored as a single ordered `[DrawElement]` list (not separate arrays per type) to preserve command-execution order. Strokes/dots emitted while `isFillActive` are appended immediately (so they animate live during the fill); `fillInsertionIndex` records the `elements.count` at the moment the fill became active, and on `endFill` the fill polygon is `insert`ed at that index — so it renders below its outline strokes regardless of command order, without delaying those strokes' own appearance.

**`DrawingBounds` computed at init.** `CanvasModel.drawingBounds` is an axis-aligned bounding box of all visible output across all frames, computed once in `init` (not per-tick). Arcs use the full-circle bounding box (center ± radius) — conservative but always correct, and avoids trigonometry over partial arc segments. `ViewportMode.autoFit` consumes this to scale and center the view; it falls back to `.scaleToFit` when `drawingBounds` is `nil` (no visible output). The `transform()` method signature takes `drawingBounds: DrawingBounds?` as a parameter so `TortoiseCanvas` passes the model's precomputed value. `DrawingBounds` lives in `TortoiseCore` (not `TortoiseUI`) because `TortoiseSVG` consumes the same computation for `render(_:fit:)` / `svg(fit:)`, which crop the `viewBox` to the drawing (default `fit: true`); `fit: false` keeps the full logical `canvasSize`.

**Hand-written `Codable` with a frozen wire format.** `Codable.swift` implements every conformance manually with explicit coding keys — do not replace it with synthesized conformances, and do not rename a key to match a refactored Swift identifier. The JSON format is **frozen for the 2.x series** (documented in `Sources/TortoiseCore/Documentation.docc/CommandSerialization.md`, which must be updated alongside any format change), because command streams are meant to be persisted as app documents and golden files. A command encodes as an object with exactly one key, the command name; decoding rejects zero keys, several keys, or an unknown key, while unknown fields *inside* a payload are ignored so payloads can grow compatibly. Adding a new `TortoiseCommand` case is backward compatible (old data still decodes); changing or removing an existing key is not.

**`@_exported import TortoiseCore` in `TortoiseUI` and `TortoiseSVG`.** Users only write `import TortoiseUI` / `import TortoiseSVG` and still see all Core types. The underscored attribute has no stability guarantee from Swift; if a future toolchain breaks it, the fallback is to drop the re-export and require users to add `import TortoiseCore` themselves — a breaking change to document in the CHANGELOG, not something to work around with tricks.

**`backgroundColor` defaults to `.clear`.** `TortoiseCanvas` skips the background fill when `alpha == 0`, letting SwiftUI's `.background()` modifier control the canvas background. The SVG renderer likewise omits the `<rect>` element when the background is transparent.

**`TortoiseSprite` is a TortoiseUI-only concept.** The sprite (built-in triangle or a user `Image`) is chosen through the `\.tortoiseSprite` environment value, like `\.tortoiseViewport` — it is *not* a `TortoiseCommand`, so it never enters the serialized stream and `TortoiseSVG` is unaffected (SVG output has never drawn the tortoise). Both canvas layers read the environment value even though only `AnimationLayer` draws the sprite: `ViewportMode.autoFit`'s edge inset is `TortoiseSprite.halfExtent * tortoiseScaleMax`, and the two layers must derive the identical transform. `halfExtent` is the sprite's half-*diagonal* so the inset holds at every heading. Image sprites are aspect-fitted into `size` (`ctx.resolve` gives the intrinsic size; a `ResolvedImage` is bound to its context, so this cannot be hoisted out of the per-frame draw).

## Coordinate System

- **Tortoise space**: center origin, Y-up, heading 0 = north, clockwise positive. Arc angles: 0 = east, CCW positive (standard math).
- **SVG / screen space**: top-left origin, Y-down.
- **Transform** (tortoise → SVG): `svg_x = w/2 + tortoise_x`, `svg_y = h/2 - tortoise_y`
- **Arc sweep-flag in SVG**: tortoise CCW (positive sweep) = CW in SVG (Y-flipped) = `sweep-flag 1`.

## Instant Mode

`isInstantMode(frames:)` in `CanvasModel` returns `true` if any frame with `tortoiseState.speed ≤ 0` appears before the first frame that produces visible output (stroke/arc/fill). When true, `CanvasModel.init` eagerly flushes all frames so static Xcode Previews show the full drawing.

## Testing

Tests live in `Tests/TortoiseCoreTests/`, `Tests/TortoiseSVGTests/`, and `Tests/TortoiseUITests/`. Tests use swift-testing (`@Suite`, `@Test`, `#expect`). `Tortoise` is `@MainActor` so test suites that use it are marked `@MainActor`.

`CodableTests.swift` pins the JSON wire format with literal expected strings — a failure there means the persisted format changed, which is a breaking change, not a test to re-baseline.

SVG tests avoid raw string literals (`#"..."#`) when the expected string contains `"#` (e.g. hex colors) — use regular strings with escaped quotes instead: `"fill=\"#ff0000\""`.

**Drawing-scenario golden tests.** `Tests/TortoiseTestSupport/` (a non-product target) defines `DrawingScenario.all` — feature-grouped tortoise programs that together cover every `TortoiseCommand` case. Both renderers are verified against the same scenarios via pointfreeco/swift-snapshot-testing:

- `TortoiseSVGTests/DrawingScenarioSVGTests` compares full SVG strings against goldens in `Tests/TortoiseSVGTests/__Snapshots__/`.
- `TortoiseUITests/DrawingScenarioCanvasTests` (macOS-only, `#if os(macOS)`) renders `TortoiseCanvas` via `ImageRenderer` (`scale = 2`, instant mode forced by prepending `speed = 0`) and compares PNGs in `Tests/TortoiseUITests/__Snapshots__/` with `precision: 0.995, perceptualPrecision: 0.98` to absorb OS-level antialiasing drift.

After intentionally changing scenario programs or renderer output, re-record **both** golden sets in the same commit and visually inspect them:

```bash
SNAPSHOT_TESTING_RECORD=all swift test --filter DrawingScenario
```
