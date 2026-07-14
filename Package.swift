// swift-tools-version: 6.2
import PackageDescription

var products: [Product] = [
    .library(name: "TortoiseCore", targets: ["TortoiseCore"]),
    .library(name: "TortoiseSVG", targets: ["TortoiseSVG"]),
]

var targets: [Target] = [
    .target(name: "TortoiseCore"),
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
]

// TortoiseUI requires SwiftUI, which only exists on Apple platforms.
// This `#if` evaluates on the build host, so native Linux builds
// (e.g. the CI container) omit the UI product and targets entirely,
// letting plain `swift build` / `swift test` succeed there.
#if !os(Linux)
    products.append(.library(name: "TortoiseUI", targets: ["TortoiseUI"]))
    targets += [
        .target(
            name: "TortoiseUI",
            dependencies: ["TortoiseCore"]
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
#endif

let package = Package(
    name: "TortoiseGraphics",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26),
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0"),
    ],
    targets: targets
)
