//  LessStylesheet.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PackagePlugin

@main
struct LessStylesheet {
    func createBuildCommands(
        sourceFiles: FileList,
        workDirectory: Path,
        with tool: PluginContext.Tool
    ) -> [Command] {
        let importables = findImportables(sourceFiles)
        let includePaths = findIncludePaths(importables)
        let outputDirectory = workDirectory.appending(subpath: "LessStylesheet/")
        return Array(sourceFiles
            .lazy.map(\.path)
            .filter { $0.isLessFile && !$0.isImportable }
            .map { createBuildCommand(for: $0, in: outputDirectory, with: tool.path, include: includePaths, otherSources: importables) }
        )
    }

    func findImportables(
        _ fileList: FileList
    ) -> [Path] {
        Array(fileList
            .lazy.map(\.path)
            .filter { $0.isLessFile && $0.isImportable }
        )
    }

    func findIncludePaths(
        _ importables: [Path]
    ) -> [Path] {
        var seen: Set<Path> = []
        return Array(importables
            .lazy.map { $0.removingLastComponent() }
            .filter { seen.insert($0).inserted }
        )
    }

    func createBuildCommand(
        for inputPath: Path,
        in outputDirectory: Path,
        with generatorToolPath: Path,
        include includePaths: [Path],
        otherSources: [Path]
    ) -> Command {
        let outputName = inputPath.stem + ".css"
        let outputPath = outputDirectory.appending(outputName)
        var arguments: [String] = []
        arguments.append(contentsOf: includePaths.flatMap { ["--include", "\($0)"] })
        arguments.append("\(inputPath)")
        arguments.append(contentsOf: ["--output", "\(outputPath)"])
        return .buildCommand(
            displayName: "Generating \(outputName) from \(inputPath.lastComponent)",
            executable: generatorToolPath,
            arguments: arguments,
            inputFiles: [inputPath] + otherSources,
            outputFiles: [outputPath]
        )
    }
}

extension Path {
    var isImportable: Bool { lastComponent.hasPrefix("_") }
    var isLessFile: Bool { self.extension == "less" }
}

extension LessStylesheet: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        guard let sourceFiles = target.sourceModule?.sourceFiles else { return [] }
        let lessc = try context.tool(named: "lessc")
        return createBuildCommands(sourceFiles: sourceFiles, workDirectory: context.pluginWorkDirectory, with: lessc)
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension LessStylesheet: XcodeBuildToolPlugin {
    func createBuildCommands(
        context: XcodePluginContext,
        target: XcodeTarget
    ) throws -> [Command] {
        let lessc = try context.tool(named: "lessc")
        return createBuildCommands(sourceFiles: target.inputFiles, workDirectory: context.pluginWorkDirectory, with: lessc)
    }
}

#endif
