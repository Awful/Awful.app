# Performance Optimization

## Overview

Awful.app's Core Data performance optimizations ensure smooth operation with large forum datasets while maintaining responsive UI. These optimizations have been refined over 20 years to handle thousands of threads, hundreds of thousands of posts, and complex relationship queries efficiently.

## Performance Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Performance Layer                            │
├─────────────────────────────────────────────────────────────────┤
│  Query Optimization                                             │
│  ├─ Fetch Request Optimization                                 │
│  ├─ Predicate Optimization                                     │
│  ├─ Relationship Prefetching                                   │
│  └─ Batch Operations                                           │
├─────────────────────────────────────────────────────────────────┤
│  Memory Management                                              │
│  ├─ Fault Management                                           │
│  ├─ Object Lifecycle                                           │
│  ├─ Cache Control                                              │
│  └─ Memory Pressure Handling                                   │
├─────────────────────────────────────────────────────────────────┤
│  Persistence Optimization                                       │
│  ├─ SQLite Configuration                                       │
│  ├─ Index Strategy                                             │
│  ├─ Write Optimization                                         │
│  └─ Vacuum and Maintenance                                     │
└─────────────────────────────────────────────────────────────────┘
```

## Query Optimization

### 1. Fetch Request Optimization

Optimized fetch requests form the foundation of performance:

```swift
// OptimizedQueries.swift - Fetch request optimization
extension NSFetchRequest {
    static func optimizedThreadFetch(for forum: Forum) -> NSFetchRequest<Thread> {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        
        // Specific predicate to limit dataset
        request.predicate = NSPredicate(format: "forum == %@", forum)
        
        // Efficient sorting with compound sort
        request.sortDescriptors = [
            NSSortDescriptor(key: "isSticky", ascending: false),
            NSSortDescriptor(key: "lastPostDate", ascending: false)
        ]
        
        // Pagination to limit memory usage
        request.fetchLimit = 50
        request.fetchOffset = 0
        
        // Pre-fetch critical relationships
        request.relationshipKeyPathsForPrefetching = [
            "author",
            "threadTag",
            "forum"
        ]
        
        // Optimize object creation
        request.returnsObjectsAsFaults = true
        request.includesPendingChanges = false
        request.includesSubentities = false
        
        // Batch fetching for related objects
        request.fetchBatchSize = 20
        
        return request
    }
    
    static func optimizedPostFetch(for thread: Thread, page: Int) -> NSFetchRequest<Post> {
        let request: NSFetchRequest<Post> = Post.fetchRequest()
        
        // Specific thread predicate
        request.predicate = NSPredicate(format: "thread == %@", thread)
        
        // Sort by post index for thread order
        request.sortDescriptors = [
            NSSortDescriptor(key: "postIndex", ascending: true)
        ]
        
        // Pagination (40 posts per page)
        let postsPerPage = 40
        request.fetchLimit = postsPerPage
        request.fetchOffset = page * postsPerPage
        
        // Pre-fetch author relationship
        request.relationshipKeyPathsForPrefetching = ["author"]
        
        // Return as faults for memory efficiency
        request.returnsObjectsAsFaults = true
        request.fetchBatchSize = 20
        
        return request
    }
}
```

### 2. Predicate Optimization

Efficient predicates reduce database scanning:

```swift
// PredicateOptimization.swift - Optimized predicate patterns
extension NSPredicate {
    
    // Use indexed fields for fast lookups
    static func threadByID(_ threadID: String) -> NSPredicate {
        return NSPredicate(format: "threadID == %@", threadID)
    }
    
