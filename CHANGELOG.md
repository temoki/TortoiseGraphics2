# Changelog

## Unreleased

### Added
- Code coverage measurement in CI: the macOS test job now runs with `--enable-code-coverage`, exports lcov, and uploads to [Codecov](https://codecov.io/gh/temoki/TortoiseGraphics2); coverage badge added to README
- Linux support for `TortoiseCore` and `TortoiseSVG`, verified by a new CI job (`swift:6.2` container) — the package manifest omits the SwiftUI-based `TortoiseUI` product and targets on Linux, so plain `swift build` / `swift test` work there out of the box
- `TortoiseState.applying(_:)` — a pure state-transition reducer, now the single source of truth shared by `Tortoise` (recording) and `CommandPlayer` (replay). This removes the duplicated state math that could silently drift apart, and is also useful for custom renderers doing incremental replay
- Community documents: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), GitHub issue forms (bug report / feature request), and a pull request template

### Changed
- CI hardening: Xcode selection no longer pins a single point release (it picks the newest stable Xcode 26.x on the runner image), SwiftPM build directories are cached across runs, and release-mode compilation moved to its own parallel job so the test job no longer builds everything twice
- `Tortoise.heading` and `TortoiseState.heading` are now always normalized to [0, 360), matching `towards()` and Python turtle — previously counterclockwise turns reported negative values (e.g. `left(90)` from north returned `-90`; it now returns `270`)

### Fixed
- `circle(radius:extent:)` with a negative radius produced mathematically inconsistent results — the end position landed on the wrong side of the circle (a zero-extent arc even teleported the tortoise to the opposite side). It now matches Python turtle: the center sits to the tortoise's right and the sweep and turn directions flip, so the arc bends the other way
- `clear()` while a fill is in progress now discards the in-progress fill (matching Python turtle): previously the pre-clear vertices leaked into the polygon completed by a later `endFill()`, resurrecting erased geometry — `isFilling` now also becomes `false` after `clear()`, and a fill started after a discarded one renders at the correct z-order in `TortoiseCanvas`
- `TortoiseCanvas`: the `TimelineView(.animation)` schedule kept firing at display refresh rate after playback finished, redrawing an unchanged canvas and wasting CPU/battery — the schedule is now paused once playback completes, and resumes when new commands re-create the playback model
- README: the installation snippet pointed at the v1 repository URL (`temoki/TortoiseGraphics`) and used `from: "2.0.0"`, which cannot resolve prerelease tags — it now points at this repository, uses a prerelease-aware `from: "2.0.0-beta1"` requirement, and includes the required `platforms` declaration

### Removed
- `Angle` type from `TortoiseCore` — no API accepted or returned it; all angles in the public API are plain `Double` degrees

## 2.0.0-beta5

### Added
- Comprehensive drawing-command golden tests: shared `DrawingScenario` fixtures (13 scenarios) covering every `TortoiseCommand` case, verified against checked-in goldens via swift-snapshot-testing — full-string SVG comparison in `TortoiseSVGTests`, and `TortoiseCanvas` PNG snapshots rendered with `ImageRenderer` in the new `TortoiseUITests` target (macOS)

### Fixed
- `TortoiseCanvas`: strokes drawn between `beginFill()` and `endFill()` were invisible during animation and only appeared all at once when the fill completed. `CanvasModel` now appends them live and tracks where to insert the fill polygon afterward, instead of buffering the strokes until `endFill`.

## 2.0.0-beta4

### Added
- Documentation site published to GitHub Pages (`.github/workflows/docs.yml`), triggered on version-tag pushes — combines the `TortoiseCore`, `TortoiseUI`, and `TortoiseSVG` DocC catalogs into a single browsable site
- `swift-docc-plugin` package dependency, so `swift package generate-documentation` (already referenced in `CLAUDE.md`) actually works
- Documentation badge in README linking to the published site

## 2.0.0-beta3

### Added
- Animated GIF (`docs/animated-square.gif`) added to README for the SwiftUI animated view section
- `TortoiseCanvas` closure init: describe the drawing inline without creating a `Tortoise` instance
- `.tortoiseViewport(_:)` environment modifier to set `ViewportMode` from outside the view
- SVG autoFit: `TortoiseSVG.render(_:fit:)` and `Tortoise.svg(fit:)` crop the `viewBox` to the actual drawing bounding box (default `fit: true`)
- `DrawingBounds` moved to `TortoiseCore` (public) — shared between `TortoiseUI` and `TortoiseSVG`
- Tortoise Star SVG (`docs/tortoise-star.svg`) added to README

### Changed
- `TortoiseCanvasView` renamed to `TortoiseCanvas` (matches SwiftUI `Canvas` naming)
- `TortoiseCanvas` default background is now `.clear`; use SwiftUI's `.background()` modifier instead
- `ViewportMode.autoFit` no longer takes a `padding:` parameter; use SwiftUI's `.padding()` instead
- Default viewport mode changed from `.scaleToFit` to `.autoFit`
- `TortoiseUI` and `TortoiseSVG` re-export `TortoiseCore` via `@_exported import` — no need to import `TortoiseCore` separately
- TortoiseSVG public API redesigned to be Tortoise-centric: `TortoiseSVG.render(_ tortoise:)` and `Tortoise.svg()` replace the old `render(commands:canvasSize:)` and `write(commands:canvasSize:to:)`

### Removed
- `TortoiseSVG.write(commands:canvasSize:to:)` — use `String.write(to:atomically:encoding:)` on the result of `svg()` instead
- `ViewportMode.autoFit(padding:)` parameter

## 2.0.0-beta2

### Fixed
- CI: use `xcrun swift-format` instead of `swift-format` to resolve command not found error
- README: fix link text "tortoise graphics" → "turtle graphics"

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
