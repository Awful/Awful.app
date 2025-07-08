# Performance Testing

## Overview

Performance testing in Awful.app ensures the application maintains high performance standards during the SwiftUI migration and ongoing development. This document covers benchmarking strategies, performance monitoring, and optimization validation.

## Performance Testing Strategy

### Key Performance Metrics

#### Application Performance
- **Launch Time**: Cold start and warm start measurements
- **Memory Usage**: Peak memory consumption and memory growth
- **CPU Usage**: Processing efficiency and battery impact
- **Network Performance**: Request latency and data throughput
- **Storage I/O**: Core Data operations and file system access

#### User Experience Metrics
- **Frame Rate**: 60 FPS target for smooth animations
- **Touch Responsiveness**: Sub-100ms touch-to-response time
- **Scroll Performance**: Smooth scrolling in lists and web views
- **Navigation Speed**: Quick transitions between screens

### Performance Test Categories

#### Synthetic Benchmarks
- Isolated component performance
- Algorithm efficiency testing
- Memory allocation patterns
- CPU-intensive operations

#### Realistic Workloads
- Typical user journey performance
- Heavy content loading scenarios
- Concurrent operation handling
- Background processing efficiency

## XCTest Performance Testing

### Basic Performance Measurement

#### Launch Performance
```swift
final class LaunchPerformanceTests: XCTestCase {
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    func testColdLaunchPerformance() {
        let app = XCUIApplication()
        
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.terminate()
            app.launch()
        }
    }
    
    func testWarmLaunchPerformance() {
        let app = XCUIApplication()
        app.launch() // Initial launch
        
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.activate()
        }
    }
}
```

#### Memory Performance
```swift
final class MemoryPerformanceTests: XCTestCase {
    func testMemoryUsageDuringThreadLoading() {
        measure(metrics: [XCTMemoryMetric()]) {
            let viewController = PostsPageViewController(
                thread: createLargeThread(),
                forumsClient: ForumsClient.shared
            )
            
            viewController.loadViewIfNeeded()
            viewController.viewDidLoad()
            viewController.loadPage(1)
            
            // Simulate memory pressure
            for _ in 0..<100 {
                let post = createTestPost()
                viewController.addPost(post)
            }
        }
    }
    
    func testMemoryLeaksInNavigation() {
        weak var weakViewController: PostsPageViewController?
        
        measure(metrics: [XCTMemoryMetric()]) {
            autoreleasepool {
                let viewController = PostsPageViewController(
                    thread: createTestThread(),
                    forumsClient: ForumsClient.shared
                )
                weakViewController = viewController
                
                // Simulate full lifecycle
                viewController.loadViewIfNeeded()
                viewController.viewDidLoad()
                viewController.viewWillAppear(true)
                viewController.viewDidAppear(true)
                viewController.viewWillDisappear(true)
                viewController.viewDidDisappear(true)
            }
        }
        
        XCTAssertNil(weakViewController, "View controller should be deallocated")
    }
}
```

#### CPU Performance
```swift
final class CPUPerformanceTests: XCTestCase {
    func testHTMLParsingPerformance() {
        let htmlContent = loadLargeHTMLFixture()
        
        measure(metrics: [XCTCPUMetric()]) {
            let document = HTMLDocument(string: htmlContent)
            let posts = try! PostsPageScrapeResult(document, url: nil)
            XCTAssertGreaterThan(posts.posts.count, 0)
        }
    }
    
    func testCoreDataFetchPerformance() {
        let context = createPopulatedContext(threadCount: 1000, postsPerThread: 100)
        
        measure(metrics: [XCTCPUMetric()]) {
            let request: NSFetchRequest<Thread> = Thread.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "lastPostDate", ascending: false)]
            request.fetchLimit = 50
            
            let threads = try! context.fetch(request)
            XCTAssertEqual(threads.count, 50)
        }
    }
}
```

### Network Performance Testing

