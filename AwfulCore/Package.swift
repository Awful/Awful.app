// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "AwfulCore",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "AwfulCore", targets: ["AwfulCore"]),
    ],
    dependencies: [
        .package(path: "../AwfulScraping"),
        .package(path: "../AwfulSwift"),
        .package(path: "../Logger"),
        .package(url: "https://github.com/nolanw/HTMLReader", .upToNextMajor(from: "2.1.7")),
    ],
    targets: [
        .target(
            name: "AwfulCore",
            dependencies: [
                "AwfulScraping",
                "AwfulSwift",
                "HTMLReader",
                "Logger",
            ],
            resources: [
                .process("Localizable.strings"),
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
