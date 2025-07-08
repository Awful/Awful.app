# Debugging Tools

## Overview

This document covers development debugging tools, techniques, and utilities for troubleshooting Awful.app issues.

## Built-in Debugging Features

### Debug Flags
**Enable via UserDefaults**:
```swift
// Core debugging
UserDefaults.standard.set(true, forKey: "AwfulDebugLogging")
UserDefaults.standard.set(true, forKey: "AwfulVerboseLogging")

// Network debugging
UserDefaults.standard.set(true, forKey: "AwfulNetworkDebug")
UserDefaults.standard.set(true, forKey: "AwfulNetworkVerbose")

// Core Data debugging
UserDefaults.standard.set(true, forKey: "AwfulCoreDataDebug")
UserDefaults.standard.set(1, forKey: "com.apple.CoreData.SQLDebug")

// Theme debugging
UserDefaults.standard.set(true, forKey: "AwfulThemeDebug")

// UI debugging
UserDefaults.standard.set(true, forKey: "AwfulUIDebug")

// Performance monitoring
UserDefaults.standard.set(true, forKey: "AwfulPerformanceDebug")

// Skip login for testing
UserDefaults.standard.set(true, forKey: "AwfulSkipLogin")

// Use test fixtures
UserDefaults.standard.set(true, forKey: "AwfulUseFixtures")
```

### Launch Arguments
**Add to scheme in Xcode**:
```
-AwfulDebugLogging YES
-AwfulNetworkDebug YES
-com.apple.CoreData.SQLDebug 1
-com.apple.CoreData.Logging.stderr 1
-NSDoubleLocalizedStrings YES
-NSShowNonLocalizedStrings YES
```

### Environment Variables
```
// Memory debugging
MallocStackLogging=1
MallocScribble=1
MallocGuardEdges=1

// Network debugging
CFNETWORK_DIAGNOSTICS=3

// Core Data debugging
CoreData.SQLDebug=1
CoreData.ConcurrencyDebug=1
```

## Custom Debug Console

### Debug Menu Implementation
```swift
class DebugMenuViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDebugMenu()
    }
    
    private func setupDebugMenu() {
        let sections = [
            createGeneralSection(),
            createNetworkSection(),
            createCoreDataSection(),
            createUISection(),
            createPerformanceSection()
        ]
        
        // Setup table view with sections
    }
    
    private func createGeneralSection() -> DebugSection {
        return DebugSection(title: "General", items: [
            DebugItem(title: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"),
            DebugItem(title: "Build Number", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"),
            DebugItem(title: "Device Model", value: UIDevice.current.model),
            DebugItem(title: "iOS Version", value: UIDevice.current.systemVersion),
            DebugItem(title: "Memory Usage", value: "\(getMemoryUsage()) MB", action: { self.showMemoryDetails() })
        ])
    }
    
    private func createNetworkSection() -> DebugSection {
        return DebugSection(title: "Network", items: [
            DebugItem(title: "Network Debug", value: UserDefaults.standard.bool(forKey: "AwfulNetworkDebug") ? "ON" : "OFF", action: { self.toggleNetworkDebug() }),
            DebugItem(title: "Clear Network Cache", action: { self.clearNetworkCache() }),
            DebugItem(title: "Test Connectivity", action: { self.testConnectivity() }),
            DebugItem(title: "Show Request Log", action: { self.showRequestLog() })
        ])
    }
}
```