#### HTTP Request Performance
```swift
final class NetworkPerformanceTests: XCTestCase {
    func testForumPageLoadPerformance() async {
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Forum page loaded")
            
            Task {
                do {
                    let result = try await ForumsClient.shared.loadForumPage(forumID: "1")
                    XCTAssertGreaterThan(result.threads.count, 0)
                    expectation.fulfill()
                } catch {
                    XCTFail("Network request failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testConcurrentRequestPerformance() async {
        let threadIDs = Array(1...10).map(String.init)
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "All requests completed")
            expectation.expectedFulfillmentCount = threadIDs.count
            
            for threadID in threadIDs {
                Task {
                    do {
                        let result = try await ForumsClient.shared.loadThread(threadID: threadID)
                        XCTAssertNotNil(result)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Request failed for thread \(threadID)")
                    }
                }
            }
            
            wait(for: [expectation], timeout: 30)
        }
    }
}
```

#### Image Loading Performance
```swift
final class ImageLoadingPerformanceTests: XCTestCase {
    func testAvatarLoadingPerformance() {
        let imageURLs = createTestImageURLs(count: 50)
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Images loaded")
            expectation.expectedFulfillmentCount = imageURLs.count
            
            for url in imageURLs {
                ImagePipeline.shared.loadImage(with: url) { result in
                    switch result {
                    case .success:
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Image loading failed: \(error)")
                    }
                }
            }
            
            wait(for: [expectation], timeout: 30)
        }
    }
}
```

### UI Performance Testing

#### Scroll Performance
```swift
final class ScrollPerformanceTests: XCTestCase {
    func testThreadListScrollPerformance() {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to thread list
        app.tabBars.buttons["Forums"].tap()
        app.tables.cells.element(boundBy: 0).tap()
        
        let threadsTable = app.tables.firstMatch
        XCTAssertTrue(threadsTable.waitForExistence(timeout: 10))
        
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
            // Perform rapid scrolling
            for _ in 0..<20 {
                threadsTable.swipeUp()
            }
            
            for _ in 0..<20 {
                threadsTable.swipeDown()
            }
        }
    }
    
    func testWebViewScrollPerformance() {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to thread
        navigateToFirstThread(app)
        
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 10))
        
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
            // Test web view scrolling
            for _ in 0..<10 {
                webView.swipeUp()
            }
            
            for _ in 0..<10 {
                webView.swipeDown()
            }
        }
    }
}
```

#### Animation Performance
```swift
final class AnimationPerformanceTests: XCTestCase {
    func testNavigationAnimationPerformance() {
        let app = XCUIApplication()
        app.launch()
        
        measure(metrics: [XCTOSSignpostMetric.navigationTransitionMetric]) {
            // Test navigation performance
            app.tabBars.buttons["Forums"].tap()
            app.tables.cells.element(boundBy: 0).tap()
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }
    
    func testModalPresentationPerformance() {
        let app = XCUIApplication()
        app.launch()
        
        navigateToFirstThread(app)
        
        measure(metrics: [XCTOSSignpostMetric.applicationLaunchMetric]) {
            // Test modal presentation
            app.toolbars.buttons["Reply"].tap()
            
            // Wait for modal to appear
            XCTAssertTrue(app.navigationBars["Reply"].waitForExistence(timeout: 5))
            
            // Dismiss modal
            app.navigationBars.buttons["Cancel"].tap()
            
            // Handle confirmation if needed
            let alert = app.alerts.firstMatch
            if alert.exists {
                alert.buttons["Discard"].tap()
            }
        }
    }
}
```

## Custom Performance Monitoring

### Performance Profiler

```swift
class PerformanceProfiler {
    private var startTime: CFAbsoluteTime = 0
    private var measurements: [String: CFTimeInterval] = [:]
    
    func startMeasuring(_ operation: String) {
        startTime = CFAbsoluteTimeGetCurrent()
    }
    
    func endMeasuring(_ operation: String) {
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        measurements[operation] = duration
    }
    
    func reportMeasurements() {
        for (operation, duration) in measurements {
            print("⏱️ \(operation): \(String(format: "%.3f", duration * 1000))ms")
        }
    }
    
    func clearMeasurements() {
        measurements.removeAll()
    }
}
```

### Memory Monitor

