// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulSearch",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulSearch", targets: ["AwfulSearch"]),
    ],
    dependencies: [
        .package(path: "../AwfulCore"),
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulTheming"),
        .package(url: "https://github.com/nolanw/HTMLReader", .upToNextMajor(from: "2.1.7")),
    ],
    targets: [
        .target(
            name: "AwfulSearch",
            dependencies: [
                "AwfulCore",
                "AwfulExtensions",
                "AwfulTheming",
                "HTMLReader",
            ]
        ),
    ]
)
