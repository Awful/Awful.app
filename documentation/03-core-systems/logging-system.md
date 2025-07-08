# Logging System

## Overview

The logging system provides comprehensive debug and diagnostic information throughout the Awful app. This system must be efficient, configurable, and provide valuable insights for debugging and monitoring during the SwiftUI migration.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Logging System                          │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Log Levels    │  │   Log Targets   │  │  Log Formatters │  │
│  │                 │  │                 │  │                 │  │
│  │ • Debug         │  │ • Console       │  │ • Text          │  │
│  │ • Info          │  │ • File          │  │ • JSON          │  │
│  │ • Warning       │  │ • Network       │  │ • Structured    │  │
│  │ • Error         │  │ • Analytics     │  │ • Custom        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Log Categories │  │   Performance   │  │  Privacy        │  │
│  │                 │  │                 │  │                 │  │
│  │ • Network       │  │ • Buffering     │  │ • Data Masking  │  │
│  │ • UI            │  │ • Async Logging │  │ • PII Filtering │  │
│  │ • Core Data     │  │ • Compression   │  │ • Redaction     │  │
│  │ • Auth          │  │ • Rotation      │  │ • Sanitization  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Core Logger Implementation

### Logger Interface
```swift
import Foundation
import os.log

// MARK: - Log Level

public enum LogLevel: Int, CaseIterable, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Log Category

public enum LogCategory: String, CaseIterable {
    case network = "network"
    case ui = "ui"
    case coreData = "core_data"
    case authentication = "auth"
    case parsing = "parsing"
    case performance = "performance"
    case user = "user"
    case system = "system"
    case general = "general"
    
    var subsystem: String {
        return "com.awful.app.\(rawValue)"
    }
    
    var osLog: OSLog {
        return OSLog(subsystem: subsystem, category: rawValue)
    }
}
```

### Main Logger Class
```swift
public class AwfulLogger {
    public static let shared = AwfulLogger()
    
    private let configuration: LoggerConfiguration
    private let targets: [LogTarget]
    private let formatter: LogFormatter
    private let queue: DispatchQueue
    private let privacy: PrivacyManager
    
    // MARK: - Initialization
    
    private init() {
        self.configuration = LoggerConfiguration.default
        self.targets = LogTargetFactory.createDefaultTargets()
        self.formatter = DefaultLogFormatter()
        self.queue = DispatchQueue(label: "com.awful.app.logging", qos: .utility)
        self.privacy = PrivacyManager()
    }
    
    // MARK: - Public Logging Interface
    
    public func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard shouldLog(level: level, category: category) else { return }
        
        let logEntry = LogEntry(
            message: message,
            level: level,
            category: category,
            timestamp: Date(),
            file: file,
            function: function,
            line: line,
            thread: Thread.current
        )
        
        logEntry(logEntry)
    }
    
    public func debug(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    public func info(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    public func warning(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    public func error(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    public func critical(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Structured Logging
    
    public func logEvent(
        _ event: String,
        properties: [String: Any] = [:],
        level: LogLevel = .info,
        category: LogCategory = .general
    ) {
        let sanitizedProperties = privacy.sanitize(properties)
        let structuredMessage = formatStructuredMessage(event: event, properties: sanitizedProperties)
        log(structuredMessage, level: level, category: category)
    }
    
    public func logPerformance(
        operation: String,
        duration: TimeInterval,
        additionalInfo: [String: Any] = [:]
    ) {
        let properties = [
            "operation": operation,
            "duration_ms": Int(duration * 1000),
            "additional_info": additionalInfo
        ]
        logEvent("performance_metric", properties: properties, category: .performance)
    }
    
    public func logNetworkRequest(
        method: String,
        url: String,
        statusCode: Int?,
        duration: TimeInterval?,
        error: Error? = nil
    ) {
        var properties: [String: Any] = [
            "method": method,
            "url": privacy.sanitizeURL(url)
        ]
        
        if let statusCode = statusCode {
            properties["status_code"] = statusCode
        }
        
        if let duration = duration {
            properties["duration_ms"] = Int(duration * 1000)
        }
        
        if let error = error {
            properties["error"] = error.localizedDescription
        }
        
        let level: LogLevel = error != nil ? .error : .info
        logEvent("network_request", properties: properties, level: level, category: .network)
    }
    
    // MARK: - Private Methods
    
    private func shouldLog(level: LogLevel, category: LogCategory) -> Bool {
        return level >= configuration.minimumLevel && 
               configuration.enabledCategories.contains(category)
    }
    
    private func logEntry(_ entry: LogEntry) {
        // Sanitize message for privacy
        let sanitizedEntry = privacy.sanitize(entry)
        
        // Log asynchronously to avoid blocking
        queue.async {
            self.writeToTargets(sanitizedEntry)
        }
    }
    
    private func writeToTargets(_ entry: LogEntry) {
        let formattedMessage = formatter.format(entry)
        
        for target in targets {
            target.write(entry, formattedMessage: formattedMessage)
        }
    }
    
    private func formatStructuredMessage(event: String, properties: [String: Any]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        let structuredData: [String: Any] = [
            "event": event,
            "properties": properties
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: structuredData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return "STRUCTURED: \(jsonString)"
        }
        
        return "STRUCTURED: \(event)"
    }
}
```

