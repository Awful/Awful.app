// swift-tools-version: 5.9

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "AwfulSettings",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulSettings", targets: ["AwfulSettings"]),
    ],
    dependencies: [
        .package(path: "../SystemCapabilities"),
        .package(url: "http://github.com/jessesquires/Foil", from: "5.0.1"),
    ],
    targets: [
        .target(
            name: "AwfulSettings",
            dependencies: [
                "Foil",
                "SystemCapabilities",
            ],
            resources: [.process("Settings.plist")]
        ),
    ]
)
