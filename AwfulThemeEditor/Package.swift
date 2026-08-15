// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulThemeEditor",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulThemeEditor", targets: ["AwfulThemeEditor"]),
    ],
    dependencies: [
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulTheming"),
    ],
    targets: [
        .target(
            name: "AwfulThemeEditor",
            dependencies: [
                "AwfulExtensions",
                "AwfulTheming",
            ]
        ),
    ]
)
