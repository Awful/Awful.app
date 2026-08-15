// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulTilt",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulTilt", targets: ["AwfulTilt"]),
    ],
    dependencies: [
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulSettings"),
        .package(path: "../AwfulTheming"),
    ],
    targets: [
        .target(
            name: "AwfulTilt",
            dependencies: [
                "AwfulExtensions",
                "AwfulSettings",
                "AwfulTheming",
            ]
        ),
    ]
)
