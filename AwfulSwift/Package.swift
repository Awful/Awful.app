// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "AwfulSwift",
    products: [.library(name: "AwfulSwift", targets: ["AwfulSwift"])],
    targets: [.target(name: "AwfulSwift", dependencies: [])]
)
