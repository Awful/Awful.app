# Performance Issues

## Overview

This document covers performance problems, memory issues, and optimization techniques for Awful.app.

## Performance Monitoring

### Key Performance Metrics
**App Launch Time**:
- Cold launch: < 2 seconds
- Warm launch: < 1 second
- Resume from background: < 0.5 seconds

**Memory Usage**:
- Typical usage: < 100 MB
- Peak usage: < 200 MB
- Memory warnings: Should be handled gracefully

**Network Performance**:
- Thread loading: < 3 seconds
- Image loading: < 5 seconds
- Search results: < 2 seconds

### Profiling Tools
**Instruments Templates**:
- Time Profiler: CPU usage analysis
- Allocations: Memory usage tracking
- Leaks: Memory leak detection
- Network: Network activity monitoring
- Energy Log: Battery usage analysis

**Built-in Debugging**:
```swift
// Enable performance logging
UserDefaults.standard.set(true, forKey: "AwfulPerformanceDebug")

// Memory usage monitoring
func logMemoryUsage() {
    let memoryUsage = getMemoryUsage()
    print("Memory usage: \(memoryUsage.used) MB / \(memoryUsage.total) MB")
}

func getMemoryUsage() -> (used: Int, total: Int) {
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
        return (used, total)
    }
    
    return (0, 0)
}
```

## Common Performance Issues

### Slow App Launch
**Problem**: App takes too long to start
**Common Causes**:
- Heavy initialization on main thread
- Synchronous network requests
- Large data processing
- Inefficient view loading

**Solutions**:
1. Profile launch sequence:
   ```swift
   func profileAppLaunch() {
       let startTime = CFAbsoluteTimeGetCurrent()
       
       // Track initialization phases
       measureBlock("Core Data Setup") {
           setupCoreData()
       }
       
       measureBlock("Theme Loading") {
           ThemeManager.shared.loadDefaultTheme()
       }
       
       measureBlock("UI Setup") {
           setupUserInterface()
       }
       
       let totalTime = CFAbsoluteTimeGetCurrent() - startTime
       print("Total launch time: \(totalTime)s")
   }
   
   func measureBlock(_ name: String, block: () -> Void) {
       let start = CFAbsoluteTimeGetCurrent()
       block()
       let end = CFAbsoluteTimeGetCurrent()
       print("\(name): \(end - start)s")
   }
   ```

2. Optimize initialization:
   ```swift
   class AppDelegate: UIResponder, UIApplicationDelegate {
       func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
           
           // Essential initialization only
           setupCoreComponents()
           
           // Defer non-critical setup
           DispatchQueue.main.async {
               self.setupSecondaryComponents()
           }
           
           return true
       }
       
       func setupCoreComponents() {
           // Core Data
           // Essential services
           // Basic UI setup
       }
       
       func setupSecondaryComponents() {
           // Analytics
           // Non-critical services
           // Background tasks
       }
   }
   ```

3. Lazy initialization:
   ```swift
   class ForumsClient {
       private lazy var urlSession: URLSession = {
           let config = URLSessionConfiguration.default
           config.timeoutIntervalForRequest = 30.0
           return URLSession(configuration: config)
       }()
       
       private lazy var imageCache: NSCache<NSString, UIImage> = {
           let cache = NSCache<NSString, UIImage>()
           cache.countLimit = 100
           cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
           return cache
       }()
   }
   ```

### Memory Issues
**Problem**: High memory usage or memory warnings
**Common Causes**:
- Image cache too large
- Retained view controllers
- Core Data object graphs
- Memory leaks

**Solutions**:
1. Implement memory monitoring:
   ```swift
   class MemoryMonitor {
       private var timer: Timer?
       
       func startMonitoring() {
           timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
               self.checkMemoryUsage()
           }
       }
       
       func checkMemoryUsage() {
           let usage = getMemoryUsage()
           let threshold = 150 // MB
           
           if usage.used > threshold {
               print("⚠️ High memory usage: \(usage.used) MB")
               performMemoryCleanup()
           }
       }
       
       func performMemoryCleanup() {
           // Clear image caches
           ImageCache.shared.removeAll()
           
           // Clear web view caches
           clearWebViewCaches()
           
           // Reset Core Data contexts
           CoreDataStack.shared.resetContexts()
           
           // Notify view controllers to cleanup
           NotificationCenter.default.post(name: .memoryWarning, object: nil)
       }
   }
   ```

