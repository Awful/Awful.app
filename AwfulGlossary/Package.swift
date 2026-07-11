// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulGlossary",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulGlossary", targets: ["AwfulGlossary"]),
    ],
    dependencies: [
        .package(path: "../AwfulCore"),
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulTheming"),
        .package(url: "https://github.com/nolanw/HTMLReader", .upToNextMajor(from: "2.1.7")),
    ],
    targets: [
        .target(
            name: "AwfulGlossary",
            dependencies: [
                "AwfulCore",
                "AwfulExtensions",
                "AwfulTheming",
                "HTMLReader",
            ]
        ),
    ]
)
