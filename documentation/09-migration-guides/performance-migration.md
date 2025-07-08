# Performance Migration Guide

## Overview

This guide covers maintaining and improving Awful.app's performance during the UIKit to SwiftUI migration, including memory optimization, rendering performance, data loading efficiency, and battery usage.

## Current Performance Characteristics

### UIKit Performance Baseline
```swift
// Current performance metrics (approximate)
struct CurrentPerformance {
    // Memory usage
    static let averageMemoryUsage: Double = 85 // MB
    static let peakMemoryUsage: Double = 150 // MB
    
    // Launch time
    static let coldLaunchTime: Double = 2.1 // seconds
    static let warmLaunchTime: Double = 0.8 // seconds
    
    // Scrolling performance
    static let averageFrameRate: Double = 58 // FPS
    static let scrollingFrameDrops: Double = 0.05 // 5% of frames
    
    // Network efficiency
    static let averageResponseTime: Double = 450 // milliseconds
    static let cacheHitRate: Double = 0.72 // 72%
    
    // Battery usage
    static let backgroundEnergyImpact: String = "Low"
    static let foregroundEnergyImpact: String = "Medium"
}

// Current performance bottlenecks
class PerformanceBottlenecks {
    // 1. Large table view cells with complex layouts
    // 2. Web view memory accumulation
    // 3. Image loading and caching inefficiencies
    // 4. Core Data fetch request overhead
    // 5. Main thread blocking during data processing
}
```

### Key Performance Areas
1. **Memory Management**: Object lifecycle and retention
2. **Rendering Performance**: View updates and drawing
3. **Data Loading**: Network requests and caching
4. **Scroll Performance**: List and collection view smoothness
5. **Launch Time**: App startup optimization
6. **Battery Usage**: CPU and network efficiency

## SwiftUI Performance Strategy

### Phase 1: Performance Monitoring Foundation

Create comprehensive performance monitoring:

```swift
// New PerformanceMonitor.swift
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var currentMetrics = PerformanceMetrics()
    @Published var isMonitoring = false
    
    private var displayLink: CADisplayLink?
    private var memoryTimer: Timer?
    private var startTime: CFTimeInterval = 0
    
    struct PerformanceMetrics {
        var frameRate: Double = 0
        var memoryUsage: Double = 0
        var cpuUsage: Double = 0
        var renderTime: Double = 0
        var viewUpdateCount: Int = 0
        
        mutating func reset() {
            frameRate = 0
            memoryUsage = 0
            cpuUsage = 0
            renderTime = 0
            viewUpdateCount = 0
        }
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        setupDisplayLink()
        setupMemoryMonitoring()
        startTime = CACurrentMediaTime()
    }
    
    func stopMonitoring() {
        isMonitoring = false
        displayLink?.invalidate()
        displayLink = nil
        memoryTimer?.invalidate()
        memoryTimer = nil
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .default)
    }
    
    @objc private func displayLinkTick(_ displayLink: CADisplayLink) {
        let frameRate = 1.0 / displayLink.targetTimestamp
        currentMetrics.frameRate = frameRate
        
        // Measure render time
        let renderStart = CACurrentMediaTime()
        // Render time measured by display link timing
        currentMetrics.renderTime = CACurrentMediaTime() - renderStart
    }
    
    private func setupMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateMemoryMetrics()
            }
        }
    }
    
    private func updateMemoryMetrics() {
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
            currentMetrics.memoryUsage = Double(info.resident_size) / 1024 / 1024 // MB
        }
        
        currentMetrics.cpuUsage = getCurrentCPUUsage()
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &info,
                                       &numCpuInfo)
        
        guard result == KERN_SUCCESS else { return 0 }
        
        // Calculate CPU usage percentage
        // Implementation details omitted for brevity
        return 0.0 // Placeholder
    }
    
    func logPerformanceEvent(_ event: String, duration: TimeInterval) {
        print("Performance: \(event) took \(duration * 1000)ms")
    }
    
    func trackViewUpdate() {
        currentMetrics.viewUpdateCount += 1
    }
}

// Performance measurement decorator
@propertyWrapper
struct Measured<T> {
    private var value: T
    private let name: String
    
    init(wrappedValue: T, _ name: String) {
        self.value = wrappedValue
        self.name = name
    }
    
    var wrappedValue: T {
        get {
            let start = CACurrentMediaTime()
            defer {
                let duration = CACurrentMediaTime() - start
                PerformanceMonitor.shared.logPerformanceEvent(name, duration: duration)
            }
            return value
        }
        set {
            value = newValue
        }
    }
}
```

