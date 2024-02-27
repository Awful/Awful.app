// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "AwfulExtensions",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [.library(name: "AwfulExtensions", targets: ["AwfulExtensions"])],
    targets: [
        .target(name: "AwfulExtensions"),
        .testTarget(name: "AwfulExtensionsTests", dependencies: ["AwfulExtensions"]),
    ]
)
