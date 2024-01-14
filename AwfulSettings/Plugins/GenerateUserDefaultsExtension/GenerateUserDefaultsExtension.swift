//  GenerateUserDefaultsExtension.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PackagePlugin

@main
struct GenerateUserDefaultsExtension: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceModule = target.sourceModule,
              let source = sourceModule.sourceFiles.first(where: { $0.path.lastComponent == "UserDefaults+Settings.swift"})?.path,
              let template = sourceModule.sourceFiles.first(where: { $0.path.lastComponent == "UserDefaults+Settings.stencil"})?.path
        else { return [] }
        let executable = context.package.directory.removingLastComponent().appending(["Vendor", "Sourcery", "bin", "sourcery"])
        let output = context.pluginWorkDirectory.appending("UserDefaults+Settings.generated.swift")
        return [.buildCommand(
            displayName: "Generating UserDefaults+Settings.generated.swift",
            executable: executable,
            arguments: [
                "--disableCache",
                "--sources", source,
                "--templates", template,
                "--output", output,
            ],
            inputFiles: [
                source,
                template,
                executable,
            ],
            outputFiles: [
                output,
            ]
        )]
    }
}
