// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "AwfulCore",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(name: "AwfulCore", targets: ["AwfulCore"]),
    ],
    dependencies: [
        .package(path: "../AwfulScraping"),
        .package(path: "../AwfulSwift"),
        .package(path: "../Logger"),
        .package(url: "https://github.com/mxcl/PromiseKit", .upToNextMajor(from: "6.0.0")),
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
                "PromiseKit",
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
