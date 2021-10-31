// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "MRProgress",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "MRProgress",
            targets: ["MRProgress"]),
    ],
    targets: [
        .target(
            name: "MRProgress",
            dependencies: []),
    ]
)
