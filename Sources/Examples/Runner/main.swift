import ExamplesGallery
import Foundation
import TortoiseSVG

// Regenerates docs/examples/*.svg — the README gallery images — from the
// example drawings in the sibling Gallery directory:
//
//     swift run ExamplesRunner
//
// Each example is a single file with a SwiftUI #Preview; open this package
// in Xcode to watch any of them draw themselves.

let outputDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // Sources/Examples/Runner/
    .deletingLastPathComponent()  // Sources/Examples/
    .deletingLastPathComponent()  // Sources/
    .deletingLastPathComponent()  // repository root
    .appending(path: "docs/examples")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for (file, draw) in Gallery.drawings {
    let 🐢 = Tortoise()
    draw(🐢)
    let url = outputDirectory.appending(path: "\(file).svg")
    try 🐢.svg().write(to: url, atomically: true, encoding: .utf8)
    print("wrote \(url.path)")
}
