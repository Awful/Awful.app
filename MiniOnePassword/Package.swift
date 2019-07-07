// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "MiniOnePassword",
    products: [
        .library(
            name: "MiniOnePassword",
            targets: ["MiniOnePassword"]),
    ],
    targets: [
        .target(
            name: "MiniOnePassword",
            dependencies: []),
    ]
)
