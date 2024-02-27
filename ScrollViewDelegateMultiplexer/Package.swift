// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScrollViewDelegateMultiplexer",
    products: [
        .library(name: "ScrollViewDelegateMultiplexer", targets: ["ScrollViewDelegateMultiplexer"]),
    ],
    targets: [
        .target(
            name: "ScrollViewDelegateMultiplexer",
            publicHeadersPath: ""
        ),
    ]
)
