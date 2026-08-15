// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulPolls",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulPolls", targets: ["AwfulPolls"]),
    ],
    dependencies: [
        .package(path: "../AwfulCore"),
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulSettings"),
        .package(path: "../AwfulTheming"),
    ],
    targets: [
        .target(
            name: "AwfulPolls",
            dependencies: [
                "AwfulCore",
                "AwfulExtensions",
                "AwfulSettings",
                "AwfulTheming",
            ]
        ),
    ]
)
