// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SystemCapabilities",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "SystemCapabilities", targets: ["SystemCapabilities"]),
    ],
    targets: [
        .target(name: "SystemCapabilities"),
    ]
)
