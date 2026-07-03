// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "rapid-mlx-swift",
    platforms: [
        .macOS(.v15),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "RapidMLX",
            targets: ["RapidMLX"]
        ),
    ],
    targets: [
        .target(
            name: "RapidMLX"
        ),
        .testTarget(
            name: "RapidMLXTests",
            dependencies: ["RapidMLX"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
