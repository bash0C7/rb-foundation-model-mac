// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "FoundationModelMac",
    platforms: [.macOS(.v12)],
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