### Log Entry Model
```swift
public struct LogEntry {
    public let message: String
    public let level: LogLevel
    public let category: LogCategory
    public let timestamp: Date
    public let file: String
    public let function: String
    public let line: Int
    public let thread: Thread
    
    public var fileName: String {
        return URL(fileURLWithPath: file).lastPathComponent
    }
    
    public var isMainThread: Bool {
        return thread.isMainThread
    }
    
    public var threadName: String {
        return thread.name ?? "Thread-\(thread.hash)"
    }
}
```

## Log Targets

### Target Protocol
```swift
protocol LogTarget {
    func write(_ entry: LogEntry, formattedMessage: String)
    func flush()
    func shouldLog(_ entry: LogEntry) -> Bool
}

// MARK: - Console Target

class ConsoleLogTarget: LogTarget {
    private let minimumLevel: LogLevel
    
    init(minimumLevel: LogLevel = .debug) {
        self.minimumLevel = minimumLevel
    }
    
    func write(_ entry: LogEntry, formattedMessage: String) {
        guard shouldLog(entry) else { return }
        
        // Use os_log for system integration
        os_log("%{public}@", log: entry.category.osLog, type: entry.level.osLogType, formattedMessage)
        
        // Also print to debug console
        #if DEBUG
        print(formattedMessage)
        #endif
    }
    
    func flush() {
        // Console doesn't need flushing
    }
    
    func shouldLog(_ entry: LogEntry) -> Bool {
        return entry.level >= minimumLevel
    }
}
```

### File Target
```swift
class FileLogTarget: LogTarget {
    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let maxFileSize: Int
    private let maxFileCount: Int
    private let minimumLevel: LogLevel
    
    private var currentFileHandle: FileHandle?
    private var currentFileURL: URL?
    private var currentFileSize: Int = 0
    
    init(
        logDirectory: URL? = nil,
        maxFileSize: Int = 10 * 1024 * 1024, // 10MB
        maxFileCount: Int = 5,
        minimumLevel: LogLevel = .info
    ) {
        self.logDirectory = logDirectory ?? Self.defaultLogDirectory()
        self.maxFileSize = maxFileSize
        self.maxFileCount = maxFileCount
        self.minimumLevel = minimumLevel
        
        setupLogDirectory()
        createNewLogFile()
    }
    
    private static func defaultLogDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Logs")
    }
    
    private func setupLogDirectory() {
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }
    
    func write(_ entry: LogEntry, formattedMessage: String) {
        guard shouldLog(entry) else { return }
        
        let logLine = "\(formattedMessage)\n"
        guard let data = logLine.data(using: .utf8) else { return }
        
        // Check if we need to rotate the log file
        if currentFileSize + data.count > maxFileSize {
            rotateLogFile()
        }
        
        // Write to current file
        currentFileHandle?.write(data)
        currentFileSize += data.count
    }
    
    func flush() {
        currentFileHandle?.synchronizeFile()
    }
    
    func shouldLog(_ entry: LogEntry) -> Bool {
        return entry.level >= minimumLevel
    }
    
    private func createNewLogFile() {
        closeCurrentFile()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let fileName = "awful-\(timestamp).log"
        currentFileURL = logDirectory.appendingPathComponent(fileName)
        
        guard let fileURL = currentFileURL else { return }
        
        // Create empty file
        fileManager.createFile(atPath: fileURL.path, contents: nil)
        
        // Open file handle
        currentFileHandle = try? FileHandle(forWritingTo: fileURL)
        currentFileSize = 0
    }
    
    private func rotateLogFile() {
        cleanupOldFiles()
        createNewLogFile()
    }
    
    private func cleanupOldFiles() {
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
            
            // Keep only the newest files
            let filesToDelete = logFiles.dropFirst(maxFileCount - 1)
            
            for file in filesToDelete {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("Failed to cleanup old log files: \(error)")
        }
    }
    
    private func closeCurrentFile() {
        currentFileHandle?.closeFile()
        currentFileHandle = nil
        currentFileURL = nil
    }
    
    deinit {
        closeCurrentFile()
    }
}
```