2. Implement proper memory warnings handling:
   ```swift
   override func didReceiveMemoryWarning() {
       super.didReceiveMemoryWarning()
       
       // Clear non-essential caches
       imageCache.removeAllObjects()
       
       // Release heavy resources
       releaseHeavyResources()
       
       // Clear view hierarchy if not visible
       if !isViewLoaded || view.window == nil {
           view = nil
       }
   }
   ```

3. Use memory-efficient image loading:
   ```swift
   class MemoryEfficientImageLoader {
       func loadImage(url: URL, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
           // Download image data
           URLSession.shared.dataTask(with: url) { data, response, error in
               guard let data = data, error == nil else {
                   completion(nil)
                   return
               }
               
               // Resize image to target size to save memory
               let image = self.resizeImage(data: data, targetSize: targetSize)
               
               DispatchQueue.main.async {
                   completion(image)
               }
           }.resume()
       }
       
       private func resizeImage(data: Data, targetSize: CGSize) -> UIImage? {
           guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
               return nil
           }
           
           let options: [CFString: Any] = [
               kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height),
               kCGImageSourceCreateThumbnailFromImageAlways: true
           ]
           
           guard let scaledImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
               return nil
           }
           
           return UIImage(cgImage: scaledImage)
       }
   }
   ```

### UI Performance Issues
**Problem**: Slow scrolling, laggy animations, unresponsive UI
**Common Causes**:
- Main thread blocking
- Complex view hierarchies
- Inefficient table/collection view cells
- Heavy image processing

**Solutions**:
1. Optimize table view performance:
   ```swift
   class OptimizedTableViewCell: UITableViewCell {
       override func prepareForReuse() {
           super.prepareForReuse()
           
           // Cancel any ongoing operations
           imageLoadingTask?.cancel()
           
           // Reset cell state
           titleLabel.text = nil
           subtitleLabel.text = nil
           avatarImageView.image = nil
       }
       
       func configure(with thread: Thread) {
           // Set text immediately
           titleLabel.text = thread.title
           subtitleLabel.text = thread.author
           
           // Load image asynchronously
           loadAvatarImage(for: thread.author)
       }
       
       private func loadAvatarImage(for author: String) {
           imageLoadingTask = ImageLoader.shared.loadAvatar(for: author) { [weak self] image in
               DispatchQueue.main.async {
                   self?.avatarImageView.image = image
               }
           }
       }
   }
   ```

2. Use background queues for heavy work:
   ```swift
   func processThreadData(_ threads: [ThreadData]) {
       DispatchQueue.global(qos: .userInitiated).async {
           // Heavy processing
           let processedThreads = threads.map { self.processThread($0) }
           
           DispatchQueue.main.async {
               // Update UI
               self.updateUI(with: processedThreads)
           }
       }
   }
   ```

3. Optimize view hierarchies:
   ```swift
   // Bad: Complex nested views
   stackView.addArrangedSubview(containerView)
   containerView.addSubview(innerStackView)
   innerStackView.addArrangedSubview(labelContainer)
   labelContainer.addSubview(label)
   
   // Good: Flat hierarchy
   stackView.addArrangedSubview(label)
   ```

## Network Performance

### Slow Network Requests
**Problem**: Network requests take too long
**Common Causes**:
- No request timeouts
- Synchronous requests
- Too many concurrent requests
- Large response sizes

**Solutions**:
1. Optimize URLSession configuration:
   ```swift
   class OptimizedNetworkManager {
       private lazy var urlSession: URLSession = {
           let config = URLSessionConfiguration.default
           
           // Set reasonable timeouts
           config.timeoutIntervalForRequest = 30.0
           config.timeoutIntervalForResource = 60.0
           
           // Limit concurrent connections
           config.httpMaximumConnectionsPerHost = 4
           
           // Enable HTTP/2
           config.httpShouldUsePipelining = true
           
           // Configure cache
           config.urlCache = URLCache(
               memoryCapacity: 10 * 1024 * 1024,  // 10MB
               diskCapacity: 50 * 1024 * 1024     // 50MB
           )
           
           return URLSession(configuration: config)
       }()
   }
   ```

