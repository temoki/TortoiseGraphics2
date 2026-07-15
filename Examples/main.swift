import Foundation
import TortoiseSVG

// Regenerates docs/examples/*.svg — the README gallery images — from the
// example drawings in this directory:
//
//     swift run Examples
//
// Each example is a single file with a SwiftUI #Preview; open this package
// in Xcode to watch any of them draw themselves.

let gallery: [(file: String, draw: @MainActor (Tortoise) -> Void)] = [
    ("square-spiral", SquareSpiral.draw),
    ("fractal-tree", FractalTree.draw),
    ("koch-snowflake", KochSnowflake.draw),
    ("circle-rosette", CircleRosette.draw),
    ("filled-star", FilledStar.draw),
    ("waves", Waves.draw),
]

let outputDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // Examples/
    .deletingLastPathComponent()  // repository root
    .appending(path: "docs/examples")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for (file, draw) in gallery {
    let 🐢 = Tortoise()
    draw(🐢)
    let url = outputDirectory.appending(path: "\(file).svg")
    try 🐢.svg().write(to: url, atomically: true, encoding: .utf8)
    print("wrote \(url.path)")
}