### Debug Logger
```swift
class DebugLogger {
    static let shared = DebugLogger()
    
    private var logs = [LogEntry]()
    private let queue = DispatchQueue(label: "debug-logger", qos: .utility)
    private let maxLogs = 1000
    
    enum LogLevel: String, CaseIterable {
        case verbose = "VERBOSE"
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    func log(_ message: String, level: LogLevel = .debug, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog(level: level, category: category) else { return }
        
        queue.async {
            let entry = LogEntry(
                timestamp: Date(),
                level: level,
                category: category,
                message: message,
                file: URL(fileURLWithPath: file).lastPathComponent,
                function: function,
                line: line
            )
            
            self.logs.append(entry)
            
            // Maintain log limit
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
            
            // Print to console if enabled
            if self.shouldPrintToConsole(level: level) {
                print("[\(entry.level.rawValue)] \(entry.category): \(entry.message)")
            }
        }
    }
    
    func getLogs(category: String? = nil, level: LogLevel? = nil) -> [LogEntry] {
        return queue.sync {
            var filteredLogs = logs
            
            if let category = category {
                filteredLogs = filteredLogs.filter { $0.category == category }
            }
            
            if let level = level {
                filteredLogs = filteredLogs.filter { $0.level == level }
            }
            
            return filteredLogs
        }
    }
    
    func exportLogs() -> String {
        let logs = getLogs()
        return logs.map { entry in
            "[\(entry.timestamp)] [\(entry.level.rawValue)] \(entry.category): \(entry.message) (\(entry.file):\(entry.line))"
        }.joined(separator: "\n")
    }
}

struct LogEntry {
    let timestamp: Date
    let level: DebugLogger.LogLevel
    let category: String
    let message: String
    let file: String
    let function: String
    let line: Int
}
```

## Network Debugging Tools

### Network Request Inspector
```swift
class NetworkRequestInspector {
    static let shared = NetworkRequestInspector()
    
    private var requests = [NetworkRequest]()
    private let queue = DispatchQueue(label: "network-inspector")
    
    func recordRequest(_ request: URLRequest, response: URLResponse?, data: Data?, error: Error?) {
        queue.async {
            let networkRequest = NetworkRequest(
                request: request,
                response: response,
                responseData: data,
                error: error,
                timestamp: Date()
            )
            
            self.requests.append(networkRequest)
            
            // Log request details
            self.logRequestDetails(networkRequest)
        }
    }
    
    private func logRequestDetails(_ networkRequest: NetworkRequest) {
        let request = networkRequest.request
        let response = networkRequest.response as? HTTPURLResponse
        
        print("🌐 \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        print("   Status: \(response?.statusCode ?? 0)")
        print("   Duration: \(networkRequest.duration)ms")
        print("   Size: \(networkRequest.responseData?.count ?? 0) bytes")
        
        if let error = networkRequest.error {
            print("   Error: \(error.localizedDescription)")
        }
    }
    
    func getRequests() -> [NetworkRequest] {
        return queue.sync { requests }
    }
    
    func clearRequests() {
        queue.async {
            self.requests.removeAll()
        }
    }
}

struct NetworkRequest {
    let request: URLRequest
    let response: URLResponse?
    let responseData: Data?
    let error: Error?
    let timestamp: Date
    
    var duration: TimeInterval {
        // Calculate from request start to completion
        return 0 // Implement timing logic
    }
}
```

### Network Monitoring
```swift
class NetworkMonitor {
    private var activeRequests = Set<UUID>()
    private var requestMetrics = [UUID: RequestMetrics]()
    
    func startRequest(_ id: UUID, url: URL) {
        activeRequests.insert(id)
        requestMetrics[id] = RequestMetrics(url: url, startTime: Date())
    }
    
    func endRequest(_ id: UUID, response: URLResponse?, error: Error?) {
        activeRequests.remove(id)
        
        if var metrics = requestMetrics[id] {
            metrics.endTime = Date()
            metrics.response = response
            metrics.error = error
            requestMetrics[id] = metrics
            
            logMetrics(metrics)
        }
    }
    
    private func logMetrics(_ metrics: RequestMetrics) {
        let duration = metrics.duration
        let statusCode = (metrics.response as? HTTPURLResponse)?.statusCode ?? 0
        
        print("📊 Request: \(metrics.url.absoluteString)")
        print("   Duration: \(duration)ms")
        print("   Status: \(statusCode)")
        
        if duration > 5000 { // 5 seconds
            print("   ⚠️ Slow request detected")
        }
    }
}

struct RequestMetrics {
    let url: URL
    let startTime: Date
    var endTime: Date?
    var response: URLResponse?
    var error: Error?
    
    var duration: TimeInterval {
        guard let endTime = endTime else { return 0 }
        return endTime.timeIntervalSince(startTime) * 1000 // milliseconds
    }
}
```