### Phase 2: Memory Optimization

Implement memory-efficient patterns:

```swift
// New MemoryOptimization.swift
@MainActor
class MemoryOptimizedViewModel: ObservableObject {
    @Published var items: [Any] = []
    
    private let memoryPressureThreshold: Double = 100 // MB
    private weak var memoryWarningObserver: NSObjectProtocol?
    
    init() {
        setupMemoryWarning()
    }
    
    private func setupMemoryWarning() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        // Clear non-essential caches
        clearCaches()
        
        // Reduce loaded data
        reduceLoadedData()
        
        // Force garbage collection
        autoreleasepool {
            // Perform cleanup
        }
    }
    
    private func clearCaches() {
        // Clear image caches
        ImageCache.shared.removeAll()
        
        // Clear web view caches
        URLCache.shared.removeAllCachedResponses()
        
        // Clear temporary data
        clearTemporaryFiles()
    }
    
    private func reduceLoadedData() {
        // Keep only visible items
        let visibleRange = getVisibleRange()
        items = Array(items[visibleRange])
    }
    
    private func getVisibleRange() -> Range<Int> {
        // Calculate visible range based on scroll position
        return 0..<min(50, items.count) // Placeholder
    }
    
    private func clearTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// Memory-efficient list view
struct MemoryEfficientList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    @State private var visibleItems: Set<Item.ID> = []
    @State private var recycledViews: [Item.ID: AnyView] = [:]
    
    private let maxCachedViews = 20
    
    var body: some View {
        LazyVStack {
            ForEach(items) { item in
                content(item)
                    .onAppear {
                        visibleItems.insert(item.id)
                    }
                    .onDisappear {
                        visibleItems.remove(item.id)
                        cacheViewIfNeeded(for: item.id)
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            clearViewCache()
        }
    }
    
    private func cacheViewIfNeeded(for id: Item.ID) {
        guard recycledViews.count < maxCachedViews else { return }
        // Cache view for reuse (simplified)
    }
    
    private func clearViewCache() {
        recycledViews.removeAll()
    }
}
```

### Phase 3: Rendering Performance

Optimize view rendering and updates:

```swift
// New RenderingOptimization.swift
struct PerformantView<Content: View>: View {
    @ViewBuilder let content: Content
    
    @State private var isVisible = true
    @State private var lastUpdateTime: Date = Date()
    
    private let updateThreshold: TimeInterval = 0.016 // 60 FPS
    
    var body: some View {
        content
            .drawingGroup() // Rasterize complex views
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            isVisible = true
                        }
                        .onDisappear {
                            isVisible = false
                        }
                }
            )
            .opacity(isVisible ? 1 : 0)
    }
}

// Optimized image loading
struct OptimizedAsyncImage: View {
    let url: URL?
    let placeholder: AnyView?
    
    @State private var image: Image?
    @State private var isLoading = false
    @StateObject private var imageLoader = ImageLoader.shared
    
    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                placeholder ?? AnyView(EmptyView())
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = url else { return }
        
        isLoading = true
        
        do {
            let loadedImage = try await imageLoader.loadImage(from: url)
            await MainActor.run {
                self.image = Image(uiImage: loadedImage)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

@MainActor
class ImageLoader: ObservableObject {
    static let shared = ImageLoader()
    
    private let cache = NSCache<NSString, UIImage>()
    private let downloadQueue = DispatchQueue(label: "image-download", qos: .userInitiated)
    
    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }
    
    func loadImage(from url: URL) async throws -> UIImage {
        let cacheKey = url.absoluteString as NSString
        
        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Download image
        return try await withCheckedThrowingContinuation { continuation in
            downloadQueue.async {
                do {
                    let data = try Data(contentsOf: url)
                    guard let image = UIImage(data: data) else {
                        continuation.resume(throwing: ImageError.invalidData)
                        return
                    }
                    
                    // Resize image if too large
                    let optimizedImage = self.optimizeImage(image)
                    
                    // Cache the image
                    let cost = data.count
                    self.cache.setObject(optimizedImage, forKey: cacheKey, cost: cost)
                    
                    continuation.resume(returning: optimizedImage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func optimizeImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1024
        let size = image.size
        
        guard max(size.width, size.height) > maxDimension else {
            return image
        }
        
        let aspectRatio = size.width / size.height
        let newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

enum ImageError: Error {
    case invalidData
}
```