### Network Target
```swift
class NetworkLogTarget: LogTarget {
    private let endpoint: URL
    private let apiKey: String?
    private let batchSize: Int
    private let flushInterval: TimeInterval
    private let minimumLevel: LogLevel
    
    private var logBatch: [LogEntry] = []
    private var lastFlush = Date()
    private let queue = DispatchQueue(label: "com.awful.app.network-logging")
    
    init(
        endpoint: URL,
        apiKey: String? = nil,
        batchSize: Int = 50,
        flushInterval: TimeInterval = 60.0,
        minimumLevel: LogLevel = .warning
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.minimumLevel = minimumLevel
        
        startPeriodicFlush()
    }
    
    func write(_ entry: LogEntry, formattedMessage: String) {
        guard shouldLog(entry) else { return }
        
        queue.async {
            self.logBatch.append(entry)
            
            if self.logBatch.count >= self.batchSize {
                self.flushInternal()
            }
        }
    }
    
    func flush() {
        queue.async {
            self.flushInternal()
        }
    }
    
    func shouldLog(_ entry: LogEntry) -> Bool {
        return entry.level >= minimumLevel
    }
    
    private func startPeriodicFlush() {
        Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { _ in
            self.flush()
        }
    }
    
    private func flushInternal() {
        guard !logBatch.isEmpty else { return }
        
        let batch = logBatch
        logBatch.removeAll()
        lastFlush = Date()
        
        sendBatch(batch)
    }
    
    private func sendBatch(_ batch: [LogEntry]) {
        let logData = batch.map { entry in
            [
                "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                "level": entry.level.displayName,
                "category": entry.category.rawValue,
                "message": entry.message,
                "file": entry.fileName,
                "function": entry.function,
                "line": entry.line,
                "thread": entry.threadName
            ]
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["logs": logData])
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Failed to send logs: \(error)")
                }
            }.resume()
        } catch {
            print("Failed to serialize logs: \(error)")
        }
    }
}
```

## Log Formatters

### Formatter Protocol
```swift
protocol LogFormatter {
    func format(_ entry: LogEntry) -> String
}

// MARK: - Default Formatter

class DefaultLogFormatter: LogFormatter {
    private let dateFormatter: DateFormatter
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    func format(_ entry: LogEntry) -> String {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        let level = entry.level.displayName.padding(toLength: 8, withPad: " ", startingAt: 0)
        let category = entry.category.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0)
        let location = "\(entry.fileName):\(entry.line)"
        let thread = entry.isMainThread ? "main" : "bg"
        
        return "\(timestamp) [\(level)] [\(category)] [\(thread)] \(location) - \(entry.message)"
    }
}

// MARK: - JSON Formatter

class JSONLogFormatter: LogFormatter {
    private let encoder: JSONEncoder
    
    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
    }
    
    func format(_ entry: LogEntry) -> String {
        let logObject: [String: Any] = [
            "timestamp": entry.timestamp,
            "level": entry.level.displayName,
            "category": entry.category.rawValue,
            "message": entry.message,
            "file": entry.fileName,
            "function": entry.function,
            "line": entry.line,
            "thread": entry.threadName,
            "is_main_thread": entry.isMainThread
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: logObject),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return entry.message
    }
}
```

## Privacy and Security

