// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Smilies",
    platforms: [.iOS(.v9)],
    products: [
        .library(
            name: "Smilies",
            targets: ["Smilies"]),
        .library(
            name: "WebArchive",
            targets: ["WebArchive"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Flipboard/FLAnimatedImage", .upToNextMajor(from: "1.0.16")),
        .package(url: "https://github.com/nolanw/HTMLReader", .upToNextMajor(from: "2.1.4")),
    ],
    targets: [
        .target(
            name: "Smilies",
            dependencies: [
                "FLAnimatedImage",
                "HTMLReader",
            ],
            resources: [
                .copy("Resources/Smilies.sqlite"),
            ],
            publicHeadersPath: "Headers"),
        .testTarget(
            name: "SmiliesTests",
            dependencies: [
                "Smilies",
                "WebArchive",
            ],
            resources: [
                .copy("showsmilies.webarchive"),
            ]),
        .target(
            name: "WebArchive",
            publicHeadersPath: "Headers"),
    ]
)
