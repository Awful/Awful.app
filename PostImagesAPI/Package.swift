// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PostImagesAPI",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "PostImagesAPI",
            targets: ["PostImagesAPI"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PostImagesAPI",
            dependencies: []),
        .testTarget(
            name: "PostImagesAPITests",
            dependencies: ["PostImagesAPI"]),
    ]
)