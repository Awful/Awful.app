// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "AwfulScraping",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "AwfulScraping",
            targets: ["AwfulScraping"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nolanw/HTMLReader", .upToNextMajor(from: "2.1.7")),
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
