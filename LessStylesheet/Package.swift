// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LessStylesheet",
    products: [
        .plugin(name: "LessStylesheet", targets: ["LessStylesheet"]),
    ],
    targets: [
        .plugin(
            name: "LessStylesheet",
            capability: .buildTool(),
            dependencies: [
                "lessc",
            ]
        ),
        .executableTarget(
            name: "lessc",
            resources: [
                .copy("less.js"),
            ]
        ),
    ]
)
