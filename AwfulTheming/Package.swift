// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulTheming",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulTheming", targets: ["AwfulTheming"]),
    ],
    dependencies: [
        .package(path: "../AwfulModelTypes"),
        .package(path: "../AwfulSettings"),
        .package(path: "../Logger"),
        .package(path: "../Vendor/PullToRefresh"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.0.0"),
        .package(url: "https://github.com/nolanw/HTMLReader", .upToNextMajor(from: "2.1.7")),
    ],
    targets: [
        .target(
            name: "AwfulTheming",
            dependencies: [
                "AwfulModelTypes",
                "AwfulSettings",
                "HTMLReader",
                "Logger",
                .product(name: "Lottie", package: "lottie-ios"),
                "PullToRefresh",
            ],
            resources: [
                .process("ForumTweaks.plist"),
                .process("Themes.plist"),
            ]
        ),
    ]
)