### Privacy Manager
```swift
class PrivacyManager {
    private let piiPatterns: [NSRegularExpression]
    private let urlSanitizer: URLSanitizer
    
    init() {
        // Common PII patterns
        piiPatterns = [
            try! NSRegularExpression(pattern: #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#), // Credit cards
            try! NSRegularExpression(pattern: #"\b\d{3}-\d{2}-\d{4}\b"#), // SSN
            try! NSRegularExpression(pattern: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#), // Email
            try! NSRegularExpression(pattern: #"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b"#) // Phone numbers
        ]
        
        urlSanitizer = URLSanitizer()
    }
    
    func sanitize(_ entry: LogEntry) -> LogEntry {
        let sanitizedMessage = sanitizeString(entry.message)
        
        return LogEntry(
            message: sanitizedMessage,
            level: entry.level,
            category: entry.category,
            timestamp: entry.timestamp,
            file: entry.file,
            function: entry.function,
            line: entry.line,
            thread: entry.thread
        )
    }
    
    func sanitize(_ properties: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        
        for (key, value) in properties {
            switch value {
            case let stringValue as String:
                sanitized[key] = sanitizeString(stringValue)
            case let dictValue as [String: Any]:
                sanitized[key] = sanitize(dictValue)
            case let arrayValue as [Any]:
                sanitized[key] = arrayValue.map { sanitizeValue($0) }
            default:
                sanitized[key] = value
            }
        }
        
        return sanitized
    }
    
    func sanitizeURL(_ url: String) -> String {
        return urlSanitizer.sanitize(url)
    }
    
    private func sanitizeString(_ string: String) -> String {
        var sanitized = string
        
        for pattern in piiPatterns {
            sanitized = pattern.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(location: 0, length: sanitized.count),
                withTemplate: "[REDACTED]"
            )
        }
        
        return sanitized
    }
    
    private func sanitizeValue(_ value: Any) -> Any {
        switch value {
        case let stringValue as String:
            return sanitizeString(stringValue)
        case let dictValue as [String: Any]:
            return sanitize(dictValue)
        default:
            return value
        }
    }
}

class URLSanitizer {
    func sanitize(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else {
            return urlString
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Remove sensitive query parameters
        if let queryItems = components?.queryItems {
            components?.queryItems = queryItems.compactMap { item in
                if isSensitiveParameter(item.name) {
                    return URLQueryItem(name: item.name, value: "[REDACTED]")
                }
                return item
            }
        }
        
        return components?.url?.absoluteString ?? urlString
    }
    
    private func isSensitiveParameter(_ name: String) -> Bool {
        let sensitiveParams = ["password", "token", "key", "auth", "session", "secret"]
        return sensitiveParams.contains { name.lowercased().contains($0) }
    }
}
```

## Performance Monitoring

### Performance Logger
```swift
class PerformanceLogger {
    private let logger = AwfulLogger.shared
    
    func measureTime<T>(
        operation: String,
        category: LogCategory = .performance,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.logPerformance(operation: operation, duration: duration)
        
        return result
    }
    
    func measureAsyncTime<T>(
        operation: String,
        category: LogCategory = .performance,
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.logPerformance(operation: operation, duration: duration)
        
        return result
    }
    
    func logMemoryUsage(context: String) {
        let memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsage = Double(memoryInfo.resident_size) / 1024.0 / 1024.0 // MB
            
            logger.logEvent("memory_usage", properties: [
                "context": context,
                "memory_mb": memoryUsage
            ], category: .performance)
        }
    }
}

// Usage examples
extension PerformanceLogger {
    static func measureNetworkRequest<T>(
        url: String,
        method: String,
        block: () async throws -> T
    ) async rethrows -> T {
        return try await PerformanceLogger().measureAsyncTime(
            operation: "network_request",
            block: block
        )
    }
    
    static func measureCoreDataOperation<T>(
        operation: String,
        block: () throws -> T
    ) rethrows -> T {
        return try PerformanceLogger().measureTime(
            operation: "core_data_\(operation)",
            category: .coreData,
            block: block
        )
    }
}
```

## Configuration

