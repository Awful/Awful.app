// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "AwfulScraping",
    products: [
        .library(
            name: "AwfulScraping",
            targets: ["AwfulScraping"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nolanw/HTMLReader", from: "2.1.8"),
    ],
    targets: [
        .target(
            name: "AwfulScraping",
            dependencies: ["HTMLReader"]),
        .testTarget(
            name: "AwfulScrapingTests",
            dependencies: ["AwfulScraping"]),
    ]
)
