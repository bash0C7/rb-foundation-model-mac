// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "FoundationModelMac",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "FoundationModelMac", type: .dynamic, targets: ["FoundationModelMac"])
    ],
    targets: [
        .target(name: "FoundationModelMac", path: "Sources/FoundationModelMac")
    ]
)
