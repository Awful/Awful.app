// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulArchives",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulArchives", targets: ["AwfulArchives"]),
    ],
    dependencies: [
        .package(path: "../AwfulCore"),
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulTheming"),
    ],
    targets: [
        .target(
            name: "AwfulArchives",
            dependencies: [
                "AwfulCore",
                "AwfulExtensions",
                "AwfulTheming",
            ]
        ),
    ]
)