## Core Data Debugging Tools

### Core Data Inspector
```swift
class CoreDataInspector {
    static let shared = CoreDataInspector()
    
    func inspectContext(_ context: NSManagedObjectContext) {
        context.perform {
            print("=== Core Data Context Inspection ===")
            print("Registered objects: \(context.registeredObjects.count)")
            print("Inserted objects: \(context.insertedObjects.count)")
            print("Updated objects: \(context.updatedObjects.count)")
            print("Deleted objects: \(context.deletedObjects.count)")
            print("Has changes: \(context.hasChanges)")
            
            // Analyze object distribution
            self.analyzeObjectDistribution(context)
            
            // Check for potential issues
            self.checkForIssues(context)
        }
    }
    
    private func analyzeObjectDistribution(_ context: NSManagedObjectContext) {
        var entityCounts = [String: Int]()
        
        for object in context.registeredObjects {
            let entityName = object.entity.name ?? "Unknown"
            entityCounts[entityName, default: 0] += 1
        }
        
        print("\nObject distribution:")
        for (entity, count) in entityCounts.sorted(by: { $0.value > $1.value }) {
            print("  \(entity): \(count)")
        }
    }
    
    private func checkForIssues(_ context: NSManagedObjectContext) {
        print("\nPotential issues:")
        
        // Check for too many objects
        if context.registeredObjects.count > 1000 {
            print("  ⚠️ High object count: \(context.registeredObjects.count)")
        }
        
        // Check for objects in fault state
        let faultCount = context.registeredObjects.filter { $0.isFault }.count
        if faultCount > 0 {
            print("  ℹ️ Objects in fault state: \(faultCount)")
        }
        
        // Check for long-lived changes
        if context.hasChanges {
            print("  ⚠️ Context has unsaved changes")
        }
    }
}
```

### Query Performance Analyzer
```swift
class QueryPerformanceAnalyzer {
    func analyzeFetchRequest<T: NSManagedObject>(_ request: NSFetchRequest<T>, in context: NSManagedObjectContext) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let results = try context.fetch(request)
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = (endTime - startTime) * 1000 // milliseconds
            
            print("📊 Query Performance:")
            print("   Entity: \(request.entityName ?? "Unknown")")
            print("   Results: \(results.count)")
            print("   Duration: \(duration)ms")
            print("   Predicate: \(request.predicate?.description ?? "None")")
            print("   Sort descriptors: \(request.sortDescriptors?.count ?? 0)")
            
            if duration > 100 { // 100ms threshold
                print("   ⚠️ Slow query detected")
                suggestOptimizations(request)
            }
            
        } catch {
            print("❌ Query failed: \(error)")
        }
    }
    
    private func suggestOptimizations<T: NSManagedObject>(_ request: NSFetchRequest<T>) {
        print("   Optimization suggestions:")
        
        if request.fetchLimit == 0 {
            print("     - Consider adding fetchLimit")
        }
        
        if request.fetchBatchSize == 0 {
            print("     - Consider adding fetchBatchSize")
        }
        
        if request.relationshipKeyPathsForPrefetching?.isEmpty != false {
            print("     - Consider prefetching relationships")
        }
        
        if request.returnsObjectsAsFaults {
            print("     - Consider setting returnsObjectsAsFaults to false")
        }
    }
}
```

## UI Debugging Tools