    // Compound predicates for complex queries
    static func unreadBookmarkedThreads(for userID: String) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isBookmarked == YES"),
            NSPredicate(format: "totalUnreadPosts > 0"),
            NSPredicate(format: "ANY bookmarkedBy.userID == %@", userID)
        ])
    }
    
    // Optimized date range queries
    static func recentThreads(within timeInterval: TimeInterval) -> NSPredicate {
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        return NSPredicate(format: "lastPostDate >= %@", cutoffDate as NSDate)
    }
    
    // Use subqueries for complex relationship filtering
    static func forumsWithRecentActivity() -> NSPredicate {
        return NSPredicate(format: 
            "SUBQUERY(threads, $thread, $thread.lastPostDate >= %@).@count > 0",
            Date().addingTimeInterval(-7 * 24 * 60 * 60) as NSDate
        )
    }
    
    // Optimize string searches
    static func threadsMatchingTitle(_ searchText: String) -> NSPredicate {
        // Use CONTAINS[cd] for case-insensitive search
        return NSPredicate(format: "title CONTAINS[cd] %@", searchText)
    }
    
    // Avoid expensive operations in predicates
    static func avoidExpensiveOperations() {
        // ❌ Avoid: function calls in predicates
        // NSPredicate(format: "FUNCTION(title, 'length') > 50")
        
        // ✅ Better: simple comparisons
        // NSPredicate(format: "title.length > 50")
        
        // ❌ Avoid: complex string operations
        // NSPredicate(format: "title MATCHES '.*[Aa]wful.*'")
        
        // ✅ Better: simple string operations
        // NSPredicate(format: "title CONTAINS[cd] 'awful'")
    }
}
```

### 3. Relationship Prefetching Strategy

Strategic prefetching prevents N+1 query problems:

```swift
// PrefetchingStrategy.swift - Relationship prefetching optimization
class PrefetchingStrategy {
    
    static func optimizeThreadListFetch() -> NSFetchRequest<Thread> {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        
        // Pre-fetch frequently accessed relationships
        request.relationshipKeyPathsForPrefetching = [
            "author",           // Thread author
            "threadTag",        // Thread category icon
            "forum",            // Parent forum
            "forum.category"    // Forum category (for breadcrumbs)
        ]
        
        // Don't pre-fetch heavy relationships
        // "posts" - Too many posts, fetch separately
        // "posts.author" - Would load all post authors
        
        return request
    }
    
    static func optimizePostListFetch() -> NSFetchRequest<Post> {
        let request: NSFetchRequest<Post> = Post.fetchRequest()
        
        // Pre-fetch post authors only
        request.relationshipKeyPathsForPrefetching = [
            "author"            // Post author
        ]
        
        // Don't pre-fetch thread - already loaded
        // Don't pre-fetch thread.forum - not needed for post display
        
        return request
    }
    
    static func optimizeForumHierarchyFetch() -> NSFetchRequest<Forum> {
        let request: NSFetchRequest<Forum> = Forum.fetchRequest()
        
        // Pre-fetch forum hierarchy relationships
        request.relationshipKeyPathsForPrefetching = [
            "category",         // Forum category
            "parentForum",      // Parent forum
            "childForums"       // Child forums (for hierarchy display)
        ]
        
        // Don't pre-fetch threads - too many
        
        return request
    }
}
```

### 4. Batch Operations

Efficient batch operations for bulk data changes:

```swift
// BatchOperations.swift - Optimized batch processing
extension NSManagedObjectContext {
    
    func performOptimizedBatchUpdate<T: NSManagedObject>(
        entity: T.Type,
        predicate: NSPredicate?,
        propertiesToUpdate: [String: Any],
        updateRequestBlock: ((NSBatchUpdateRequest) -> Void)? = nil
    ) throws -> NSBatchUpdateResult {
        
        let batchRequest = NSBatchUpdateRequest(entity: T.entity())
        batchRequest.predicate = predicate
        batchRequest.propertiesToUpdate = propertiesToUpdate
        batchRequest.resultType = .updatedObjectIDsResultType
        
        // Allow custom configuration
        updateRequestBlock?(batchRequest)
        
        let result = try execute(batchRequest) as! NSBatchUpdateResult
        
        // Efficiently merge changes
        if let objectIDs = result.result as? [NSManagedObjectID] {
            let changes = [NSUpdatedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
        }
        
        return result
    }
    
    func performOptimizedBatchDelete<T: NSManagedObject>(
        entity: T.Type,
        predicate: NSPredicate?
    ) throws -> NSBatchDeleteResult {
        
        let fetchRequest = T.fetchRequest()
        fetchRequest.predicate = predicate
        
        let batchRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchRequest.resultType = .resultTypeObjectIDs
        
        let result = try execute(batchRequest) as! NSBatchDeleteResult
        
        // Efficiently merge deletions
        if let objectIDs = result.result as? [NSManagedObjectID] {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
        }
        
        return result
    }
    
    // Batch update example: Mark threads as read
    func markThreadsAsRead(in forum: Forum) throws {
        try performOptimizedBatchUpdate(
            entity: Thread.self,
            predicate: NSPredicate(format: "forum == %@ AND totalUnreadPosts > 0", forum),
            propertiesToUpdate: [
                "totalUnreadPosts": 0,
                "seenPosts": "numberOfPosts"
            ]
        )
    }
    
    // Batch delete example: Remove old posts
    func removeOldPosts(olderThan date: Date) throws {
        try performOptimizedBatchDelete(
            entity: Post.self,
            predicate: NSPredicate(format: "postDate < %@", date as NSDate)
        )
    }
}
```

## Memory Management

### 1. Fault Management

Strategic fault handling prevents memory bloat:

```swift
// FaultManagement.swift - Optimized fault handling
extension NSManagedObject {
    
