// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "AwfulCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "AwfulCore", targets: ["AwfulCore"]),
    ],
    dependencies: [
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulModelTypes"),
        .package(path: "../AwfulScraping"),
        .package(url: "https://github.com/nolanw/HTMLReader", .upToNextMajor(from: "2.1.7")),
    ],
    targets: [
        .target(
            name: "AwfulCore",
            dependencies: [
                "AwfulExtensions",
                "AwfulModelTypes",
                "AwfulScraping",
                "HTMLReader",
            ]
        ),
        .testTarget(
            name: "AwfulCoreTests",
            dependencies: ["AwfulCore"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
