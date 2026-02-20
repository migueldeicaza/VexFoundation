// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VexFoundation",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "VexFoundation",
            targets: ["VexFoundation"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "VexFoundation",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "VexFoundationTests",
            dependencies: ["VexFoundation"]
        ),
    ]
)
