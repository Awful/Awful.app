# Background Processing

## Overview

Awful.app's background processing system ensures smooth user experience by handling data import, synchronization, and maintenance operations without blocking the UI thread. This system has evolved to handle large datasets efficiently while maintaining responsiveness and data integrity.

## Architecture Overview

```
Main Thread (UI)          Background Thread (Data Processing)
      │                              │
      │                              │
  User Actions              ForumsClient Background Context
      │                              │
      │                              │
NSFetchedResultsController    HTML Scraping & Import
      │                              │
      │                              │
  UI Updates  ←────────────────── Context Merging
      │                              │
      │                              │
  Responsive UI                 Data Persistence
```

## Core Components

### 1. Background Context Management

The `ForumsClient` maintains a dedicated background context for all import operations:

```swift
// ForumsClient.swift - Background context setup
public final class ForumsClient {
    private var backgroundManagedObjectContext: NSManagedObjectContext?
    private var lastModifiedObserver: LastModifiedContextObserver?
    
    public var managedObjectContext: NSManagedObjectContext? {
        didSet {
            setupBackgroundContext()
        }
    }
    
    private func setupBackgroundContext() {
        guard let mainContext = managedObjectContext else { return }
        
        // Create private queue context for background operations
        let background = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundManagedObjectContext = background
        background.persistentStoreCoordinator = mainContext.persistentStoreCoordinator
        
        // Set up context synchronization
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(backgroundManagedObjectContextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: background
        )
        
        // Add last modified date observer
        lastModifiedObserver = LastModifiedContextObserver(managedObjectContext: background)
    }
}
```

### 2. Import Operation Queue

Background operations are managed through a dedicated operation queue:

```swift
// DataStore.swift - Operation queue for background tasks
public final class DataStore {
    private var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1 // Serial execution
        queue.qualityOfService = .background
        queue.name = "com.awfulapp.data-processing"
        return queue
    }()
    
    /// Schedule background operation
    func scheduleBackgroundOperation<T>(_ operation: @escaping () throws -> T) -> Promise<T> {
        return Promise { seal in
            operationQueue.addOperation {
                do {
                    let result = try operation()
                    seal.fulfill(result)
                } catch {
                    seal.reject(error)
                }
            }
        }
    }
}
```

### 3. Context Synchronization

Changes from background context are automatically merged to main context:

```swift
// ForumsClient.swift - Context synchronization
@objc private func backgroundManagedObjectContextDidSave(_ notification: Notification) {
    guard let context = managedObjectContext else { return }
    
    // Extract updated object IDs for fault management
    let updatedObjectIDs: [NSManagedObjectID] = {
        guard
            let userInfo = notification.userInfo,
            let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>
        else { return [] }
        return updatedObjects.map { $0.objectID }
    }()
    
    // Merge changes on main context
    context.perform {
        // Refresh faults to prevent stale data
        updatedObjectIDs
            .compactMap { context.object(with: $0) }
            .forEach { $0.willAccessValue(forKey: nil) }
        
        // Apply changes from background context
        context.mergeChanges(fromContextDidSave: notification)
    }
}
```

## Background Processing Patterns

### 1. Bulk Data Import

Large datasets are processed in batches to manage memory usage:

```swift
// ThreadPersistence.swift - Bulk thread import
extension ThreadPersistence {
    static func importThreads(
        _ scrapedThreads: [ScrapedThread],
        into context: NSManagedObjectContext
    ) throws {
        context.performAndWait {
            // Process in batches to manage memory
            let batchSize = 50
            
            for batch in scrapedThreads.chunked(into: batchSize) {
                autoreleasepool {
                    // Get thread IDs for upsert operation
                    let threadIDs = batch.map { $0.threadID }
                    let upsertBatch = UpsertBatch<Thread>(
                        in: context,
                        identifiedBy: \.threadID,
                        identifiers: threadIDs
                    )
                    
                    // Process each thread in batch
                    for scrapedThread in batch {
                        let thread = upsertBatch[scrapedThread.threadID]
                        
                        // Update thread properties
                        thread.title = scrapedThread.title
                        thread.numberOfPosts = Int32(scrapedThread.postCount)
                        thread.lastPostDate = scrapedThread.lastPostDate
                        
                        // Handle relationships
                        if let forumID = scrapedThread.forumID {
                            thread.forum = ForumPersistence.getOrCreate(
                                forumID: forumID,
                                in: context
                            )
                        }
                        
                        if let authorID = scrapedThread.authorID {
                            thread.author = AuthorPersistence.getOrCreate(
                                userID: authorID,
                                username: scrapedThread.author,
                                in: context
                            )
                        }
                    }
                    
                    // Save batch
                    do {
                        try context.save()
                    } catch {
                        logger.error("Batch save failed: \(error)")
                        throw error
                    }
                }
            }
        }
    }
}
```