### Logger Configuration
```swift
struct LoggerConfiguration {
    let minimumLevel: LogLevel
    let enabledCategories: Set<LogCategory>
    let enableConsoleLogging: Bool
    let enableFileLogging: Bool
    let enableNetworkLogging: Bool
    let maxFileSize: Int
    let maxFileCount: Int
    
    static let `default` = LoggerConfiguration(
        minimumLevel: .debug,
        enabledCategories: Set(LogCategory.allCases),
        enableConsoleLogging: true,
        enableFileLogging: true,
        enableNetworkLogging: false,
        maxFileSize: 10 * 1024 * 1024, // 10MB
        maxFileCount: 5
    )
    
    static let production = LoggerConfiguration(
        minimumLevel: .info,
        enabledCategories: Set(LogCategory.allCases),
        enableConsoleLogging: false,
        enableFileLogging: true,
        enableNetworkLogging: true,
        maxFileSize: 5 * 1024 * 1024, // 5MB
        maxFileCount: 3
    )
}

class LogTargetFactory {
    static func createDefaultTargets() -> [LogTarget] {
        var targets: [LogTarget] = []
        
        #if DEBUG
        targets.append(ConsoleLogTarget(minimumLevel: .debug))
        #endif
        
        targets.append(FileLogTarget(minimumLevel: .info))
        
        // Add network target in production
        #if !DEBUG
        if let networkEndpoint = getNetworkLoggingEndpoint() {
            targets.append(NetworkLogTarget(
                endpoint: networkEndpoint,
                minimumLevel: .error
            ))
        }
        #endif
        
        return targets
    }
    
    private static func getNetworkLoggingEndpoint() -> URL? {
        // Return configured logging endpoint
        return nil
    }
}
```

## Testing

### Mock Logger
```swift
class MockLogger: AwfulLogger {
    private(set) var loggedMessages: [LogEntry] = []
    
    override func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let entry = LogEntry(
            message: message,
            level: level,
            category: category,
            timestamp: Date(),
            file: file,
            function: function,
            line: line,
            thread: Thread.current
        )
        
        loggedMessages.append(entry)
    }
    
    func clearLogs() {
        loggedMessages.removeAll()
    }
    
    func hasLoggedMessage(containing substring: String, level: LogLevel? = nil) -> Bool {
        return loggedMessages.contains { entry in
            let messageMatches = entry.message.contains(substring)
            let levelMatches = level == nil || entry.level == level
            return messageMatches && levelMatches
        }
    }
}

// Test example
class LoggingTests: XCTestCase {
    var mockLogger: MockLogger!
    
    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
    }
    
    func testErrorLogging() {
        mockLogger.error("Test error message", category: .network)
        
        XCTAssertTrue(mockLogger.hasLoggedMessage(containing: "Test error message", level: .error))
        XCTAssertEqual(mockLogger.loggedMessages.count, 1)
        XCTAssertEqual(mockLogger.loggedMessages[0].category, .network)
    }
}
```

## Convenience Extensions

### SwiftUI Integration
```swift
extension View {
    func logViewAppear(_ viewName: String) -> some View {
        onAppear {
            AwfulLogger.shared.debug("View appeared: \(viewName)", category: .ui)
        }
    }
    
    func logViewDisappear(_ viewName: String) -> some View {
        onDisappear {
            AwfulLogger.shared.debug("View disappeared: \(viewName)", category: .ui)
        }
    }
}

// Usage
struct ContentView: View {
    var body: some View {
        Text("Hello World")
            .logViewAppear("ContentView")
            .logViewDisappear("ContentView")
    }
}
```

### Network Request Logging
```swift
extension URLRequest {
    func logRequest() {
        let method = httpMethod ?? "GET"
        let url = self.url?.absoluteString ?? "unknown"
        
        AwfulLogger.shared.logEvent("network_request_start", properties: [
            "method": method,
            "url": url
        ], category: .network)
    }
}

extension URLResponse {
    func logResponse(data: Data?, error: Error?) {
        guard let httpResponse = self as? HTTPURLResponse else { return }
        
        var properties: [String: Any] = [
            "status_code": httpResponse.statusCode,
            "url": httpResponse.url?.absoluteString ?? "unknown"
        ]
        
        if let data = data {
            properties["response_size"] = data.count
        }
        
        if let error = error {
            properties["error"] = error.localizedDescription
        }
        
        let level: LogLevel = error != nil ? .error : .info
        AwfulLogger.shared.logEvent("network_request_complete", properties: properties, level: level, category: .network)
    }
}
```

## Best Practices

1. **Use Appropriate Log Levels**: Debug for development, info for significant events, warnings for potential issues, errors for failures
2. **Structure Your Logs**: Use categories and structured logging for better analysis
3. **Protect Privacy**: Always sanitize sensitive information before logging
4. **Performance**: Use asynchronous logging to avoid blocking main thread
5. **Storage Management**: Implement log rotation and cleanup to manage disk usage
6. **Context**: Include relevant context information in log messages
7. **Testing**: Use mock loggers for testing to verify logging behavior
8. **Monitoring**: Use logs for debugging, monitoring, and improving app performance