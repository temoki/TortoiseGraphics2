# Contributing to TortoiseGraphics2

Thank you for your interest in improving TortoiseGraphics2! Bug reports, feature
requests, documentation fixes, and pull requests are all welcome.

## Requirements

- **Swift** 6.2+ / **Xcode** 26+
- **macOS** to run the full test suite — the golden image tests in
  `TortoiseUITests` render a SwiftUI view and are macOS-only.

## Building and testing

```bash
swift build                                      # build all targets
swift test                                       # run all tests
swift test --filter TortoiseCore                 # run one test suite
swift test --filter "forward with pen down"      # run a single test by name
swift package generate-documentation             # build the DocC documentation
```

Tests use [swift-testing](https://github.com/swiftlang/swift-testing)
(`@Suite`, `@Test`, `#expect`) — not XCTest. `Tortoise` is `@MainActor`, so
test suites that use it are annotated `@MainActor`.

## Code style

Formatting is enforced by `swift-format` in CI; the `.swift-format` file at the
repository root is the source of truth.

```bash
# What CI runs — must pass:
xcrun swift-format lint --recursive --strict Sources Tests

# Auto-format your changes:
xcrun swift-format format --in-place --recursive Sources Tests
```

## Architecture ground rules

The design follows an **event-sourcing pattern**: `Tortoise` accumulates
`[TortoiseCommand]` (it never mutates past state), and renderers are pure
functions that replay the same stream via `CommandPlayer.play()`.

- `TortoiseCore` must stay free of platform dependencies (Foundation and
  Observation only — no SwiftUI, no CoreGraphics).
- `TortoiseUI` and `TortoiseSVG` both depend on `TortoiseCore` and never on
  each other.
- Key design decisions (main-actor rules, sub-frame animation, fill ordering,
  and more) are documented in [CLAUDE.md](CLAUDE.md) — a useful read for human
  contributors too, not just AI assistants.

## Golden snapshot tests

Both renderers are verified against the same drawing scenarios
(`Tests/TortoiseTestSupport/DrawingScenarios.swift`), which together cover
every `TortoiseCommand` case:

- **SVG strings** — `Tests/TortoiseSVGTests/__Snapshots__/`
- **Canvas PNGs** (macOS-only) — `Tests/TortoiseUITests/__Snapshots__/`

Rules:

- Never edit files under `__Snapshots__/` by hand.
- If you intentionally change renderer output or scenario programs, re-record
  **both** golden sets in the same commit and visually inspect the results:

  ```bash
  SNAPSHOT_TESTING_RECORD=all swift test --filter DrawingScenario
  ```

- If you add or change a `TortoiseCommand` — or anything else that affects
  visible output — add or update a scenario so both renderers stay covered.

The PNG goldens depend on OS-level rendering. The current set was recorded on
**macOS 26** (Xcode 26); CI compares them on `macos-15` runners, with a small
tolerance (`precision: 0.995`, `perceptualPrecision: 0.98`) absorbing
antialiasing drift between OS versions. If a PR bumps the CI runner image
(`runs-on: macos-XX`) or you re-record on a different macOS version, confirm
the PNG golden tests still pass in CI — and if they don't, re-record both
golden sets and visually inspect them as described above.

## Submitting a pull request

1. Fork the repository and create a branch from `main`.
2. Make your change, including tests for new behavior.
3. Verify locally that `swift test` and the swift-format lint pass.
4. Add a `CHANGELOG.md` entry for user-visible changes.
5. Open a pull request against `main`. CI must pass: tests on macOS and
   Linux, a release-mode build, and the format lint.

Please keep each pull request focused on a single topic — small PRs are
reviewed faster.

## Reporting bugs and requesting features

Please use the issue templates. For bugs, a minimal tortoise program that
reproduces the problem helps enormously.

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
