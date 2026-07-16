# Command Serialization

Persist command streams as JSON with a frozen, documented wire format.

## Overview

``TortoiseCommand``, ``Color``, ``Point``, and ``Size`` conform to `Codable`.
A recorded drawing — ``Tortoise/commands`` — can be saved with `JSONEncoder`
and replayed later with any renderer:

```swift
// Save
let data = try JSONEncoder().encode(🐢.commands)

// Load and re-render (canvas, SVG, or a custom renderer)
let commands = try JSONDecoder().decode([TortoiseCommand].self, from: data)
let frames = CommandPlayer.play(commands: commands)
```

This is designed for long-term storage: app documents, test fixtures, and
golden files. For example, an app can persist the evaluated command stream
of a program that uses randomness, so that reopening the document shows
exactly the drawing that was exported.

## Wire format

All conformances are hand-written with explicit coding keys — the format is
decoupled from Swift identifier names, so refactoring the library can never
change serialized data.

A command encodes as a JSON object with exactly one key, the command name:

| Command | JSON |
| --- | --- |
| `forward(100)` | `{"forward":{"distance":100}}` |
| `rotate(-45.5)` | `{"rotate":{"degrees":-45.5}}` |
| `home` | `{"home":{}}` |
| `setPosition(Point(x: 10, y: 20))` | `{"setPosition":{"x":10,"y":20}}` |
| `setHeading(270)` | `{"setHeading":{"degrees":270}}` |
| `penDown` / `penUp` | `{"penDown":{}}` / `{"penUp":{}}` |
| `penColor(.red)` | `{"penColor":{"red":1,"green":0,"blue":0,"alpha":1}}` |
| `penWidth(3)` | `{"penWidth":{"width":3}}` |
| `fillColor(.cyan)` | `{"fillColor":{"red":0,"green":1,"blue":1,"alpha":1}}` |
| `beginFill` / `endFill` | `{"beginFill":{}}` / `{"endFill":{}}` |
| `showTortoise` / `hideTortoise` | `{"showTortoise":{}}` / `{"hideTortoise":{}}` |
| `speed(0)` | `{"speed":{"value":0}}` |
| `backgroundColor(.black)` | `{"backgroundColor":{"red":0,"green":0,"blue":0,"alpha":1}}` |
| `clear` | `{"clear":{}}` |
| `circle(radius: -50, extent: 180)` | `{"arc":{"radius":-50,"extent":180}}` |
| `dot(8)` | `{"dot":{"size":8}}` |

On decode, a command object must contain **exactly one key, and it must be
a known command name** — anything else (no keys, several keys, an unknown
key, or an unknown key alongside a known one) fails with
`DecodingError.dataCorrupted`. Unrecognized fields *inside* a command's
payload are ignored, which is what lets later library versions extend a
payload without breaking older data.

Value types encode as plain objects:

- ``Point`` — `{"x":10,"y":20}`
- ``Size`` — `{"width":400,"height":400}`
- ``Color`` — `{"red":1,"green":0.5,"blue":0,"alpha":1}`. On decode, `alpha`
  may be omitted (it defaults to 1) and every component is clamped to 0…1,
  matching ``Color/init(red:green:blue:alpha:)``.

## Stability guarantee

- **Keys and structure are frozen for the 2.x release series.** Data written
  by any 2.x version decodes in every later 2.x version.
- **New command cases may be added in minor releases.** That is backward
  compatible: old data always decodes on newer library versions. The reverse
  is not guaranteed — a stream containing a command unknown to an older
  library version fails to decode there with `DecodingError`.
- Key *order* in encoder output is up to your encoder configuration; use
  `JSONEncoder.OutputFormatting.sortedKeys` where byte-identical output
  matters (for example, golden files).