```swift
class MemoryMonitor {
    func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    func monitorMemoryDuring<T>(_ operation: () throws -> T) rethrows -> (result: T, memoryDelta: Int64) {
        let initialMemory = getCurrentMemoryUsage()
        let result = try operation()
        let finalMemory = getCurrentMemoryUsage()
        
        let memoryDelta = Int64(finalMemory) - Int64(initialMemory)
        return (result: result, memoryDelta: memoryDelta)
    }
}
```

### CPU Monitor

```swift
class CPUMonitor {
    func getCurrentCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &info,
                                       &numCpuInfo)
        
        if result == KERN_SUCCESS {
            // Calculate CPU usage
            let cpuLoadInfo = info.bindMemory(to: processor_cpu_load_info.self, capacity: Int(numCpus))
            
            var totalUser: UInt32 = 0
            var totalSystem: UInt32 = 0
            var totalIdle: UInt32 = 0
            
            for i in 0..<Int(numCpus) {
                totalUser += cpuLoadInfo[i].cpu_ticks.0
                totalSystem += cpuLoadInfo[i].cpu_ticks.1
                totalIdle += cpuLoadInfo[i].cpu_ticks.2
            }
            
            let total = totalUser + totalSystem + totalIdle
            return Double(totalUser + totalSystem) / Double(total) * 100.0
        }
        
        return 0.0
    }
}
```

## Performance Testing for Migration

### UIKit vs SwiftUI Performance

#### Rendering Performance Comparison
```swift
final class MigrationPerformanceTests: XCTestCase {
    func testUIKitVsSwiftUIRenderingPerformance() {
        let testData = createLargeThreadList(count: 1000)
        
        // Test UIKit performance
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            let uikitController = UIKitThreadsTableViewController()
            uikitController.threads = testData
            uikitController.loadViewIfNeeded()
            uikitController.viewDidLoad()
            
            // Simulate scrolling
            uikitController.tableView.reloadData()
        }
        
        // Test SwiftUI performance
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            let swiftuiView = SwiftUIThreadsList(threads: testData)
            let hostingController = UIHostingController(rootView: swiftuiView)
            hostingController.loadViewIfNeeded()
            
            // Force view update
            hostingController.rootView = SwiftUIThreadsList(threads: testData)
        }
    }
}
```

#### Navigation Performance Comparison
```swift
final class NavigationPerformanceTests: XCTestCase {
    func testUIKitNavigationPerformance() {
        measure(metrics: [XCTClockMetric()]) {
            let navController = UINavigationController()
            let sourceVC = UIKitForumsViewController()
            let targetVC = UIKitThreadsViewController()
            
            navController.viewControllers = [sourceVC]
            
            let expectation = XCTestExpectation(description: "Navigation completed")
            
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                expectation.fulfill()
            }
            
            navController.pushViewController(targetVC, animated: true)
            
            CATransaction.commit()
            
            wait(for: [expectation], timeout: 5)
        }
    }
    
    func testSwiftUINavigationPerformance() {
        measure(metrics: [XCTClockMetric()]) {
            // SwiftUI navigation performance testing
            // Would require custom measurement since SwiftUI
            // navigation is declarative
        }
    }
}
```

### Data Performance Testing

#### Core Data Performance
```swift
final class CoreDataPerformanceTests: XCTestCase {
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = createPerformanceTestContext()
    }
    
    func testBatchInsertPerformance() {
        let threadData = createTestThreadData(count: 1000)
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            context.performAndWait {
                for data in threadData {
                    let thread = Thread(context: context)
                    thread.threadID = data.id
                    thread.title = data.title
                    thread.lastPostDate = data.lastPostDate
                }
                
                do {
                    try context.save()
                } catch {
                    XCTFail("Failed to save context: \(error)")
                }
            }
        }
    }
    
    func testComplexFetchPerformance() {
        // Populate context with test data
        populateContextWithTestData(threadCount: 10000, postsPerThread: 50)
        
        measure(metrics: [XCTClockMetric()]) {
            let request: NSFetchRequest<Thread> = Thread.fetchRequest()
            request.predicate = NSPredicate(format: "isBookmarked == YES AND lastPostDate > %@", Date().addingTimeInterval(-86400) as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "lastPostDate", ascending: false)]
            request.fetchLimit = 100
            request.relationshipKeyPathsForPrefetching = ["forum", "lastPost", "lastPost.author"]
            
            let threads = try! context.fetch(request)
            XCTAssertLessThanOrEqual(threads.count, 100)
        }
    }
}
```