### 2. Incremental Synchronization

Updates are processed incrementally to minimize data transfer and processing:

```swift
// ForumsClient.swift - Incremental sync
func syncBookmarkedThreads(completion: @escaping (Result<Void, Error>) -> Void) {
    guard let backgroundContext = backgroundManagedObjectContext else {
        completion(.failure(ForumsClientError.contextNotAvailable))
        return
    }
    
    backgroundContext.perform {
        do {
            // Get bookmarked threads that need updating
            let bookmarkedThreads = self.getBookmarkedThreadsNeedingSync(in: backgroundContext)
            
            // Process threads in groups
            let syncGroup = DispatchGroup()
            var syncErrors: [Error] = []
            
            for thread in bookmarkedThreads {
                syncGroup.enter()
                
                self.syncThread(thread) { result in
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        syncErrors.append(error)
                    }
                    syncGroup.leave()
                }
            }
            
            // Wait for all sync operations
            syncGroup.notify(queue: .main) {
                if syncErrors.isEmpty {
                    completion(.success(()))
                } else {
                    completion(.failure(syncErrors.first!))
                }
            }
            
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
}
```

### 3. Background App Refresh

The system supports background app refresh for automatic updates:

```swift
// AppDelegate.swift - Background app refresh
func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    let backgroundTask = UIApplication.shared.beginBackgroundTask {
        // Background time expired
        completionHandler(.failed)
    }
    
    // Perform background sync
    ForumsClient.shared.performBackgroundSync { result in
        UIApplication.shared.endBackgroundTask(backgroundTask)
        
        switch result {
        case .success(let hasNewData):
            completionHandler(hasNewData ? .newData : .noData)
        case .failure:
            completionHandler(.failed)
        }
    }
}
```

## Cache Management

### 1. Automatic Cache Pruning

The `CachePruner` operation removes stale data to manage storage:

```swift
// CachePruner.swift - Background cache management
final class CachePruner: Operation {
    let managedObjectContext: NSManagedObjectContext
    
    override func main() {
        let context = managedObjectContext
        guard let storeCoordinator = context.persistentStoreCoordinator else { return }
        
        context.performAndWait {
            // Find entities with lastModifiedDate
            let allEntities = storeCoordinator.managedObjectModel.entities
            let prunableEntities = allEntities.filter { entity in
                entity.attributesByName["lastModifiedDate"] != nil
            }
            
            // Delete objects older than 7 days
            var components = DateComponents()
            components.day = -7
            let calendar = Calendar(identifier: .gregorian)
            let oneWeekAgo = calendar.date(byAdding: components, to: Date())!
            
            let fetchRequest: NSFetchRequest<NSManagedObjectID> = NSFetchRequest()
            fetchRequest.predicate = NSPredicate(format: "lastModifiedDate < %@", oneWeekAgo as NSDate)
            fetchRequest.resultType = .managedObjectIDResultType
            
            var candidateObjectIDs: [NSManagedObjectID] = []
            
            for entity in prunableEntities {
                fetchRequest.entity = entity
                do {
                    let result = try context.fetch(fetchRequest)
                    candidateObjectIDs.append(contentsOf: result)
                } catch {
                    logger.error("Error fetching candidates for pruning: \(error)")
                }
            }
            
            // Filter out objects that are actively in use
            let expiredObjectIDs = candidateObjectIDs.filter { objectID in
                context.registeredObject(for: objectID) == nil
            }
            
            // Delete expired objects
            for objectID in expiredObjectIDs {
                let object = context.object(with: objectID)
                context.delete(object)
            }
            
            // Save changes
            do {
                try context.save()
                logger.info("Pruned \(expiredObjectIDs.count) objects from cache")
            } catch {
                logger.error("Error saving after pruning: \(error)")
            }
        }
    }
}
```

### 2. Memory Pressure Handling

The system responds to memory pressure by reducing cache usage:

```swift
// DataStore.swift - Memory pressure handling
@objc private func applicationDidReceiveMemoryWarning(notification: Notification) {
    // Clear managed object context caches
    mainManagedObjectContext.perform {
        self.mainManagedObjectContext.refreshAllObjects()
    }
    
    // Cancel non-essential background operations
    operationQueue.operations.forEach { operation in
        if operation.queuePriority == .low {
            operation.cancel()
        }
    }
    
    // Trigger immediate cache pruning
    prune()
}
```

## Error Handling in Background Operations