    func refreshToFault() {
        guard !isFault else { return }
        managedObjectContext?.refresh(self, mergeChanges: false)
    }
    
    func ensureFaultStatus(for keyPath: String) {
        guard let context = managedObjectContext else { return }
        
        // Convert related objects to faults if not needed
        if let relatedObject = value(forKey: keyPath) as? NSManagedObject,
           !relatedObject.isFault {
            context.refresh(relatedObject, mergeChanges: false)
        }
    }
}

extension NSManagedObjectContext {
    
    func refreshAllObjectsToFaults() {
        // Refresh all objects to faults to free memory
        registeredObjects.forEach { object in
            refresh(object, mergeChanges: false)
        }
    }
    
    func refreshLargeObjectsToFaults() {
        // Identify and fault large objects (posts with content)
        let largeObjects = registeredObjects.filter { object in
            if let post = object as? Post {
                return post.innerHTML?.count ?? 0 > 10000
            }
            return false
        }
        
        largeObjects.forEach { object in
            refresh(object, mergeChanges: false)
        }
    }
    
    func maintainMemoryFootprint() {
        // Keep memory usage reasonable
        let registeredCount = registeredObjects.count
        
        if registeredCount > 1000 {
            logger.warning("High object count: \(registeredCount), refreshing to faults")
            refreshAllObjectsToFaults()
        }
    }
}
```

### 2. Object Lifecycle Management

Efficient object lifecycle prevents memory leaks:

```swift
// ObjectLifecycleManager.swift - Object lifecycle optimization
class ObjectLifecycleManager {
    private weak var context: NSManagedObjectContext?
    private var objectObservations: [NSManagedObjectID: NSKeyValueObservation] = [:]
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupMemoryPressureHandling()
    }
    
    private func setupMemoryPressureHandling() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryPressure()
        }
    }
    
    private func handleMemoryPressure() {
        guard let context = context else { return }
        
        logger.info("Handling memory pressure - refreshing objects to faults")
        
        // Remove object observations to prevent retain cycles
        objectObservations.removeAll()
        
        // Refresh all objects to faults
        context.refreshAllObjectsToFaults()
        
        // Reset context if safe
        if !context.hasChanges {
            context.reset()
        }
    }
    
    func optimizeForLargeDataset() {
        guard let context = context else { return }
        
        // Set reasonable batch sizes
        context.stalenessInterval = 0.0
        
        // Configure merge policy for performance
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        // Set undo manager to nil for better performance
        context.undoManager = nil
    }
}
```

### 3. Cache Management

Intelligent caching strategies for optimal performance:

```swift
// CacheManager.swift - Intelligent cache management
class CacheManager {
    private let context: NSManagedObjectContext
    private var objectCache: NSCache<NSString, NSManagedObject>
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.objectCache = NSCache<NSString, NSManagedObject>()
        
        // Configure cache limits
        objectCache.countLimit = 500
        objectCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        setupCacheManagement()
    }
    
    private func setupCacheManagement() {
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectCache.removeAllObjects()
        }
        
        // Monitor context changes
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: context,
            queue: .main
        ) { [weak self] notification in
            self?.updateCacheFromContextChanges(notification)
        }
    }
    
    private func updateCacheFromContextChanges(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        // Remove deleted objects from cache
        if let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> {
            for object in deletedObjects {
                let key = cacheKey(for: object)
                objectCache.removeObject(forKey: key)
            }
        }
        
        // Update cached objects
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            for object in updatedObjects {
                let key = cacheKey(for: object)
                let cost = calculateObjectCost(object)
                objectCache.setObject(object, forKey: key, cost: cost)
            }
        }
    }
    
    private func cacheKey(for object: NSManagedObject) -> NSString {
        return "\(object.entity.name!):\(object.objectID.uriRepresentation().absoluteString)" as NSString
    }
    
    private func calculateObjectCost(_ object: NSManagedObject) -> Int {
        // Estimate memory cost of object
        switch object {
        case let post as Post:
            return (post.innerHTML?.count ?? 0) + (post.text?.count ?? 0)
        case let thread as Thread:
            return thread.title.count + 100 // Base overhead
        default:
            return 100 // Default cost
        }
    }
}
```

## Persistence Optimization

### 1. SQLite Configuration

Optimize SQLite for Core Data performance:

```swift
// SQLiteOptimization.swift - SQLite configuration
extension DataStore {
    