#### HTML Scraping Performance
```swift
final class ScrapingPerformanceTests: XCTestCase {
    func testLargeThreadScrapingPerformance() {
        let largeThreadHTML = loadFixture("large-thread") // 1000+ posts
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let document = HTMLDocument(string: largeThreadHTML)
            let result = try! PostsPageScrapeResult(document, url: nil)
            
            XCTAssertGreaterThan(result.posts.count, 1000)
        }
    }
    
    func testConcurrentScrapingPerformance() {
        let htmlFixtures = (1...10).map { "thread-page-\($0)" }
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "All scraping completed")
            expectation.expectedFulfillmentCount = htmlFixtures.count
            
            let queue = DispatchQueue(label: "scraping", qos: .userInitiated, attributes: .concurrent)
            
            for fixture in htmlFixtures {
                queue.async {
                    let html = self.loadFixture(fixture)
                    let document = HTMLDocument(string: html)
                    let result = try! PostsPageScrapeResult(document, url: nil)
                    
                    XCTAssertGreaterThan(result.posts.count, 0)
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 10)
        }
    }
}
```

## Performance Benchmarking

### Baseline Establishment

#### Performance Baselines
```swift
struct PerformanceBaselines {
    static let launchTime: TimeInterval = 2.0 // seconds
    static let threadLoadTime: TimeInterval = 1.0 // seconds
    static let memoryUsageLimit: UInt64 = 100_000_000 // 100MB
    static let scrollFPS: Double = 60.0
    static let networkRequestTimeout: TimeInterval = 5.0
    
    static func validate(metric: String, value: Double) -> Bool {
        switch metric {
        case "launch":
            return value <= launchTime
        case "threadLoad":
            return value <= threadLoadTime
        case "scroll":
            return value >= scrollFPS
        case "network":
            return value <= networkRequestTimeout
        default:
            return true
        }
    }
}
```

#### Performance Regression Detection
```swift
class PerformanceRegressionDetector {
    private let baselineStore = UserDefaults(suiteName: "performance-baselines")!
    
    func recordBaseline(for metric: String, value: Double) {
        baselineStore.set(value, forKey: "baseline-\(metric)")
    }
    
    func checkForRegression(metric: String, currentValue: Double, threshold: Double = 0.1) -> Bool {
        guard let baseline = baselineStore.object(forKey: "baseline-\(metric)") as? Double else {
            // No baseline exists, record current value
            recordBaseline(for: metric, value: currentValue)
            return false
        }
        
        let percentageChange = (currentValue - baseline) / baseline
        return percentageChange > threshold
    }
    
    func reportRegressions() {
        // Implementation would report performance regressions
        // to monitoring system or CI/CD pipeline
    }
}
```

### Continuous Performance Monitoring

#### Performance Test Integration
```swift
final class ContinuousPerformanceTests: XCTestCase {
    let regressionDetector = PerformanceRegressionDetector()
    
    func testContinuousLaunchPerformance() {
        var launchTimes: [TimeInterval] = []
        
        for _ in 0..<5 {
            let startTime = CFAbsoluteTimeGetCurrent()
            let app = XCUIApplication()
            app.launch()
            app.terminate()
            let endTime = CFAbsoluteTimeGetCurrent()
            
            launchTimes.append(endTime - startTime)
        }
        
        let averageLaunchTime = launchTimes.reduce(0, +) / Double(launchTimes.count)
        
        XCTAssertFalse(
            regressionDetector.checkForRegression(
                metric: "launch",
                currentValue: averageLaunchTime
            ),
            "Launch time regression detected: \(averageLaunchTime)s"
        )
    }
}
```

## Performance Optimization Validation

### Before/After Comparison Testing

