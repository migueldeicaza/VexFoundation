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
    targets: [
        .target(
            name: "VexFoundation",
            resources: [
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "VexFoundationTests",
            dependencies: ["VexFoundation"]
        ),
    ]
)