    private func configureSQLiteOptions() -> [String: Any] {
        var options: [String: Any] = [
            // Enable automatic migration
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            
            // SQLite-specific optimizations
            NSSQLitePragmasOption: [
                "journal_mode": "WAL",          // Write-Ahead Logging for better concurrency
                "synchronous": "NORMAL",        // Balance between safety and performance
                "cache_size": "10000",          // Larger cache for better performance
                "temp_store": "MEMORY",         // Use memory for temporary storage
                "mmap_size": "268435456",       // Memory-mapped I/O (256MB)
                "foreign_keys": "ON"            // Enable foreign key constraints
            ]
        ]
        
        // Add vacuum configuration
        if shouldPerformVacuum() {
            options[NSSQLiteManualVacuumOption] = true
        }
        
        return options
    }
    
    private func shouldPerformVacuum() -> Bool {
        // Vacuum database periodically to reclaim space
        let lastVacuum = UserDefaults.standard.object(forKey: "LastVacuumDate") as? Date ?? Date.distantPast
        let daysSinceVacuum = Date().timeIntervalSince(lastVacuum) / (24 * 60 * 60)
        
        return daysSinceVacuum > 7 // Vacuum weekly
    }
    
    func performManualVacuum() {
        guard let store = persistentStore,
              let storeURL = store.url else { return }
        
        // Perform vacuum operation
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: Self.model)
        
        do {
            let tempStore = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: [NSSQLiteManualVacuumOption: true]
            )
            
            try coordinator.remove(tempStore)
            
            // Update last vacuum date
            UserDefaults.standard.set(Date(), forKey: "LastVacuumDate")
            
            logger.info("Database vacuum completed successfully")
            
        } catch {
            logger.error("Failed to vacuum database: \(error)")
        }
    }
}
```

### 2. Index Strategy

Strategic indexing for query performance:

```swift
// IndexStrategy.swift - Database indexing strategy
extension DataStore {
    
    func createPerformanceIndexes() {
        // Note: Core Data automatically creates indexes for:
        // - Primary keys (objectID)
        // - Foreign keys (relationships)
        // - Attributes marked as "Indexed" in the model
        
        // Custom indexes can be created via SQLite directly if needed
        executeSQLiteStatement("CREATE INDEX IF NOT EXISTS idx_thread_lastpost ON ZTHREAD (ZLASTPOSTDATE DESC)")
        executeSQLiteStatement("CREATE INDEX IF NOT EXISTS idx_post_thread_index ON ZPOST (ZTHREAD, ZPOSTINDEX)")
        executeSQLiteStatement("CREATE INDEX IF NOT EXISTS idx_thread_forum_sticky ON ZTHREAD (ZFORUM, ZISSTICKY DESC, ZLASTPOSTDATE DESC)")
        executeSQLiteStatement("CREATE INDEX IF NOT EXISTS idx_user_username ON ZUSER (ZUSERNAME)")
    }
    
    private func executeSQLiteStatement(_ sql: String) {
        guard let storeURL = persistentStore?.url else { return }
        
        var database: OpaquePointer?
        
        if sqlite3_open(storeURL.path, &database) == SQLITE_OK {
            if sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK {
                logger.info("Successfully executed SQL: \(sql)")
            } else {
                logger.error("Failed to execute SQL: \(sql)")
            }
        }
        
        sqlite3_close(database)
    }
    
    func analyzeQueryPerformance() {
        // Enable SQLite query analysis
        executeSQLiteStatement("PRAGMA optimize")
        
        // Log slow queries (requires custom logging)
        #if DEBUG
        enableSlowQueryLogging()
        #endif
    }
    
