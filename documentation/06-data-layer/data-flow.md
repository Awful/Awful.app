# Data Flow

## Overview

Awful.app implements a sophisticated data flow architecture that manages the movement of data from network requests through HTML scraping to Core Data persistence, and finally to UI presentation. This system has been refined over 20 years to handle the complex requirements of forum data synchronization and offline support.

## Data Flow Architecture

```
Network Request → HTML Scraping → Background Processing → Core Data → UI Updates
      │                │                │                  │           │
      │                │                │                  │           │
   Forums API      AwfulScraping    BackgroundContext   MainContext   View Controllers
      │                │                │                  │           │
      │                │                │                  │           │
   HTTP/Cookies    HTMLReader       UpsertBatch         FRC/KVO     TableView/WebView
```

## Core Components

### 1. Network Layer (ForumsClient)

The `ForumsClient` serves as the primary interface for all network operations:

```swift
// ForumsClient.swift - Network request initiation
func loadPage(_ page: PostsPage, updatingProgress: Progress?) -> Promise<PostsPage> {
    return Promise { seal in
        // Network request configuration
        var components = URLComponents(url: baseURL.appendingPathComponent("showthread.php"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "threadid", value: page.threadID),
            URLQueryItem(name: "pagenumber", value: "\(page.pageNumber)")
        ]
        
        // Execute request with session
        let task = urlSession?.dataTask(with: components.url!) { data, response, error in
            // Handle response and pass to scraping layer
            self.processResponse(data: data, response: response, error: error, seal: seal)
        }
        task?.resume()
    }
}
```

### 2. HTML Scraping Layer (AwfulScraping)

Raw HTML responses are processed through specialized scrapers:

```swift
// PostsPageScraper.swift - HTML parsing and extraction
func scrape(_ html: String, baseURL: URL) -> ScrapedPostsPage {
    let document = HTMLDocument(string: html)
    let posts = document.nodes(matchingSelector: "table.post")
    
    return ScrapedPostsPage(
        posts: posts.compactMap { parsePost($0) },
        pageNumber: parsePageNumber(document),
        totalPages: parseTotalPages(document),
        threadInfo: parseThreadInfo(document)
    )
}
```

### 3. Background Processing (Private Queue Context)

All data import operations occur on a private queue to avoid blocking the UI:

```swift
// ForumsClient.swift - Background processing
private func processScrapedData<T>(_ scrapedData: T, completion: @escaping (Result<T, Error>) -> Void) {
    guard let backgroundContext = backgroundManagedObjectContext else { return }
    
    backgroundContext.perform {
        do {
            // Import scraped data into Core Data
            try self.importScrapedData(scrapedData, into: backgroundContext)
            
            // Save changes to persistent store
            try backgroundContext.save()
            
            // Success callback on main queue
            DispatchQueue.main.async {
                completion(.success(scrapedData))
            }
        } catch {
            // Error handling
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
}
```

### 4. Core Data Persistence Layer

The persistence layer manages data storage and retrieval:

```swift
// DataStore.swift - Core Data stack management
public final class DataStore {
    /// Main context for UI operations
    public let mainManagedObjectContext: NSManagedObjectContext
    
    /// Background context for import operations
    private var backgroundContext: NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = storeCoordinator
        return context
    }
    
    /// Context merging for cross-context updates
    private func mergeContexts(_ notification: Notification) {
        mainManagedObjectContext.perform {
            self.mainManagedObjectContext.mergeChanges(fromContextDidSave: notification)
        }
    }
}
```

### 5. UI Update Layer

View controllers observe Core Data changes and update the UI accordingly:

```swift
// ThreadsTableViewController.swift - UI updates from Core Data
class ThreadsTableViewController: UITableViewController {
    private var fetchedResultsController: NSFetchedResultsController<Thread>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFetchedResultsController()
    }
    
    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastPostDate", ascending: false)]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: DataStore.shared.mainManagedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        fetchedResultsController.delegate = self
        try! fetchedResultsController.performFetch()
    }
}
```

## Data Flow Patterns

### 1. Pull-to-Refresh Pattern

```swift
// User-initiated refresh
@objc private func refreshControlActivated() {
    ForumsClient.shared.loadThreads(in: forum) { result in
        DispatchQueue.main.async {
            self.refreshControl?.endRefreshing()
            
            switch result {
            case .success:
                // Data automatically updates through FRC
                break
            case .failure(let error):
                self.presentError(error)
            }
        }
    }
}
```