### 1. Retry Mechanisms

Background operations implement intelligent retry logic:

```swift
// BackgroundOperation.swift - Retry with exponential backoff
class BackgroundOperation: Operation {
    private let maxRetries = 3
    private var retryCount = 0
    
    override func main() {
        performOperationWithRetry()
    }
    
    private func performOperationWithRetry() {
        do {
            try performOperation()
        } catch {
            if retryCount < maxRetries && isRetryableError(error) {
                retryCount += 1
                let backoffTime = pow(2.0, Double(retryCount))
                
                DispatchQueue.global().asyncAfter(deadline: .now() + backoffTime) {
                    self.performOperationWithRetry()
                }
            } else {
                handleFailure(error)
            }
        }
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        switch error {
        case let urlError as URLError:
            return urlError.code == .timedOut || urlError.code == .networkConnectionLost
        case let nsError as NSError where nsError.domain == NSCocoaErrorDomain:
            return nsError.code == NSManagedObjectContextLockingError
        default:
            return false
        }
    }
}
```

### 2. Transaction Rollback

Failed operations properly rollback changes:

```swift
// ImportOperation.swift - Transaction rollback
class ImportOperation: Operation {
    private let context: NSManagedObjectContext
    private let scrapedData: ScrapedData
    
    override func main() {
        context.performAndWait {
            // Create savepoint
            let savepoint = context.insertedObjects.union(context.updatedObjects)
            
            do {
                try processScrapedData(scrapedData)
                try context.save()
            } catch {
                // Rollback changes
                rollbackChanges(savepoint: savepoint)
                logger.error("Import failed, rolled back: \(error)")
                throw error
            }
        }
    }
    
    private func rollbackChanges(savepoint: Set<NSManagedObject>) {
        // Delete inserted objects
        for object in context.insertedObjects {
            context.delete(object)
        }
        
        // Revert updated objects
        for object in context.updatedObjects {
            context.refresh(object, mergeChanges: false)
        }
        
        // Reset context
        context.reset()
    }
}
```

## Performance Monitoring

### 1. Operation Metrics

Background operations are monitored for performance:

```swift
// PerformanceMonitor.swift - Operation monitoring
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private var operationMetrics: [String: OperationMetrics] = [:]
    
    func trackOperation<T>(
        _ name: String,
        operation: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            recordMetric(name: name, duration: duration)
        }
        
        return try operation()
    }
    
    private func recordMetric(name: String, duration: TimeInterval) {
        var metrics = operationMetrics[name] ?? OperationMetrics()
        metrics.recordDuration(duration)
        operationMetrics[name] = metrics
        
        // Log slow operations
        if duration > 5.0 {
            logger.warning("Slow operation: \(name) took \(duration)s")
        }
    }
}

struct OperationMetrics {
    private(set) var totalDuration: TimeInterval = 0
    private(set) var operationCount: Int = 0
    private(set) var maxDuration: TimeInterval = 0
    
    mutating func recordDuration(_ duration: TimeInterval) {
        totalDuration += duration
        operationCount += 1
        maxDuration = max(maxDuration, duration)
    }
    
    var averageDuration: TimeInterval {
        return operationCount > 0 ? totalDuration / Double(operationCount) : 0
    }
}
```

### 2. Memory Usage Tracking

Background operations monitor memory usage:

```swift
// MemoryMonitor.swift - Memory usage tracking
class MemoryMonitor {
    static func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        return info.resident_size
    }
    
    static func logMemoryUsage(for operation: String) {
        let memoryUsage = getCurrentMemoryUsage()
        let memoryMB = memoryUsage / 1024 / 1024
        
        logger.info("Memory usage for \(operation): \(memoryMB)MB")
        
        // Warn if memory usage is high
        if memoryMB > 200 {
            logger.warning("High memory usage detected: \(memoryMB)MB")
        }
    }
}
```

## SwiftUI Integration

### 1. Background Task Management

SwiftUI views can trigger background operations:

```swift
// ThreadListView.swift - SwiftUI background operations
struct ThreadListView: View {
    @State private var isRefreshing = false
    @StateObject private var backgroundTaskManager = BackgroundTaskManager()
    
    var body: some View {
        List(threads) { thread in
            ThreadRowView(thread: thread)
        }
        .refreshable {
            await refreshThreads()
        }
        .onAppear {
            backgroundTaskManager.startPeriodicSync()
        }
        .onDisappear {
            backgroundTaskManager.stopPeriodicSync()
        }
    }
    
    private func refreshThreads() async {
        isRefreshing = true
        
        do {
            try await backgroundTaskManager.syncThreads()
        } catch {
            logger.error("Thread sync failed: \(error)")
        }
        
        isRefreshing = false
    }
}
```