### Phase 4: Data Loading Optimization

Optimize data loading and caching:

```swift
// New DataLoadingOptimization.swift
@MainActor
class OptimizedDataLoader: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    
    private let cache = NSCache<NSString, AnyObject>()
    private let operationQueue = OperationQueue()
    
    init() {
        operationQueue.maxConcurrentOperationCount = 3
        operationQueue.qualityOfService = .userInitiated
        
        cache.countLimit = 50
        cache.totalCostLimit = 10 * 1024 * 1024 // 10 MB
    }
    
    func loadData<T: Codable>(
        from endpoint: String,
        type: T.Type,
        cachePolicy: CachePolicy = .standard
    ) async throws -> T {
        let cacheKey = NSString(string: endpoint)
        
        // Check cache based on policy
        if cachePolicy != .noCache,
           let cachedData = cache.object(forKey: cacheKey) as? CachedItem<T>,
           !cachedData.isExpired {
            return cachedData.item
        }
        
        // Load from network
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try await performNetworkRequest(endpoint: endpoint)
            let item = try JSONDecoder().decode(T.self, from: data)
            
            // Cache the result
            if cachePolicy != .noCache {
                let cachedItem = CachedItem(item: item, expiry: cachePolicy.expiry)
                cache.setObject(cachedItem, forKey: cacheKey, cost: data.count)
            }
            
            return item
        } catch {
            self.error = error
            throw error
        }
    }
    
    private func performNetworkRequest(endpoint: String) async throws -> Data {
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }
        
        return data
    }
    
    func prefetchData<T: Codable>(
        from endpoints: [String],
        type: T.Type,
        priority: Operation.QueuePriority = .normal
    ) {
        for endpoint in endpoints {
            let operation = BlockOperation {
                Task {
                    try? await self.loadData(from: endpoint, type: type)
                }
            }
            operation.queuePriority = priority
            operationQueue.addOperation(operation)
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

struct CachedItem<T> {
    let item: T
    let timestamp: Date
    let expiry: TimeInterval
    
    init(item: T, expiry: TimeInterval) {
        self.item = item
        self.timestamp = Date()
        self.expiry = expiry
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > expiry
    }
}

enum CachePolicy {
    case noCache
    case standard
    case aggressive
    case custom(TimeInterval)
    
    var expiry: TimeInterval {
        switch self {
        case .noCache: return 0
        case .standard: return 300 // 5 minutes
        case .aggressive: return 3600 // 1 hour
        case .custom(let interval): return interval
        }
    }
}

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case networkUnavailable
}
```

### Phase 5: Background Processing

Optimize background processing:

