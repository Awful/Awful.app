// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ScannerShim",
    products: [
        .library(
            name: "ScannerShim",
            targets: ["ScannerShim"]),
    ],
    targets: [
        .target(
            name: "ScannerShim",
            dependencies: []),
    ]
)
