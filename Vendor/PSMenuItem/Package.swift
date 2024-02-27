// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "PSMenuItem",
    platforms: [.iOS(.v15)],
    products: [.library(name: "PSMenuItem", targets: ["PSMenuItem"])],
    targets: [
        .target(
            name: "PSMenuItem",
            publicHeadersPath: ""
        ),
    ]
)