2. Implement request batching:
   ```swift
   class BatchRequestManager {
       private var pendingRequests = [String: [CompletionHandler]]()
       private let queue = DispatchQueue(label: "batch-requests")
       
       func performRequest(url: URL, completion: @escaping CompletionHandler) {
           let key = url.absoluteString
           
           queue.async {
               if var handlers = self.pendingRequests[key] {
                   // Request already in progress, add to batch
                   handlers.append(completion)
                   self.pendingRequests[key] = handlers
               } else {
                   // New request
                   self.pendingRequests[key] = [completion]
                   self.executeRequest(url: url, key: key)
               }
           }
       }
       
       private func executeRequest(url: URL, key: String) {
           URLSession.shared.dataTask(with: url) { data, response, error in
               self.queue.async {
                   let handlers = self.pendingRequests.removeValue(forKey: key) ?? []
                   
                   DispatchQueue.main.async {
                       for handler in handlers {
                           handler(data, response, error)
                       }
                   }
               }
           }.resume()
       }
   }
   ```

3. Use response caching:
   ```swift
   class CachedNetworkManager {
       private let cache = NSCache<NSString, CachedResponse>()
       
       func loadThread(threadID: String, completion: @escaping (Thread?) -> Void) {
           let cacheKey = "thread-\(threadID)" as NSString
           
           // Check cache first
           if let cachedResponse = cache.object(forKey: cacheKey),
              cachedResponse.isValid {
               completion(cachedResponse.thread)
               return
           }
           
           // Network request
           performNetworkRequest(threadID: threadID) { thread in
               if let thread = thread {
                   let cachedResponse = CachedResponse(thread: thread, timestamp: Date())
                   self.cache.setObject(cachedResponse, forKey: cacheKey)
               }
               completion(thread)
           }
       }
   }
   
   class CachedResponse {
       let thread: Thread
       let timestamp: Date
       let ttl: TimeInterval = 300 // 5 minutes
       
       init(thread: Thread, timestamp: Date) {
           self.thread = thread
           self.timestamp = timestamp
       }
       
       var isValid: Bool {
           return Date().timeIntervalSince(timestamp) < ttl
       }
   }
   ```

### Image Loading Performance
**Problem**: Images load slowly or cause UI lag
**Solutions**:
1. Implement progressive image loading:
   ```swift
   class ProgressiveImageLoader {
       func loadImage(url: URL, progressHandler: @escaping (Double) -> Void, completion: @escaping (UIImage?) -> Void) {
           let task = URLSession.shared.dataTask(with: url) { data, response, error in
               guard let data = data, error == nil else {
                   completion(nil)
                   return
               }
               
               // Create incremental image source
               let source = CGImageSourceCreateIncremental(nil)
               CGImageSourceUpdateData(source, data as CFData, true)
               
               if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                   let image = UIImage(cgImage: cgImage)
                   DispatchQueue.main.async {
                       completion(image)
                   }
               }
           }
           
           task.resume()
       }
   }
   ```

2. Use image prefetching:
   ```swift
   class ImagePrefetcher {
       private let prefetchQueue = DispatchQueue(label: "image-prefetch", qos: .utility)
       private var prefetchTasks = [URL: URLSessionDataTask]()
       
       func prefetchImages(urls: [URL]) {
           prefetchQueue.async {
               for url in urls {
                   self.prefetchImage(url: url)
               }
           }
       }
       
       private func prefetchImage(url: URL) {
           guard prefetchTasks[url] == nil else { return }
           
           let task = URLSession.shared.dataTask(with: url) { data, _, _ in
               // Store in cache
               if let data = data {
                   ImageCache.shared.setData(data, for: url)
               }
               
               self.prefetchTasks.removeValue(forKey: url)
           }
           
           prefetchTasks[url] = task
           task.resume()
       }
   }
   ```

## Core Data Performance

