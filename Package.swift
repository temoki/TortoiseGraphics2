// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TortoiseGraphics",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(name: "TortoiseCore", targets: ["TortoiseCore"]),
        .library(name: "TortoiseUI", targets: ["TortoiseUI"]),
        .library(name: "TortoiseSVG", targets: ["TortoiseSVG"]),
    ],
    targets: [
        .target(name: "TortoiseCore"),
        .target(
            name: "TortoiseUI",
            dependencies: ["TortoiseCore"]
        ),
        .target(
            name: "TortoiseSVG",
            dependencies: ["TortoiseCore"]
        ),
        .testTarget(
            name: "TortoiseCoreTests",
            dependencies: ["TortoiseCore"]
        ),
        .testTarget(
            name: "TortoiseSVGTests",
            dependencies: ["TortoiseSVG"]
        ),
    ]
)