    #if DEBUG
    private func enableSlowQueryLogging() {
        // Custom implementation to log slow Core Data queries
        // This would require method swizzling or other advanced techniques
    }
    #endif
}
```

### 3. Write Optimization

Optimize write operations for better performance:

```swift
// WriteOptimization.swift - Write operation optimization
extension NSManagedObjectContext {
    
    func performOptimizedSave() throws {
        guard hasChanges else { return }
        
        // Disable undo tracking during save
        let originalUndoManager = undoManager
        undoManager = nil
        
        defer {
            undoManager = originalUndoManager
        }
        
        // Perform save with retry logic
        var attempt = 0
        let maxAttempts = 3
        
        while attempt < maxAttempts {
            do {
                try save()
                return
            } catch let error as NSError {
                attempt += 1
                
                if attempt < maxAttempts && isRetryableError(error) {
                    // Wait before retry
                    Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
                    continue
                }
                
                throw error
            }
        }
    }
    
    private func isRetryableError(_ error: NSError) -> Bool {
        // Check if error is retryable
        switch error.code {
        case NSManagedObjectContextLockingError,
             NSSQLiteBusyError:
            return true
        default:
            return false
        }
    }
    
    func performBatchedSave(batchSize: Int = 100) throws {
        guard hasChanges else { return }
        
        let insertedObjects = Array(self.insertedObjects)
        let updatedObjects = Array(self.updatedObjects)
        
        // Process in batches to avoid memory spikes
        for batch in insertedObjects.chunked(into: batchSize) {
            // Save batch
            try performOptimizedSave()
            
            // Refresh objects to faults to free memory
            batch.forEach { object in
                refresh(object, mergeChanges: false)
            }
        }
        
        for batch in updatedObjects.chunked(into: batchSize) {
            try performOptimizedSave()
            
            batch.forEach { object in
                refresh(object, mergeChanges: false)
            }
        }
    }
}
```

## Performance Monitoring

### 1. Performance Metrics Collection

Monitor Core Data performance in production:

```swift
// PerformanceMonitor.swift - Performance monitoring
class CoreDataPerformanceMonitor {
    private let startTime = CFAbsoluteTimeGetCurrent()
    private var queryMetrics: [String: QueryMetrics] = [:]
    
    struct QueryMetrics {
        var totalTime: TimeInterval = 0
        var queryCount: Int = 0
        var maxTime: TimeInterval = 0
        var minTime: TimeInterval = .greatestFiniteMagnitude
        
        mutating func recordQuery(duration: TimeInterval) {
            totalTime += duration
            queryCount += 1
            maxTime = max(maxTime, duration)
            minTime = min(minTime, duration)
        }
        
        var averageTime: TimeInterval {
            return queryCount > 0 ? totalTime / Double(queryCount) : 0
        }
    }
    
    func trackFetchRequest<T>(_ request: NSFetchRequest<T>, in context: NSManagedObjectContext) -> [T] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let results = try context.fetch(request)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            recordQueryMetrics(for: request, duration: duration, resultCount: results.count)
            
            return results
        } catch {
            logger.error("Fetch request failed: \(error)")
            return []
        }
    }
    
    private func recordQueryMetrics<T>(for request: NSFetchRequest<T>, duration: TimeInterval, resultCount: Int) {
        let entityName = request.entityName ?? "Unknown"
        
        var metrics = queryMetrics[entityName] ?? QueryMetrics()
        metrics.recordQuery(duration: duration)
        queryMetrics[entityName] = metrics
        
        // Log slow queries
        if duration > 1.0 {
            logger.warning("Slow query detected: \(entityName) took \(duration)s for \(resultCount) results")
        }
        
        // Log performance summary periodically
        if metrics.queryCount % 100 == 0 {
            logPerformanceSummary(for: entityName, metrics: metrics)
        }
    }
    
    private func logPerformanceSummary(for entityName: String, metrics: QueryMetrics) {
        logger.info("""
            Performance Summary for \(entityName):
            - Total queries: \(metrics.queryCount)
            - Average time: \(String(format: "%.3f", metrics.averageTime))s
            - Max time: \(String(format: "%.3f", metrics.maxTime))s
            - Min time: \(String(format: "%.3f", metrics.minTime))s
            """)
    }
    
    func generatePerformanceReport() -> String {
        var report = "Core Data Performance Report\n"
        report += "===========================\n\n"
        
        for (entityName, metrics) in queryMetrics.sorted(by: { $0.value.averageTime > $1.value.averageTime }) {
            report += "\(entityName):\n"
            report += "  Queries: \(metrics.queryCount)\n"
            report += "  Average: \(String(format: "%.3f", metrics.averageTime))s\n"
            report += "  Max: \(String(format: "%.3f", metrics.maxTime))s\n"
            report += "  Total: \(String(format: "%.3f", metrics.totalTime))s\n\n"
        }
        
        return report
    }
}
```

### 2. Memory Usage Tracking

Monitor memory usage patterns:

```swift
// MemoryTracker.swift - Memory usage monitoring
class MemoryTracker {
    private var samples: [MemorySample] = []
    
