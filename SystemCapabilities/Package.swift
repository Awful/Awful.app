// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SystemCapabilities",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "SystemCapabilities", targets: ["SystemCapabilities"]),
    ],
    dependencies: [.package(path: "../Logger")],
    targets: [
        .target(name: "SystemCapabilities", dependencies: ["Logger"]),
    ]
)