### 2. Background Task Manager

```swift
// BackgroundTaskManager.swift - SwiftUI-compatible background task management
@MainActor
class BackgroundTaskManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private var syncTimer: Timer?
    private let forumsClient = ForumsClient.shared
    
    func startPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.syncThreads()
            }
        }
    }
    
    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    func syncThreads() async throws {
        isSyncing = true
        syncError = nil
        
        do {
            try await forumsClient.syncBookmarkedThreads()
            lastSyncDate = Date()
        } catch {
            syncError = error
            throw error
        }
        
        isSyncing = false
    }
}
```

## Testing Background Operations

### 1. Unit Testing

Background operations are tested with mock contexts:

```swift
// BackgroundProcessingTests.swift - Unit tests
class BackgroundProcessingTests: XCTestCase {
    var testContext: NSManagedObjectContext!
    var backgroundContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        let container = NSPersistentContainer(name: "TestModel")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        testContext = container.viewContext
        backgroundContext = container.newBackgroundContext()
    }
    
    func testBulkImport() {
        // Given: Test data
        let scrapedThreads = createTestScrapedThreads()
        
        // When: Import in background
        let expectation = XCTestExpectation(description: "Import completion")
        
        backgroundContext.perform {
            do {
                try ThreadPersistence.importThreads(scrapedThreads, into: self.backgroundContext)
                expectation.fulfill()
            } catch {
                XCTFail("Import failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Then: Verify data persisted
        let threads = Thread.fetch(in: testContext) { _ in }
        XCTAssertEqual(threads.count, scrapedThreads.count)
    }
    
    func testContextSynchronization() {
        // Given: Background context changes
        let expectation = XCTestExpectation(description: "Context sync")
        
        backgroundContext.perform {
            let thread = Thread.insert(into: self.backgroundContext)
            thread.threadID = "test-thread"
            thread.title = "Test Thread"
            
            try! self.backgroundContext.save()
        }
        
        // When: Changes are merged
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Then: Verify changes in main context
            let threads = Thread.fetch(in: self.testContext) {
                $0.predicate = NSPredicate(format: "threadID == %@", "test-thread")
            }
            
            XCTAssertEqual(threads.count, 1)
            XCTAssertEqual(threads.first?.title, "Test Thread")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
```

### 2. Performance Testing

Background operations are tested for performance:

```swift
// PerformanceTests.swift - Performance testing
class PerformanceTests: XCTestCase {
    func testBulkImportPerformance() {
        // Given: Large dataset
        let largeDataset = createLargeTestDataset(count: 1000)
        
        // When: Measure import performance
        measure {
            backgroundContext.performAndWait {
                try! ThreadPersistence.importThreads(largeDataset, into: backgroundContext)
            }
        }
        
        // Then: Verify reasonable performance
        // XCTest will report performance metrics
    }
    
    func testMemoryUsageUnderLoad() {
        // Given: Memory baseline
        let baselineMemory = MemoryMonitor.getCurrentMemoryUsage()
        
        // When: Process large dataset
        let largeDataset = createLargeTestDataset(count: 5000)
        
        backgroundContext.performAndWait {
            try! ThreadPersistence.importThreads(largeDataset, into: backgroundContext)
        }
        
        // Then: Verify memory usage is reasonable
        let peakMemory = MemoryMonitor.getCurrentMemoryUsage()
        let memoryIncrease = peakMemory - baselineMemory
        
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024) // Less than 50MB increase
    }
}
```

## Known Issues and Limitations

### Current Issues

1. **Large Dataset Memory Spikes**: Very large imports can cause temporary memory spikes
2. **Context Merge Delays**: Heavy background processing can delay UI updates
3. **Operation Cancellation**: Some operations cannot be cleanly cancelled mid-process
4. **Error Recovery**: Complex operations may leave partial state after failure

### Mitigation Strategies

1. **Batch Processing**: All large operations are processed in batches
2. **Memory Monitoring**: Active monitoring and pressure response
3. **Graceful Degradation**: Fallback to simplified operations under pressure
4. **Transaction Management**: Proper rollback mechanisms for failed operations

### Future Improvements

1. **Async/Await**: Modernize to async/await for better error handling
2. **Combine Integration**: Use Combine for reactive background processing
3. **CloudKit Background Sync**: Add cloud synchronization
4. **SwiftData Migration**: Gradual migration to SwiftData for new features

The background processing system ensures that Awful.app remains responsive while handling complex data operations, providing a foundation for future enhancements and SwiftUI migration.