    struct MemorySample {
        let timestamp: Date
        let memoryUsage: UInt64
        let objectCount: Int
        let contextDescription: String
    }
    
    func recordMemorySample(for context: NSManagedObjectContext, description: String = "") {
        let memoryUsage = getCurrentMemoryUsage()
        let objectCount = context.registeredObjects.count
        
        let sample = MemorySample(
            timestamp: Date(),
            memoryUsage: memoryUsage,
            objectCount: objectCount,
            contextDescription: description
        )
        
        samples.append(sample)
        
        // Keep only recent samples
        if samples.count > 1000 {
            samples.removeFirst(samples.count - 1000)
        }
        
        // Alert on high memory usage
        if memoryUsage > 200 * 1024 * 1024 { // 200MB
            logger.warning("High memory usage: \(memoryUsage / 1024 / 1024)MB with \(objectCount) objects")
        }
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    func generateMemoryReport() -> String {
        guard !samples.isEmpty else { return "No memory samples recorded" }
        
        let maxMemory = samples.max { $0.memoryUsage < $1.memoryUsage }!
        let maxObjects = samples.max { $0.objectCount < $1.objectCount }!
        let avgMemory = samples.reduce(0) { $0 + $1.memoryUsage } / UInt64(samples.count)
        
        return """
            Memory Usage Report
            ==================
            
            Peak Memory: \(maxMemory.memoryUsage / 1024 / 1024)MB at \(maxMemory.timestamp)
            Peak Objects: \(maxObjects.objectCount) at \(maxObjects.timestamp)
            Average Memory: \(avgMemory / 1024 / 1024)MB
            
            Recent samples: \(samples.suffix(10).map { "\($0.memoryUsage / 1024 / 1024)MB" }.joined(separator: ", "))
            """
    }
}
```

## SwiftUI Integration Optimizations

### 1. @FetchRequest Optimization

Optimize SwiftUI @FetchRequest usage:

```swift
// SwiftUIOptimizations.swift - SwiftUI Core Data optimization
struct OptimizedThreadListView: View {
    let forum: Forum
    
    // Optimized fetch request with proper configuration
    @FetchRequest private var threads: FetchedResults<Thread>
    
    init(forum: Forum) {
        self.forum = forum
        
        // Configure optimized fetch request
        _threads = FetchRequest(
            entity: Thread.entity(),
            sortDescriptors: [
                NSSortDescriptor(key: "isSticky", ascending: false),
                NSSortDescriptor(key: "lastPostDate", ascending: false)
            ],
            predicate: NSPredicate(format: "forum == %@", forum),
            animation: .default
        )
    }
    
    var body: some View {
        List {
            // Use LazyVStack for better performance with large lists
            LazyVStack(spacing: 0) {
                ForEach(threads) { thread in
                    ThreadRowView(thread: thread)
                        .onAppear {
                            // Pre-load related data when needed
                            preloadThreadDataIfNeeded(thread)
                        }
                }
            }
        }
        .refreshable {
            await refreshThreads()
        }
    }
    
    private func preloadThreadDataIfNeeded(_ thread: Thread) {
        // Ensure critical relationships are loaded
        _ = thread.author?.username
        _ = thread.threadTag?.imageName
    }
    
    private func refreshThreads() async {
        // Implement refresh logic
        do {
            try await ForumsClient.shared.loadThreads(in: forum)
        } catch {
            logger.error("Failed to refresh threads: \(error)")
        }
    }
}
```

### 2. Performance-Optimized Data Sources

Create optimized data sources for SwiftUI:

```swift
// OptimizedDataSource.swift - Performance-optimized SwiftUI data source
@MainActor
class OptimizedThreadDataSource: ObservableObject {
    @Published var threads: [Thread] = []
    @Published var isLoading = false
    
