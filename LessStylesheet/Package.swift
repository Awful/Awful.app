// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LessStylesheet",
    products: [
        .executable(name: "lessc", targets: ["lessc"]),
        .plugin(name: "LessStylesheet", targets: ["LessStylesheet"]),
    ],
    targets: [
        .executableTarget(
            name: "lessc",
            resources: [
                .copy("less.js"),
            ]
        ),
        .plugin(
            name: "LessStylesheet",
            capability: .buildTool(),
            dependencies: [
                // No point; doesn't work in archive builds. See read me for more info.
                // "lessc",
            ]
        ),
    ]
)
