// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Logger",
    products: [.library(name: "Logger", targets: ["Logger"])],
    targets: [.target(name: "Logger", dependencies: [])]
)
