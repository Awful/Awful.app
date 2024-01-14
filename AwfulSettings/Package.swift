// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwfulSettings",
    products: [
        .library(name: "AwfulSettings", targets: ["AwfulSettings"]),
        .plugin(name: "GenerateUserDefaultsExtension", targets: ["GenerateUserDefaultsExtension"]),
    ],
    targets: [
        .target(
            name: "AwfulSettings",
            resources: [.process("Settings.plist")],
            plugins: ["GenerateUserDefaultsExtension"]
        ),
        .testTarget(name: "AwfulSettingsTests", dependencies: ["AwfulSettings"]),
        .plugin(name: "GenerateUserDefaultsExtension", capability: .buildTool()),
    ]
)
