// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LinksmithCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LinksmithCore", targets: ["LinksmithCore"]),
    ],
    targets: [
        .target(name: "LinksmithCore"),
        .testTarget(name: "LinksmithCoreTests", dependencies: ["LinksmithCore"]),
    ]
)
