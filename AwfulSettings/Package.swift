// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulSettings",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulSettings", targets: ["AwfulSettings"]),
    ],
    dependencies: [
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulModelTypes"),
        .package(path: "../SystemCapabilities"),
        .package(url: "http://github.com/jessesquires/Foil", from: "5.0.1"),
        
    ],
    targets: [
        .target(
            name: "AwfulSettings",
            dependencies: [
                "AwfulExtensions",
                "AwfulModelTypes",
                "Foil",
                "SystemCapabilities",
            ]
        ),
    ]
)