### View Hierarchy Inspector
```swift
class ViewHierarchyInspector {
    static func inspect(_ view: UIView, level: Int = 0) {
        let indent = String(repeating: "  ", count: level)
        let className = String(describing: type(of: view))
        let frame = view.frame
        let hidden = view.isHidden ? " [HIDDEN]" : ""
        let alpha = view.alpha < 1.0 ? " [α=\(view.alpha)]" : ""
        
        print("\(indent)\(className) \(frame)\(hidden)\(alpha)")
        
        // Check for common issues
        if view.frame.size.width == 0 || view.frame.size.height == 0 {
            print("\(indent)  ⚠️ Zero size")
        }
        
        if view.clipsToBounds && !view.subviews.isEmpty {
            print("\(indent)  ℹ️ Clips subviews")
        }
        
        for subview in view.subviews {
            inspect(subview, level: level + 1)
        }
    }
    
    static func findViewsWithIssues(_ view: UIView) -> [UIView] {
        var problematicViews = [UIView]()
        
        // Check current view
        if view.frame.size.width == 0 || view.frame.size.height == 0 {
            problematicViews.append(view)
        }
        
        if view.frame.origin.x < 0 || view.frame.origin.y < 0 {
            problematicViews.append(view)
        }
        
        // Check subviews recursively
        for subview in view.subviews {
            problematicViews.append(contentsOf: findViewsWithIssues(subview))
        }
        
        return problematicViews
    }
}
```

### Auto Layout Debugger
```swift
class AutoLayoutDebugger {
    static func debugConstraints(for view: UIView) {
        print("=== Auto Layout Debug for \(type(of: view)) ===")
        
        // Check for ambiguous layout
        if view.hasAmbiguousLayout {
            print("⚠️ Ambiguous layout detected")
        }
        
        // List constraints
        print("Constraints (\(view.constraints.count)):")
        for (index, constraint) in view.constraints.enumerated() {
            print("  [\(index)] \(constraint)")
            
            if !constraint.isActive {
                print("    ⚠️ Inactive constraint")
            }
            
            if constraint.priority.rawValue < 1000 {
                print("    ℹ️ Priority: \(constraint.priority.rawValue)")
            }
        }
        
        // Check intrinsic content size
        let intrinsicSize = view.intrinsicContentSize
        if intrinsicSize.width != UIView.noIntrinsicMetric || intrinsicSize.height != UIView.noIntrinsicMetric {
            print("Intrinsic content size: \(intrinsicSize)")
        }
        
        // Check compression resistance and hugging priorities
        let horizontalCompressionResistance = view.contentCompressionResistancePriority(for: .horizontal)
        let verticalCompressionResistance = view.contentCompressionResistancePriority(for: .vertical)
        let horizontalHugging = view.contentHuggingPriority(for: .horizontal)
        let verticalHugging = view.contentHuggingPriority(for: .vertical)
        
        print("Content priorities:")
        print("  Compression resistance: H=\(horizontalCompressionResistance.rawValue), V=\(verticalCompressionResistance.rawValue)")
        print("  Content hugging: H=\(horizontalHugging.rawValue), V=\(verticalHugging.rawValue)")
    }
}
```

## Performance Profiling Tools

### CPU Profiler
```swift
class CPUProfiler {
    private var startTime: CFAbsoluteTime = 0
    private var samples = [CPUSample]()
    
    func startProfiling() {
        startTime = CFAbsoluteTimeGetCurrent()
        samples.removeAll()
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            self.takeSample()
        }
    }
    
    private func takeSample() {
        let timestamp = CFAbsoluteTimeGetCurrent() - startTime
        let cpuUsage = getCurrentCPUUsage()
        
        samples.append(CPUSample(timestamp: timestamp, cpuUsage: cpuUsage))
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Double(info.user_time.seconds + info.system_time.seconds) : 0.0
    }
    
    func getReport() -> String {
        let avgCPU = samples.map { $0.cpuUsage }.reduce(0, +) / Double(samples.count)
        let maxCPU = samples.map { $0.cpuUsage }.max() ?? 0
        
        return """
        CPU Profile Report:
        Duration: \(samples.last?.timestamp ?? 0)s
        Samples: \(samples.count)
        Average CPU: \(avgCPU)%
        Peak CPU: \(maxCPU)%
        """
    }
}

struct CPUSample {
    let timestamp: CFAbsoluteTime
    let cpuUsage: Double
}
```

