// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "PullToRefresh",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "PullToRefresh",
            targets: ["PullToRefresh"]),
    ],
    targets: [
        .target(
            name: "PullToRefresh"),
    ]
)