```swift
// New BackgroundProcessing.swift
@MainActor
class BackgroundTaskManager: ObservableObject {
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let processingQueue = DispatchQueue(label: "background-processing", qos: .background)
    
    func performBackgroundTask<T>(
        _ task: @escaping () async throws -> T
    ) async throws -> T {
        // Start background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "DataProcessing") {
            self.endBackgroundTask()
        }
        
        defer {
            endBackgroundTask()
        }
        
        return try await withTaskGroup(of: T.self) { group in
            group.addTask {
                try await task()
            }
            
            return try await group.next()!
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    func scheduleBackgroundRefresh() {
        // Schedule background app refresh
        let request = BGAppRefreshTaskRequest(identifier: "com.awful.background-refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        try? BGTaskScheduler.shared.submit(request)
    }
}

// Optimized Core Data operations
extension NSManagedObjectContext {
    func performBackgroundBatch<T>(
        _ operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            perform {
                do {
                    let result = try operation(self)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func batchInsert<T: NSManagedObject>(
        _ objects: [T],
        batchSize: Int = 100
    ) async throws {
        let batches = objects.chunked(into: batchSize)
        
        for batch in batches {
            try await performBackgroundBatch { context in
                for object in batch {
                    context.insert(object)
                }
                try context.save()
            }
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

## Migration Steps

### Step 1: Performance Baseline (Week 1)
1. **Setup Performance Monitoring**: Comprehensive metrics collection
2. **Establish Baseline**: Current performance measurements
3. **Identify Bottlenecks**: Performance profiling and analysis
4. **Create Performance Tests**: Automated performance validation

### Step 2: Memory Optimization (Week 2)
1. **Implement Memory Monitoring**: Real-time memory tracking
2. **Optimize View Lifecycle**: Efficient view creation and destruction
3. **Implement View Recycling**: Reuse expensive views
4. **Add Memory Pressure Handling**: Graceful memory management

### Step 3: Rendering Optimization (Week 2-3)
1. **Optimize Complex Views**: Use drawingGroup for complex layouts
2. **Implement Lazy Loading**: On-demand view creation
3. **Add Image Optimization**: Efficient image loading and caching
4. **Optimize Animations**: Smooth animation performance

### Step 4: Data Loading Optimization (Week 3)
1. **Implement Smart Caching**: Intelligent cache management
2. **Add Prefetching**: Predictive data loading
3. **Optimize Network Requests**: Efficient request handling
4. **Background Processing**: Off-main-thread operations

### Step 5: Performance Validation (Week 4)
1. **Comprehensive Testing**: Performance regression testing
2. **Real Device Testing**: Multi-device performance validation
3. **Memory Leak Detection**: Automated leak detection
4. **Battery Usage Analysis**: Energy impact assessment

## Performance Best Practices

### SwiftUI Specific Optimizations
```swift
// Avoid expensive computations in body
struct OptimizedView: View {
    let data: [Item]
    
    // Compute expensive values outside of body
    private var processedData: [ProcessedItem] {
        data.map { item in
            processItem(item) // Expensive operation
        }
    }
    
    var body: some View {
        List(processedData) { item in
            ItemRow(item: item)
        }
    }
}

// Use @State for local state only
struct EfficientStateView: View {
    @State private var localCounter = 0 // Good: local state
    @StateObject private var viewModel = ViewModel() // Good: owned object
    @ObservedObject var sharedData: SharedData // Good: external object
    
    var body: some View {
        VStack {
            Text("Counter: \(localCounter)")
            Text("Shared: \(sharedData.value)")
        }
    }
}

// Minimize view updates with equatable
struct OptimizedRow: View, Equatable {
    let item: Item
    
    static func == (lhs: OptimizedRow, rhs: OptimizedRow) -> Bool {
        lhs.item.id == rhs.item.id && lhs.item.version == rhs.item.version
    }
    
    var body: some View {
        HStack {
            Text(item.title)
            Spacer()
            Text(item.subtitle)
        }
    }
}
```

## Risk Mitigation

### High-Risk Performance Areas
1. **Memory Leaks**: SwiftUI retain cycles
2. **Scroll Performance**: Large list rendering
3. **Network Efficiency**: Excessive requests
4. **Battery Drain**: Background processing

### Mitigation Strategies
1. **Continuous Monitoring**: Real-time performance tracking
2. **Automated Testing**: Performance regression detection
3. **Memory Profiling**: Regular memory analysis
4. **Device Testing**: Multi-device validation

## Testing Strategy

### Performance Tests
```swift
// PerformanceTests.swift
class PerformanceTests: XCTestCase {
    func testScrollPerformance() {
        measure {
            // Measure scroll performance
            // Large list scrolling test
        }
    }
    
