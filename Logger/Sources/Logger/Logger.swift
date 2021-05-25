//  Logger.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/**
 Records messages of varying severity.
 
 All loggers have a name. Requesting a logger with the same name will always return the same instance.
 
 Only messages at or above the logger's current level will be printed. Messages lower than the logger's current level are discarded. The levels, in increasing order, are: debug, info, warning, error.
 
 ## Typical usage
 
 Put a logger instance in each file, e.g.:
 
     private let Log: Logger = .get()
 
 then pepper the code in that file with calls to `Log.d`, `Log.i`, `Log.w`, and `Log.e`.
 
 While working in a file, you might temporarily set its logger's level to debug in order to get more information about what's going on. You do this by changing to e.g.

     private let Log: Logger = .get(level: .debug)

 then you might back out of that change once you're pleased with your work.

 ## When to use which level
 
 The levels can be kinda wishy-washy, and different people can reasonably have different opinions about their correct usage. Here are some general ideas that might help you get started.
 
     * Use `Log.d` for messages that are only interesting during development, or that are too noisy for a production release. Anytime you want to `print` something just to poke at it, make it a `Log.d` and leave it in for the next person.
     * Use `Log.i` for messages that might be useful in a crash log, but don't otherwise indicate a failure. Since info is the default log level, you can assume it will be included when you run into a problem.
     * Use `Log.w` for messages that are unexpected, but aren't worth giving up and showing the user an error message.
     * Use `Log.e` for errors that we tell the user about.
     * When in doubt, just log something and sort it out later!
 
 Note that nothing here is meant to replace any Swift error handling and condition checking (e.g. `try`/`catch`, `assert`, `precondition`, `fatalError`). When that's the right tool for the job, please use it!
 */
public class Logger {
    public var level: Level
    let name: String

    public enum Level: Comparable {
        case debug, info, warning, error

        var abbreviation: String {
            switch self {
            case .debug:
                return "DEBUG"
            case .info:
                return "INFO"
            case .warning:
                return "WARN"
            case .error:
                return "ERROR"
            }
        }

        public static func < (lhs: Level, rhs: Level) -> Bool {
            switch (lhs, rhs) {
            case (.debug, .info), (.debug, .warning), (.debug, .error),
                 (.info, .warning), (.info, .error),
                 (.warning, .error):
                return true

            case (.debug, _), (.info, _), (.warning, _), (.error, _):
                return false
            }
        }
    }

    init(name: String, level: Level = .info) {
        self.name = name
        self.level = level
    }

    /**
     Retrieves the named logger, creating it if necessary.
     
     - Parameter name: What to call the logger. Pass `nil` (the default) in order to name the logger after the basename of the current file.
     - Parameter level: The log level to use for the newly-created logger. If the logger already exists, its level is not changed.
     */
    public static func get(
        _ name: String? = nil,
        level: Level = .info,
        file: String = #file
    ) -> Logger {
        let name = name ?? String(file.split(separator: "/").last?.split(separator: ".").dropLast().last ?? "")

        loggersLock.lock()
        defer { loggersLock.unlock() }

        if let logger = loggers[name] {
            return logger
        }

        let logger = Logger(name: name, level: level)
        loggers[name] = logger

        return logger
    }

    public func log(
        level: Level,
        message: () -> String,
        file: String,
        line: Int
    ) {
        guard level >= self.level else { return }
        let message = message()
        print("[\(name)] \(file):L\(line):\(level.abbreviation): \(message)")
        Logger.extraHandler?(name, level, message, file, line)
    }

    /**
     Records a debug message.
     
     - Seealso: `Level.debug`
     */
    public func d(
        _ message: @autoclosure () -> String,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .debug, message: message, file: file, line: line)
    }

    /**
     Records an info message.
     
     - Seealso: `Level.info`
     */
    public func i(
        _ message: @autoclosure () -> String,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .info, message: message, file: file, line: line)
    }

    /**
     Records a warning message.
     
     - Seealso: `Level.warning`
     */
    public func w(
        _ message: @autoclosure () -> String,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .warning, message: message, file: file, line: line)
    }

    /**
     Records an error message.
     
     - Seealso: `Level.error`
     */
    public func e(
        _ message: @autoclosure () -> String,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .error, message: message, file: file, line: line)
    }
    
    /// A closure to call with every message that gets printed (e.g. for use with `CLSLog`).
    public static var extraHandler: ((_ name: String, _ level: Level, _ message: String, _ file: String, _ line: Int) -> Void)?
}

var loggers: [String: Logger] = [:]
let loggersLock: NSLock = .init()
