// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "FoundationModelMac",
    platforms: [.macOS(.v27)],
    products: [
        .library(
            name: "FoundationModelMac",
            type: .dynamic,
            targets: ["FoundationModelMac"]
        ),
    ],
    targets: [
        .target(
            name: "FoundationModelMac"
        ),
    ]
)