### 2. Background Sync Pattern

```swift
// Automatic background synchronization
private func performBackgroundSync() {
    let backgroundTask = UIApplication.shared.beginBackgroundTask { }
    
    ForumsClient.shared.syncBookmarkedThreads { result in
        UIApplication.shared.endBackgroundTask(backgroundTask)
        
        // UI updates happen automatically through context merging
        // No explicit UI refresh needed
    }
}
```

### 3. Incremental Loading Pattern

```swift
// Pagination and incremental data loading
func loadMorePosts() {
    guard !isLoadingMore else { return }
    isLoadingMore = true
    
    ForumsClient.shared.loadPage(currentPage + 1, for: thread) { result in
        self.isLoadingMore = false
        
        switch result {
        case .success(let page):
            // New posts automatically appear through FRC
            self.currentPage = page.pageNumber
        case .failure(let error):
            self.presentError(error)
        }
    }
}
```

## Context Management Strategy

### Main Context (UI Thread)
- **Purpose**: UI binding and user interactions
- **Thread**: Main queue only
- **Operations**: Fetching for display, user edits, immediate updates
- **Characteristics**: Read-heavy, low-latency requirements

### Background Context (Private Queue)
- **Purpose**: Network data import and heavy processing
- **Thread**: Private background queue
- **Operations**: Bulk imports, complex transformations, cache management
- **Characteristics**: Write-heavy, can block without affecting UI

### Context Synchronization
```swift
// Automatic context merging
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

## Data Import Strategies

### 1. Upsert Operations

The `UpsertBatch` class efficiently handles bulk insert/update operations:

```swift
// UpsertBatch.swift - Efficient bulk operations
class UpsertBatch<T: NSManagedObject & Managed> {
    private let context: NSManagedObjectContext
    private let idKeyPath: WritableKeyPath<T, String>
    private var objects: [String: T]
    
    init(in context: NSManagedObjectContext, identifiedBy keyPath: WritableKeyPath<T, String>, identifiers: [String]) {
        self.context = context
        self.idKeyPath = keyPath
        
        // Pre-fetch existing objects to avoid duplicates
        objects = .init(uniqueKeysWithValues:
            T.fetch(in: context) {
                $0.predicate = .init("\(keyPath) IN \(identifiers)")
                $0.returnsObjectsAsFaults = false
            }.map { ($0[keyPath: keyPath], $0) }
        )
    }
    
