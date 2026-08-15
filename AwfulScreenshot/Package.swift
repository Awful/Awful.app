// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulScreenshot",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulScreenshot", targets: ["AwfulScreenshot"]),
    ],
    dependencies: [
        .package(path: "../AwfulCore"),
        .package(path: "../AwfulTheming"),
    ],
    targets: [
        .target(
            name: "AwfulScreenshot",
            dependencies: [
                "AwfulCore",
                "AwfulTheming",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
