//  lessc.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import JavaScriptCore

@main struct LessCompiler {
    static func quitAndExplain(_ message: String) -> Never {
        print("error:", message)
        print()
        print("Usage: lessc [--include <path>]… <input.less> --output <output.css>")
        exit(EXIT_FAILURE)
    }

    static func quit(_ message: String) -> Never {
        print("error:", message)
        exit(EXIT_FAILURE)
    }

    static func main() throws {
        var includePaths: [String] = []
        var inputPath: String?
        var outputPath: String?
        var arguments = CommandLine.arguments.dropFirst()
    loop: while true {
            switch arguments.popFirst() {
            case "--include":
                includePaths.append(arguments.popFirst()!)
            case "--output" where outputPath == nil:
                outputPath = arguments.popFirst()!
            case .some(let input) where inputPath == nil:
                inputPath = input
            case nil:
                break loop
            case let surprise?:
                quitAndExplain("Unexpected argument: \(surprise)")
            }
        }
        if inputPath == nil { quitAndExplain("Missing input path") }
        else if outputPath == nil { quitAndExplain("Missing output path") }

        let context = JSContext()!

        // Error handling and logging.
        context.exceptionHandler = { quit("less.js exception: \($1?.toString() ?? "(null)")") }
        do {
            let log: @convention(block) (String) -> Void = { print("console.log", $0) }
            let warn: @convention(block) (String) -> Void = { print("console.warn", $0) }
            context.globalObject.setValue([
                "log": log,
                "warn": warn,
            ], forProperty: "console")
        }

        // Pretend to be a browser just enough to get rendering working: set `window` to global object and stub out some bits.
        // Then set some less options.
        context.evaluateScript(#"""
            window = this;
            document = { currentScript: {} };
            location = { hash: '' };
            less = {
                env: 'development',
                isFileProtocol: true,
                onReady: false,
                logLevel: 3,
                plugins: [{ install: (less, pluginManager) => {
                    let fm = new less.FileManager();
                    fm.loadFile = function(filename, currentDirectory, options, environment, callback) {
                        return new Promise(function (resolve, reject) {
                            var contents = loadIncludeFile(filename);
                            if (contents == null) {
                                reject({type: 'File', message: `'${filename}' wasn't found`});
                            } else {
                                resolve({contents, filename});
                            }
                        });
                    };
                    pluginManager.addFileManager(fm);
                }}],
            };
            """#
        )
        // Here's our hook to load imports.
        let loadIncludeFile: @convention(block) (String) -> String? = { filename in
            let filename = "_\(filename)"
            for includePath in includePaths {
                do {
                    let includeURL = URL(fileURLWithPath: includePath, isDirectory: true)
                    return try String(contentsOf: includeURL.appendingPathComponent(filename, isDirectory: true))
                } catch {
                    // try the next one
                }
            }
            return nil
        }
        context.globalObject.setValue(JSValue(object: loadIncludeFile, in: context), forProperty: "loadIncludeFile")

        // Now we're ready to fire up less.js.
        let lessjs = try String(contentsOf: Bundle.module.url(forResource: "less", withExtension: "js")!)
        context.evaluateScript(lessjs)

        // And use it to render!
        let input = try String(contentsOf: URL(fileURLWithPath: inputPath!))
        let render = context.globalObject.forProperty("window").forProperty("less").forProperty("render")!
        let cb: @convention(block) (JSValue?, JSValue?) -> Void = { error, output in
            if let error, !error.isNull, !error.isUndefined {
                quit("less.js render: \(error)")
            }
            guard let css = output?.forProperty("css").toString() else {
                quit("less.js render has no css output?")
            }
            let outputURL = URL(fileURLWithPath: outputPath!, isDirectory: false)
            do {
                try css.write(to: outputURL, atomically: true, encoding: .utf8)
            } catch {
                quit("could not save css output: \(error)")
            }
        }
        let result = render.call(withArguments: [
            input,
            JSValue(object: cb, in: context)!,
        ])
        guard result?.isUndefined == true else {
            quit("less.js render returned surprisingly: \(result as Any)")
        }
    }
}