    subscript(_ id: String) -> T {
        if let object = objects[id] {
            return object
        } else {
            var object = T.insert(into: context)
            object[keyPath: idKeyPath] = id
            objects[id] = object
            return object
        }
    }
}
```

### 2. Batch Processing Pattern

```swift
// Efficient batch processing for large datasets
private func importPosts(_ scrapedPosts: [ScrapedPost], into context: NSManagedObjectContext) {
    let postIDs = scrapedPosts.map { $0.postID }
    let upsertBatch = UpsertBatch<Post>(in: context, identifiedBy: \.postID, identifiers: postIDs)
    
    for scrapedPost in scrapedPosts {
        let post = upsertBatch[scrapedPost.postID]
        
        // Update post properties
        post.innerHTML = scrapedPost.innerHTML
        post.postDate = scrapedPost.postDate
        post.author = getOrCreateUser(scrapedPost.author, in: context)
        
        // Handle relationships
        post.thread = getThread(scrapedPost.threadID, in: context)
    }
}
```

### 3. Relationship Management

```swift
// Complex relationship handling during import
private func updateThreadRelationships(_ thread: Thread, with scrapedData: ScrapedThread) {
    // Update simple properties
    thread.title = scrapedData.title
    thread.numberOfPosts = Int32(scrapedData.postCount)
    
    // Handle forum relationship
    if let forumID = scrapedData.forumID {
        thread.forum = getOrCreateForum(forumID, in: thread.managedObjectContext!)
    }
    
    // Handle thread tag relationship
    if let threadTagID = scrapedData.threadTagID {
        thread.threadTag = getOrCreateThreadTag(threadTagID, in: thread.managedObjectContext!)
    }
    
    // Update user relationships
    if let authorID = scrapedData.authorID {
        thread.author = getOrCreateUser(authorID, in: thread.managedObjectContext!)
    }
}
```

## Error Handling and Recovery

### Network Error Handling
```swift
// Robust error handling throughout the data flow
func handleNetworkError(_ error: Error, for operation: String) {
    switch error {
    case let urlError as URLError:
        switch urlError.code {
        case .notConnectedToInternet:
            // Enable offline mode
            enableOfflineMode()
        case .timedOut:
            // Retry with exponential backoff
            scheduleRetry(for: operation)
        default:
            // Log and present error
            logger.error("Network error for \(operation): \(error)")
            presentError(error)
        }
    case let scrapingError as ScrapingError:
        // Handle HTML parsing errors
        logger.error("Scraping error for \(operation): \(error)")
        reportScrapingError(scrapingError)
    default:
        // Generic error handling
        logger.error("Unknown error for \(operation): \(error)")
        presentError(error)
    }
}
```

### Core Data Error Recovery
```swift
// Core Data error handling and recovery
private func handleCoreDataError(_ error: Error, context: NSManagedObjectContext) {
    if let coreDataError = error as NSError? {
        switch coreDataError.code {
        case NSManagedObjectContextLockingError:
            // Context threading violation
            logger.error("Context threading error: \(error)")
            assertionFailure("Core Data threading violation")
            
        case NSManagedObjectMergeError:
            // Merge conflict resolution
            logger.warning("Merge conflict: \(error)")
            resolveConflict(context: context)
            
        case NSValidationMissingMandatoryPropertyError:
            // Data validation error
            logger.error("Validation error: \(error)")
            rollbackChanges(context: context)
            
        default:
            logger.error("Core Data error: \(error)")
            rollbackChanges(context: context)
        }
    }
}
```

## Performance Optimization

### 1. Fetch Request Optimization

```swift
// Optimized fetch requests for better performance
private func optimizedThreadFetch(for forum: Forum) -> NSFetchRequest<Thread> {
    let request: NSFetchRequest<Thread> = Thread.fetchRequest()
    
    // Specific predicate to limit results
    request.predicate = NSPredicate(format: "forum == %@", forum)
    
    // Efficient sorting
    request.sortDescriptors = [NSSortDescriptor(key: "lastPostDate", ascending: false)]
    
    // Limit results for pagination
    request.fetchLimit = 50
    
    // Pre-fetch related objects
    request.relationshipKeyPathsForPrefetching = ["author", "threadTag"]
    
    // Return as faults for memory efficiency
    request.returnsObjectsAsFaults = true
    
    return request
}
```

### 2. Memory Management

```swift
// Efficient memory management during data processing
private func processLargeDataSet(_ data: [ScrapedData]) {
    let batchSize = 100
    
    for batch in data.chunked(into: batchSize) {
        autoreleasepool {
            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            context.persistentStoreCoordinator = mainContext.persistentStoreCoordinator
            
            context.performAndWait {
                processBatch(batch, in: context)
                
                do {
                    try context.save()
                    context.reset() // Free memory
                } catch {
                    logger.error("Batch save error: \(error)")
                }
            }
        }
    }
}
```

### 3. Cache Management

```swift
// Intelligent cache management for optimal performance
private func manageCacheSize() {
    let cacheSize = getCurrentCacheSize()
    let maxCacheSize = 100 * 1024 * 1024 // 100MB
    
    if cacheSize > maxCacheSize {
        // Trigger cache pruning
        DataStore.shared.prune()
        
        // Force memory cleanup
        mainContext.perform {
            mainContext.refreshAllObjects()
        }
    }
}
```

## SwiftUI Migration Considerations

### 1. @FetchRequest Integration

```swift
// SwiftUI view with Core Data integration
struct ThreadListView: View {
    @FetchRequest(
        entity: Thread.entity(),
        sortDescriptors: [NSSortDescriptor(key: "lastPostDate", ascending: false)],
        predicate: NSPredicate(format: "forum == %@", forum)
    ) var threads: FetchedResults<Thread>
    
    var body: some View {
        List(threads) { thread in
            ThreadRowView(thread: thread)
        }
        .onAppear {
            // Trigger refresh if needed
            refreshThreadsIfNeeded()
        }
    }
}
```

### 2. ObservableObject Data Sources

```swift
// SwiftUI-compatible data source
class ThreadListDataSource: ObservableObject {
    @Published var threads: [Thread] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let forum: Forum
    private let context: NSManagedObjectContext
    
