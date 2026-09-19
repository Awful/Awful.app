// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "ImgurAnonymousAPI",
    platforms: [
        .iOS(.v15),
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