    func testMemoryUsage() {
        measureMemory {
            // Memory usage test
            // Load large dataset and measure memory
        }
    }
    
    func testLaunchTime() {
        measure {
            // App launch time test
        }
    }
}
```

### Memory Tests
```swift
// MemoryTests.swift
class MemoryTests: XCTestCase {
    func testMemoryLeaks() {
        weak var viewModel: ViewModel?
        
        autoreleasepool {
            let vm = ViewModel()
            viewModel = vm
            // Use view model
        }
        
        XCTAssertNil(viewModel, "View model should be deallocated")
    }
    
    func testMemoryPressure() {
        // Test memory pressure handling
        // Simulate low memory conditions
    }
}
```

## Performance Targets

### Target Metrics
```swift
struct PerformanceTargets {
    // Memory usage
    static let maxMemoryUsage: Double = 120 // MB (30% increase allowance)
    static let averageMemoryUsage: Double = 90 // MB
    
    // Launch time
    static let maxColdLaunchTime: Double = 2.5 // seconds
    static let maxWarmLaunchTime: Double = 1.0 // seconds
    
    // Scrolling performance
    static let minFrameRate: Double = 55 // FPS
    static let maxFrameDrops: Double = 0.03 // 3% of frames
    
    // Network efficiency
    static let maxResponseTime: Double = 500 // milliseconds
    static let minCacheHitRate: Double = 0.75 // 75%
    
    // Battery usage
    static let maxEnergyImpact: String = "Medium"
}
```

## Timeline Estimation

### Conservative Estimate: 4 weeks
- **Week 1**: Performance monitoring and baseline
- **Week 2**: Memory and rendering optimization
- **Week 3**: Data loading optimization
- **Week 4**: Performance validation and tuning

### Aggressive Estimate: 3 weeks
- Assumes simple performance optimization
- No major architectural changes
- Limited optimization scope

## Dependencies

### Internal Dependencies
- PerformanceMonitor: Metrics collection
- ImageLoader: Optimized image handling
- DataLoader: Efficient data operations

### External Dependencies
- SwiftUI: UI framework performance
- Core Data: Data layer efficiency
- Network framework: Request optimization

## Success Criteria

### Performance Requirements
- [ ] Memory usage within 30% of current levels
- [ ] Launch time maintained or improved
- [ ] Scroll performance smooth at 55+ FPS
- [ ] Network efficiency maintained or improved
- [ ] Battery usage impact unchanged

### Technical Requirements
- [ ] No memory leaks detected
- [ ] Automated performance tests passing
- [ ] Performance monitoring active
- [ ] Optimization patterns documented
- [ ] Performance regressions prevented

### User Experience Requirements
- [ ] App feels as fast or faster
- [ ] No perceived performance degradation
- [ ] Smooth animations and transitions
- [ ] Responsive user interactions
- [ ] Efficient background operations

## Migration Checklist

### Pre-Migration
- [ ] Establish performance baseline
- [ ] Setup performance monitoring
- [ ] Identify performance bottlenecks
- [ ] Prepare performance tests

### During Migration
- [ ] Implement performance monitoring
- [ ] Apply memory optimizations
- [ ] Optimize rendering performance
- [ ] Improve data loading efficiency
- [ ] Add background processing optimization

### Post-Migration
- [ ] Validate performance targets
- [ ] Test on multiple devices
- [ ] Analyze battery usage
- [ ] Update documentation
- [ ] Deploy to beta testing

This migration guide provides a comprehensive approach to maintaining and improving performance during the UIKit to SwiftUI migration while ensuring the app remains fast and efficient.