    init(forum: Forum, context: NSManagedObjectContext) {
        self.forum = forum
        self.context = context
        setupFetchedResultsController()
    }
    
    private func setupFetchedResultsController() {
        // Convert NSFetchedResultsController to @Published property
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.predicate = NSPredicate(format: "forum == %@", forum)
        request.sortDescriptors = [NSSortDescriptor(key: "lastPostDate", ascending: false)]
        
        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        controller.delegate = self
        try! controller.performFetch()
        
        threads = controller.fetchedObjects ?? []
    }
}
```

## Testing Strategies

### 1. Data Flow Testing

```swift
// Integration test for complete data flow
func testDataFlowFromNetworkToUI() {
    // Given: Mock network response
    let mockHTML = loadTestHTMLResponse()
    MockURLProtocol.setMockResponse(mockHTML)
    
    // When: Trigger data flow
    let expectation = XCTestExpectation(description: "Data flow completion")
    
    ForumsClient.shared.loadThreads(in: testForum) { result in
        switch result {
        case .success:
            // Then: Verify data persisted to Core Data
            let threads = Thread.fetch(in: self.testContext) {
                $0.predicate = NSPredicate(format: "forum == %@", self.testForum)
            }
            XCTAssertFalse(threads.isEmpty)
            
            // Verify UI updates
            XCTAssertEqual(self.viewController.tableView.numberOfRows(inSection: 0), threads.count)
            
        case .failure(let error):
            XCTFail("Data flow failed: \(error)")
        }
        
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10.0)
}
```

### 2. Context Synchronization Testing

```swift
// Test context merging and synchronization
func testContextSynchronization() {
    // Given: Background context with changes
    let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    backgroundContext.persistentStoreCoordinator = testContainer.persistentStoreCoordinator
    
    // When: Save changes in background context
    backgroundContext.performAndWait {
        let thread = Thread.insert(into: backgroundContext)
        thread.threadID = "test-thread"
        thread.title = "Test Thread"
        
        try! backgroundContext.save()
    }
    
    // Then: Verify changes merged to main context
    let expectation = XCTestExpectation(description: "Context synchronization")
    
    DispatchQueue.main.async {
        let threads = Thread.fetch(in: self.mainContext) {
            $0.predicate = NSPredicate(format: "threadID == %@", "test-thread")
        }
        
        XCTAssertEqual(threads.count, 1)
        XCTAssertEqual(threads.first?.title, "Test Thread")
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
}
```

## Known Issues and Limitations

### Current Limitations

1. **Large Dataset Memory Usage**: Loading large forums can consume significant memory
2. **Complex Relationship Queries**: Deep relationship traversals can be slow
3. **Context Switching Overhead**: Frequent context merging can impact performance
4. **Batch Operation Limitations**: Very large batch operations may cause memory pressure

### Workaround Strategies

1. **Pagination**: Implement consistent pagination across all data loading operations
2. **Lazy Loading**: Use faulting and prefetching strategically
3. **Memory Pressure Handling**: Implement memory warning responses
4. **Background Processing**: Keep heavy operations off the main thread

### Future Improvements

1. **SwiftData Integration**: Gradual migration to SwiftData alongside Core Data
2. **Async/Await**: Modernize asynchronous operations
3. **Combine Integration**: Replace KVO with Combine publishers
4. **CloudKit Sync**: Add cloud synchronization for user data

## Migration Path to SwiftUI

### Phase 1: Maintain Core Data
- Keep existing Core Data stack unchanged
- Use @FetchRequest and @ObservedObject in SwiftUI views
- Gradually convert NSFetchedResultsController to SwiftUI patterns

### Phase 2: Modernize Data Layer
- Introduce async/await for network operations
- Add Combine publishers for reactive programming
- Implement proper error handling with Result types

### Phase 3: SwiftData Integration
- Add SwiftData models alongside Core Data (dual persistence)
- Migrate user preferences and settings first
- Gradually migrate core entities while maintaining compatibility

This data flow architecture ensures robust, performant data management while supporting the planned migration to SwiftUI without breaking existing functionality.