### Memory Profiler
```swift
class MemoryProfiler {
    func takeSnapshot() -> MemorySnapshot {
        let usage = getDetailedMemoryUsage()
        return MemorySnapshot(
            timestamp: Date(),
            totalMemory: usage.total,
            usedMemory: usage.used,
            freeMemory: usage.free,
            cacheMemory: usage.cache
        )
    }
    
    private func getDetailedMemoryUsage() -> (total: Int, used: Int, free: Int, cache: Int) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let used = Int(info.resident_size) / 1024 / 1024
            let total = Int(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
            return (total: total, used: used, free: total - used, cache: 0)
        }
        
        return (total: 0, used: 0, free: 0, cache: 0)
    }
}

struct MemorySnapshot {
    let timestamp: Date
    let totalMemory: Int
    let usedMemory: Int
    let freeMemory: Int
    let cacheMemory: Int
}
```

## Command Line Tools

### lldb Commands
```
# Print view hierarchy
(lldb) expr -l objc -O -- [[[UIApplication sharedApplication] keyWindow] recursiveDescription]

# Print specific view properties
(lldb) po view.frame
(lldb) po view.constraints

# Print Core Data context state
(lldb) po context.insertedObjects
(lldb) po context.hasChanges

# Print memory usage
(lldb) expr -- (void)NSLog(@"Memory: %@", [[NSProcessInfo processInfo] physicalMemory])

# Break on exception
(lldb) breakpoint set -E swift

# Symbolic breakpoint on method
(lldb) breakpoint set -n "+[NSManagedObjectContext save:]"
```

### Console Commands
```bash
# View simulator logs
xcrun simctl spawn booted log stream --predicate 'process == "Awful"'

# Reset all simulators
xcrun simctl erase all

# Install app on simulator
xcrun simctl install booted path/to/Awful.app

# Launch app with arguments
xcrun simctl launch booted com.robotsandpencils.Awful -AwfulDebugLogging YES

# Capture simulator screenshot
xcrun simctl io booted screenshot screenshot.png

# Record simulator video
xcrun simctl io booted recordVideo video.mov
```

## Testing Tools

### UI Testing Helpers
```swift
class UITestingHelpers {
    static func enableAccessibilityIdentifiers() {
        // Add accessibility identifiers to views for UI testing
        #if DEBUG
        addAccessibilityIdentifiers()
        #endif
    }
    
    private static func addAccessibilityIdentifiers() {
        // Implementation to add accessibility identifiers
    }
    
    static func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
            activity.add(attachment)
        }
    }
}
```

### Performance Testing
```swift
class PerformanceTestHelpers {
    static func measureAsyncOperation<T>(
        _ operation: @escaping (@escaping (T) -> Void) -> Void,
        timeout: TimeInterval = 5.0
    ) -> T? {
        let expectation = XCTestExpectation(description: "Async operation")
        var result: T?
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        operation { value in
            result = value
            expectation.fulfill()
        }
        
        let waiter = XCTWaiter()
        let waitResult = waiter.wait(for: [expectation], timeout: timeout)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("Operation completed in \(duration)s")
        
        return waitResult == .completed ? result : nil
    }
}
```

## Best Practices

### Debug Tool Guidelines
1. **Conditional Compilation**: Use #if DEBUG for debug-only code
2. **Performance Impact**: Minimize performance impact of debug code
3. **User Privacy**: Don't log sensitive user information
4. **Error Handling**: Handle debug tool failures gracefully
5. **Documentation**: Document debug features and flags

### Debugging Workflow
1. **Reproduce Issue**: Create consistent reproduction steps
2. **Gather Information**: Use appropriate debugging tools
3. **Form Hypothesis**: Develop theories about the issue
4. **Test Solutions**: Verify fixes with debugging tools
5. **Document Findings**: Record solutions for future reference

### Tool Integration
1. **Xcode Integration**: Use Xcode debugging features effectively
2. **Third-party Tools**: Integrate external debugging tools
3. **CI/CD Integration**: Include debugging in automated testing
4. **Team Sharing**: Share debugging configurations and tools
5. **Version Control**: Track debugging configurations appropriately