    private let forum: Forum
    private let context: NSManagedObjectContext
    private let performanceMonitor = CoreDataPerformanceMonitor()
    
    private var currentPage = 0
    private let pageSize = 50
    
    init(forum: Forum, context: NSManagedObjectContext) {
        self.forum = forum
        self.context = context
        loadInitialData()
    }
    
    private func loadInitialData() {
        let request = createOptimizedRequest()
        request.fetchLimit = pageSize
        request.fetchOffset = 0
        
        threads = performanceMonitor.trackFetchRequest(request, in: context)
    }
    
    func loadMoreThreads() {
        guard !isLoading else { return }
        
        isLoading = true
        currentPage += 1
        
        Task {
            let request = createOptimizedRequest()
            request.fetchLimit = pageSize
            request.fetchOffset = currentPage * pageSize
            
            let newThreads = performanceMonitor.trackFetchRequest(request, in: context)
            
            await MainActor.run {
                threads.append(contentsOf: newThreads)
                isLoading = false
            }
        }
    }
    
    private func createOptimizedRequest() -> NSFetchRequest<Thread> {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        
        request.predicate = NSPredicate(format: "forum == %@", forum)
        request.sortDescriptors = [
            NSSortDescriptor(key: "isSticky", ascending: false),
            NSSortDescriptor(key: "lastPostDate", ascending: false)
        ]
        
        // Performance optimizations
        request.relationshipKeyPathsForPrefetching = ["author", "threadTag"]
        request.returnsObjectsAsFaults = true
        request.fetchBatchSize = 20
        
        return request
    }
}
```

## Testing Performance

### 1. Performance Test Suite

Comprehensive performance testing:

```swift
// PerformanceTests.swift - Performance testing suite
class CoreDataPerformanceTests: XCTestCase {
    var testContext: NSManagedObjectContext!
    var performanceMonitor: CoreDataPerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        
        // Set up test context with large dataset
        testContext = createTestContext()
        performanceMonitor = CoreDataPerformanceMonitor()
        populateLargeTestDataset()
    }
    
    func testThreadFetchPerformance() {
        measure {
            let request = NSFetchRequest<Thread>.optimizedThreadFetch(for: testForum)
            _ = performanceMonitor.trackFetchRequest(request, in: testContext)
        }
    }
    
    func testPostFetchPerformance() {
        measure {
            let request = NSFetchRequest<Post>.optimizedPostFetch(for: testThread, page: 0)
            _ = performanceMonitor.trackFetchRequest(request, in: testContext)
        }
    }
    
    func testBatchUpdatePerformance() {
        measure {
            try! testContext.markThreadsAsRead(in: testForum)
        }
    }
    
    func testMemoryUsageUnderLoad() {
        let memoryTracker = MemoryTracker()
        
        // Baseline memory
        memoryTracker.recordMemorySample(for: testContext, description: "Baseline")
        
        // Load large dataset
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.fetchLimit = 1000
        let threads = try! testContext.fetch(request)
        
        memoryTracker.recordMemorySample(for: testContext, description: "After loading 1000 threads")
        
        // Access all thread properties
        for thread in threads {
            _ = thread.title
            _ = thread.author?.username
            _ = thread.posts.count
        }
        
        memoryTracker.recordMemorySample(for: testContext, description: "After accessing properties")
        
        // Verify memory usage is reasonable
        let finalSample = memoryTracker.samples.last!
        XCTAssertLessThan(finalSample.memoryUsage, 100 * 1024 * 1024) // Less than 100MB
    }
    
    private func populateLargeTestDataset() {
        // Create test data that matches production scale
        for i in 0..<100 {
            let thread = Thread.insert(into: testContext)
            thread.threadID = "test-thread-\(i)"
            thread.title = "Test Thread \(i)"
            thread.forum = testForum
            
            for j in 0..<50 {
                let post = Post.insert(into: testContext)
                post.postID = "test-post-\(i)-\(j)"
                post.postIndex = Int32(j)
                post.thread = thread
                post.innerHTML = String(repeating: "Test content ", count: 100)
            }
        }
        
        try! testContext.save()
    }
}
```

These performance optimizations ensure Awful.app maintains excellent performance while handling large forum datasets and preparing for SwiftUI migration without sacrificing responsiveness.