### Slow Fetch Requests
**Problem**: Core Data queries are slow
**Solutions**:
1. Optimize fetch requests:
   ```swift
   func optimizedThreadsFetch() -> NSFetchRequest<Thread> {
       let request = NSFetchRequest<Thread>(entityName: "Thread")
       
       // Use predicates to limit results
       request.predicate = NSPredicate(format: "lastUpdate > %@", Date().addingTimeInterval(-86400))
       
       // Limit result set
       request.fetchLimit = 50
       
       // Use batch fetching
       request.fetchBatchSize = 20
       
       // Prefetch relationships
       request.relationshipKeyPathsForPrefetching = ["forum", "author"]
       
       // Optimize for performance
       request.includesSubentities = false
       request.includesPropertyValues = true
       request.returnsObjectsAsFaults = false
       
       return request
   }
   ```

2. Use background contexts for heavy operations:
   ```swift
   func performHeavyCoreDataOperation() {
       let backgroundContext = persistentContainer.newBackgroundContext()
       
       backgroundContext.perform {
           // Heavy Core Data work
           let request = self.createHeavyFetchRequest()
           
           do {
               let results = try backgroundContext.fetch(request)
               self.processResults(results, in: backgroundContext)
               
               try backgroundContext.save()
           } catch {
               print("Background operation failed: \(error)")
           }
       }
   }
   ```

3. Implement proper indexing:
   ```swift
   // In Core Data model
   // Add indexes on frequently queried attributes:
   // - threadID
   // - lastUpdate
   // - forumID
   // - authorName
   ```

### Memory Usage with Core Data
**Problem**: Core Data consuming too much memory
**Solutions**:
1. Use faulting effectively:
   ```swift
   func manageCoreDataMemory() {
       let context = persistentContainer.viewContext
       
       // Turn objects into faults
       for object in context.registeredObjects {
           if !object.isFault && !context.updatedObjects.contains(object) {
               context.refresh(object, mergeChanges: false)
           }
       }
       
       // Reset context if memory pressure is high
       if getMemoryUsage().used > 150 {
           context.reset()
       }
   }
   ```

2. Batch processing for large datasets:
   ```swift
   func processBatchUpdate() {
       let batchRequest = NSBatchUpdateRequest(entityName: "Thread")
       batchRequest.predicate = NSPredicate(format: "needsUpdate == YES")
       batchRequest.propertiesToUpdate = ["lastProcessed": Date()]
       
       do {
           try persistentContainer.viewContext.execute(batchRequest)
       } catch {
           print("Batch update failed: \(error)")
       }
   }
   ```

## Debugging Performance Issues

### Profiling Techniques
1. **Time Profiler**:
   ```swift
   func profileCriticalPath() {
       let startTime = CFAbsoluteTimeGetCurrent()
       
       // Critical operation
       performCriticalOperation()
       
       let endTime = CFAbsoluteTimeGetCurrent()
       let duration = endTime - startTime
       
       if duration > 0.1 { // 100ms threshold
           print("⚠️ Slow operation detected: \(duration)s")
       }
   }
   ```

2. **Custom Performance Metrics**:
   ```swift
   class PerformanceTracker {
       private var startTimes = [String: CFAbsoluteTime]()
       
       func startMeasuring(_ identifier: String) {
           startTimes[identifier] = CFAbsoluteTimeGetCurrent()
       }
       
       func endMeasuring(_ identifier: String) {
           guard let startTime = startTimes.removeValue(forKey: identifier) else {
               return
           }
           
           let duration = CFAbsoluteTimeGetCurrent() - startTime
           logPerformance(identifier: identifier, duration: duration)
       }
       
       private func logPerformance(identifier: String, duration: CFAbsoluteTime) {
           let category = categorizePerformance(duration: duration)
           print("📊 \(identifier): \(duration)s [\(category)]")
       }
       
       private func categorizePerformance(duration: CFAbsoluteTime) -> String {
           switch duration {
           case 0..<0.1: return "FAST"
           case 0.1..<0.5: return "NORMAL"
           case 0.5..<1.0: return "SLOW"
           default: return "VERY SLOW"
           }
       }
   }
   ```

