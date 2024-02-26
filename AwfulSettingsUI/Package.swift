// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulSettingsUI",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulSettingsUI", targets: ["AwfulSettingsUI"]),
    ],
    dependencies: [
        .package(path: "../AwfulCore"),
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulSettings"),
        .package(path: "../AwfulTheming"),
        .package(url: "https://github.com/kean/Nuke", from: "12.1.6"),
    ],
    targets: [
        .target(
            name: "AwfulSettingsUI",
            dependencies: [
                "AwfulCore",
                "AwfulExtensions",
                "AwfulSettings",
                "AwfulTheming",
                .product(name: "NukeUI", package: "Nuke"),
            ]
        ),
    ]
)
