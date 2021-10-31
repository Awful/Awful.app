// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ImgurAnonymousAPI",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "ImgurAnonymousAPI",
            targets: ["ImgurAnonymousAPI"]),
    ],
    targets: [
        .target(
            name: "ImgurAnonymousAPI",
            dependencies: []),
    ]
)