### Performance Testing
```swift
class PerformanceTests: XCTestCase {
    func testThreadLoadingPerformance() {
        measure {
            // Code to measure
            let expectation = XCTestExpectation(description: "Thread loading")
            
            ForumsClient.shared.loadThread(threadID: "123") { result in
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testScrollingPerformance() {
        let tableView = UITableView()
        let dataSource = ThreadsDataSource()
        
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            
            // Simulate scrolling
            for i in 0..<100 {
                let indexPath = IndexPath(row: i, section: 0)
                _ = dataSource.tableView(tableView, cellForRowAt: indexPath)
            }
            
            stopMeasuring()
        }
    }
}
```

## Optimization Strategies

### Code-Level Optimizations
1. **Use appropriate data structures**:
   ```swift
   // Use Set for membership testing
   let validForumIDs = Set(["1", "2", "3", "4"])
   if validForumIDs.contains(forumID) {
       // Fast O(1) lookup
   }
   
   // Use Dictionary for lookups
   let threadsByID = Dictionary(uniqueKeysWithValues: threads.map { ($0.threadID, $0) })
   if let thread = threadsByID[threadID] {
       // Fast O(1) lookup
   }
   ```

2. **Optimize string operations**:
   ```swift
   // Use string interpolation instead of concatenation
   let message = "Thread \(threadID) by \(author)" // Good
   let message = "Thread " + threadID + " by " + author // Slower
   
   // Use StringBuilder for multiple concatenations
   var builder = ""
   builder.reserveCapacity(estimatedLength)
   for item in items {
       builder += item.description
   }
   ```

3. **Efficient collection operations**:
   ```swift
   // Use lazy evaluation for chained operations
   let result = threads
       .lazy
       .filter { $0.isSticky }
       .map { $0.title }
       .prefix(10)
   
   // Use reduce for aggregations
   let totalPosts = threads.reduce(0) { $0 + $1.postCount }
   ```

### Memory Optimization
1. **Implement proper cleanup**:
   ```swift
   deinit {
       // Cancel operations
       imageLoadingTask?.cancel()
       
       // Remove observers
       NotificationCenter.default.removeObserver(self)
       
       // Clean up timers
       refreshTimer?.invalidate()
   }
   ```

2. **Use weak references appropriately**:
   ```swift
   class ThreadViewController: UIViewController {
       weak var delegate: ThreadViewControllerDelegate?
       
       private var observations = [NSKeyValueObservation]()
       
       override func viewDidLoad() {
           super.viewDidLoad()
           
           // Use weak self in closures
           loadThread { [weak self] thread in
               self?.updateUI(with: thread)
           }
       }
   }
   ```

### Network Optimization
1. **Request deduplication**:
   ```swift
   class RequestDeduplicator {
       private var activeRequests = [String: URLSessionDataTask]()
       
       func performRequest(url: URL, completion: @escaping (Data?, Error?) -> Void) {
           let key = url.absoluteString
           
           if let existingTask = activeRequests[key] {
               // Request already in progress
               return
           }
           
           let task = URLSession.shared.dataTask(with: url) { data, _, error in
               self.activeRequests.removeValue(forKey: key)
               completion(data, error)
           }
           
           activeRequests[key] = task
           task.resume()
       }
   }
   ```

2. **Smart caching strategies**:
   ```swift
   class SmartCache {
       private let memoryCache = NSCache<NSString, NSData>()
       private let diskCache: DiskCache
       
       func data(for key: String) -> Data? {
           // Check memory first
           if let data = memoryCache.object(forKey: key as NSString) {
               return data as Data
           }
           
           // Check disk cache
           if let data = diskCache.data(for: key) {
               // Promote to memory cache
               memoryCache.setObject(data as NSData, forKey: key as NSString)
               return data
           }
           
           return nil
       }
   }
   ```

## Best Practices

### Performance Guidelines
1. **Measure Before Optimizing**: Always profile before making changes
2. **Target Real Devices**: Test on actual hardware, not just simulator
3. **Monitor Continuously**: Implement ongoing performance monitoring
4. **Optimize Critical Paths**: Focus on user-facing operations
5. **Balance Trade-offs**: Consider memory vs. CPU vs. battery usage

### Development Practices
1. **Async Programming**: Use async/await for better performance
2. **Background Processing**: Move heavy work off main thread
3. **Lazy Loading**: Load resources only when needed
4. **Resource Management**: Properly manage memory and resources
5. **Testing**: Include performance tests in test suite