#### Optimization Impact Measurement
```swift
final class OptimizationValidationTests: XCTestCase {
    func testImageCachingOptimization() {
        let imageURLs = createTestImageURLs(count: 100)
        
        // Test without caching (baseline)
        let baselineTime = measureImageLoadingTime(urls: imageURLs, useCache: false)
        
        // Test with caching (optimized)
        let optimizedTime = measureImageLoadingTime(urls: imageURLs, useCache: true)
        
        // Verify optimization improved performance
        let improvementRatio = baselineTime / optimizedTime
        XCTAssertGreaterThan(improvementRatio, 2.0, "Image caching should improve performance by at least 2x")
    }
    
    private func measureImageLoadingTime(urls: [URL], useCache: Bool) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let expectation = XCTestExpectation(description: "Images loaded")
        expectation.expectedFulfillmentCount = urls.count
        
        let pipeline = useCache ? ImagePipeline.shared : ImagePipeline(configuration: .withoutCache)
        
        for url in urls {
            pipeline.loadImage(with: url) { _ in
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30)
        
        return CFAbsoluteTimeGetCurrent() - startTime
    }
}
```

### A/B Performance Testing

#### Feature Flag Performance Impact
```swift
final class FeatureFlagPerformanceTests: XCTestCase {
    func testNewFeaturePerformanceImpact() {
        // Test with feature disabled
        FeatureFlags.newPostRenderer = false
        let baselineTime = measurePostRenderingTime()
        
        // Test with feature enabled
        FeatureFlags.newPostRenderer = true
        let newFeatureTime = measurePostRenderingTime()
        
        // Verify new feature doesn't significantly impact performance
        let performanceImpact = (newFeatureTime - baselineTime) / baselineTime
        XCTAssertLessThan(performanceImpact, 0.05, "New feature should not impact performance by more than 5%")
    }
    
    private func measurePostRenderingTime() -> TimeInterval {
        let posts = createTestPosts(count: 100)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for post in posts {
            let renderer = PostRenderer()
            let _ = renderer.render(post)
        }
        
        return CFAbsoluteTimeGetCurrent() - startTime
    }
}
```

## Performance Test Automation

### CI/CD Integration

#### Performance Pipeline
```yaml
# .github/workflows/performance.yml
name: Performance Tests

on:
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *' # Daily at 2 AM

jobs:
  performance:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Run Performance Tests
      run: |
        xcodebuild test \
          -project Awful.xcodeproj \
          -scheme AwfulPerformanceTests \
          -destination 'platform=iOS Simulator,name=iPhone 14' \
          -resultBundlePath performance-results
    
    - name: Analyze Performance Results
      run: |
        python scripts/analyze-performance.py performance-results
    
    - name: Upload Performance Report
      uses: actions/upload-artifact@v2
      with:
        name: performance-report
        path: performance-report.html
```

#### Performance Regression Alerts
```swift
// Script to analyze performance results and alert on regressions
class PerformanceAnalyzer {
    func analyzeResults(_ resultBundle: URL) {
        let metrics = extractMetrics(from: resultBundle)
        
        for metric in metrics {
            if isRegression(metric) {
                sendAlert(for: metric)
            }
        }
    }
    
    private func isRegression(_ metric: PerformanceMetric) -> Bool {
        // Compare against historical baselines
        return metric.value > metric.baseline * 1.1 // 10% threshold
    }
    
    private func sendAlert(for metric: PerformanceMetric) {
        // Send alert to Slack, email, or monitoring system
        print("⚠️ Performance regression detected: \(metric.name)")
    }
}
```

## Best Practices

### Test Design
- Establish clear performance baselines
- Test realistic scenarios and data sizes
- Include both synthetic and real-world workloads
- Test across different device capabilities

### Measurement Accuracy
- Use appropriate metrics for each test type
- Run multiple iterations for statistical significance
- Control for external factors (device state, network conditions)
- Use consistent test environments

### Automation
- Integrate performance tests into CI/CD pipeline
- Set up regression detection and alerting
- Maintain performance baselines over time
- Regular performance review and optimization cycles

### Reporting
- Generate clear performance reports
- Track performance trends over time
- Compare performance across different configurations
- Document performance characteristics and trade-offs

## Future Enhancements

### Advanced Performance Testing
- Real device performance testing
- Battery usage optimization testing
- Thermal performance testing
- Accessibility performance testing

### Tool Integration
- Firebase Performance Monitoring
- Instruments automation
- Custom performance dashboards
- Performance budgets and enforcement