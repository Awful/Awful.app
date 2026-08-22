// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulRapsheet",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulRapsheet", targets: ["AwfulRapsheet"]),
    ],
    dependencies: [
        .package(path: "../AwfulCore"),
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulSettings"),
        .package(path: "../AwfulTheming"),
        .package(path: "../ScrollViewDelegateMultiplexer"),
    ],
    targets: [
        .target(
            name: "AwfulRapsheet",
            dependencies: [
                "AwfulCore",
                "AwfulExtensions",
                "AwfulSettings",
                "AwfulTheming",
                "ScrollViewDelegateMultiplexer",
            ]
        ),
    ]
)
