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
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0"),
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
        .target(
            name: "TortoiseTestSupport",
            dependencies: ["TortoiseCore"],
            path: "Tests/TortoiseTestSupport"
        ),
        .testTarget(
            name: "TortoiseCoreTests",
            dependencies: ["TortoiseCore"]
        ),
        .testTarget(
            name: "TortoiseSVGTests",
            dependencies: [
                "TortoiseSVG",
                "TortoiseTestSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "TortoiseUITests",
            dependencies: [
                "TortoiseUI",
                "TortoiseTestSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
