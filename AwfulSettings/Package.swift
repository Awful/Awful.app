// swift-tools-version: 5.9

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "AwfulSettings",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AwfulSettings", targets: ["AwfulSettings"]),
        .library(name: "AwfulSettingsUI", targets: ["AwfulSettingsUI"]),
    ],
    dependencies: [
        .package(path: "../AwfulExtensions"),
        .package(path: "../AwfulModelTypes"),
        .package(path: "../SystemCapabilities"),
        .package(url: "http://github.com/jessesquires/Foil", from: "5.0.1"),
        .package(url: "https://github.com/kean/Nuke", from: "12.1.6"),
    ],
    targets: [
        .target(
            name: "AwfulSettings",
            dependencies: [
                "AwfulExtensions",
                "AwfulModelTypes",
                "Foil",
                "SystemCapabilities",
            ],
            resources: [.process("Settings.plist")]
        ),
        .target(
            name: "AwfulSettingsUI",
            dependencies: [
                "AwfulExtensions",
                "AwfulSettings",
                .product(name: "NukeUI", package: "Nuke"),
            ]
        ),
    ]
)
