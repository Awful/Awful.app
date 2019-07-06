// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MiniOnePassword",
    products: [
        .library(
            name: "MiniOnePassword",
            targets: ["MiniOnePassword"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MiniOnePassword",
            dependencies: []),
    ]
)
