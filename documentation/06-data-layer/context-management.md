# Context Management

## Overview

Awful.app implements a sophisticated Core Data context management strategy that separates UI operations from data import operations while maintaining data consistency and optimal performance. This pattern has been essential for handling large forum datasets without blocking the user interface.

## Context Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Core Data Stack                          │
├─────────────────────────────────────────────────────────────┤
│  Persistent Store Coordinator                               │
│  ├─ SQLite Store (AwfulCache.sqlite)                       │
│  ├─ Migration Configuration                                │
│  └─ Store Metadata                                         │
├─────────────────────────────────────────────────────────────┤
│                    Context Layer                            │
│  ┌─────────────────┐          ┌─────────────────────────┐   │
│  │  Main Context   │          │  Background Context     │   │
│  │  (Main Queue)   │◄────────►│  (Private Queue)        │   │
│  │                 │   Merge  │                         │   │
│  │ • UI Operations │   Changes│ • Network Import        │   │
│  │ • User Input    │          │ • Bulk Operations       │   │
│  │ • FRC Updates   │          │ • Cache Management      │   │
│  └─────────────────┘          └─────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Core Context Types

### 1. Main Context (UI Thread)

The main context handles all UI-related operations and must remain responsive:

```swift
// DataStore.swift - Main context configuration
public final class DataStore: NSObject {
    /// Main-queue-concurrency-type context for UI operations
    public let mainManagedObjectContext: NSManagedObjectContext
    
    private let storeCoordinator: NSPersistentStoreCoordinator
    
    public init(storeDirectoryURL: URL) {
        // Create main context with main queue concurrency
        mainManagedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: Self.model)
        mainManagedObjectContext.persistentStoreCoordinator = storeCoordinator
        
        super.init()
        
        // Configure automatic saving
        setupAutomaticSaving()
    }
    
    private func setupAutomaticSaving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidEnterBackground(notification: Notification) {
        do {
            try mainManagedObjectContext.save()
        } catch {
            fatalError("Error saving main managed object context: \(error)")
        }
    }
}
```

### 2. Background Context (Private Queue)

Background contexts handle heavy data processing operations:

```swift
// ForumsClient.swift - Background context management
public final class ForumsClient {
    private var backgroundManagedObjectContext: NSManagedObjectContext?
    private var lastModifiedObserver: LastModifiedContextObserver?
    
    public var managedObjectContext: NSManagedObjectContext? {
        didSet {
            setupBackgroundContext(for: managedObjectContext)
        }
    }
    
    private func setupBackgroundContext(for mainContext: NSManagedObjectContext?) {
        // Clean up old context
        if let oldBackground = backgroundManagedObjectContext {
            NotificationCenter.default.removeObserver(
                self,
                name: .NSManagedObjectContextDidSave,
                object: oldBackground
            )
        }
        
        guard let mainContext = mainContext else {
            backgroundManagedObjectContext = nil
            lastModifiedObserver = nil
            return
        }
        
        // Create new background context
        let background = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        background.persistentStoreCoordinator = mainContext.persistentStoreCoordinator
        background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundManagedObjectContext = background
        
        // Set up change notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(backgroundManagedObjectContextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: background
        )
        
        // Set up bidirectional merging
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainManagedObjectContextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: mainContext
        )
        
        // Add last modified date tracking
        lastModifiedObserver = LastModifiedContextObserver(managedObjectContext: background)
    }
}
```

## Context Synchronization

### 1. Background to Main Merging

Changes from background context are automatically merged to main context:

```swift
// ForumsClient.swift - Background to main context merging
@objc private func backgroundManagedObjectContextDidSave(_ notification: Notification) {
    guard let context = managedObjectContext else { return }
    
    // Extract updated object IDs for efficient fault management
    let updatedObjectIDs: [NSManagedObjectID] = {
        guard
            let userInfo = notification.userInfo,
            let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>
        else { return [] }
        return updatedObjects.map { $0.objectID }
    }()
    
    // Merge changes on main queue
    context.perform {
        // Refresh faults to prevent stale data issues
        updatedObjectIDs
            .compactMap { context.object(with: $0) }
            .forEach { $0.willAccessValue(forKey: nil) }
        
        // Apply changes from background context
        context.mergeChanges(fromContextDidSave: notification)
    }
}
```

### 2. Main to Background Merging

User changes from main context are merged to background context:

```swift
// ForumsClient.swift - Main to background context merging
@objc private func mainManagedObjectContextDidSave(_ notification: Notification) {
    guard let context = backgroundManagedObjectContext else { return }
    
    // Merge user changes to background context
    context.perform {
        context.mergeChanges(fromContextDidSave: notification)
    }
}
```

### 3. Conflict Resolution

Merge conflicts are handled with appropriate policies:

```swift
// Context configuration with merge policies
private func configureContextMergePolicy(_ context: NSManagedObjectContext, isBackground: Bool) {
    if isBackground {
        // Background context: prefer server data
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    } else {
        // Main context: prefer user changes
        context.mergePolicy = NSErrorMergePolicy
    }
}
```

## Context Usage Patterns

### 1. UI Operations Pattern

Main context operations for UI binding and user interactions:

```swift
// ThreadsTableViewController.swift - Main context UI operations
class ThreadsTableViewController: UITableViewController {
    private var fetchedResultsController: NSFetchedResultsController<Thread>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFetchedResultsController()
    }
    
    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "isSticky", ascending: false),
            NSSortDescriptor(key: "lastPostDate", ascending: false)
        ]
        request.predicate = NSPredicate(format: "forum == %@", forum)
        
        // Use main context for UI operations
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: DataStore.shared.mainManagedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: "Threads-\(forum.forumID)"
        )
        
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            logger.error("Failed to fetch threads: \(error)")
        }
    }
    
    // User interaction - mark thread as read
    func markThreadAsRead(_ thread: Thread) {
        // Perform on main context for immediate UI update
        thread.seenPosts = thread.numberOfPosts
        
        do {
            try DataStore.shared.mainManagedObjectContext.save()
        } catch {
            logger.error("Failed to save thread read status: \(error)")
        }
    }
}
```

### 2. Background Import Pattern

Background context operations for data import:

```swift
// PostPersistence.swift - Background import operations
extension PostPersistence {
    static func importPosts(
        _ scrapedPosts: [ScrapedPost],
        for thread: Thread,
        in backgroundContext: NSManagedObjectContext
    ) throws {
        // Ensure we're on the background context queue
        backgroundContext.performAndWait {
            // Get thread in background context
            guard let backgroundThread = backgroundContext.object(with: thread.objectID) as? Thread else {
                throw PersistenceError.objectNotFound
            }
            
            // Process posts in batches
            let batchSize = 25
            for batch in scrapedPosts.chunked(into: batchSize) {
                autoreleasepool {
                    // Create upsert batch
                    let postIDs = batch.map { $0.postID }
                    let upsertBatch = UpsertBatch<Post>(
                        in: backgroundContext,
                        identifiedBy: \.postID,
                        identifiers: postIDs
                    )
                    
                    // Import each post
                    for scrapedPost in batch {
                        let post = upsertBatch[scrapedPost.postID]
                        
                        // Update post properties
                        post.innerHTML = scrapedPost.innerHTML
                        post.postDate = scrapedPost.postDate
                        post.postIndex = Int32(scrapedPost.postIndex)
                        post.thread = backgroundThread
                        
                        // Handle author relationship
                        if let authorData = scrapedPost.author {
                            post.author = AuthorPersistence.getOrCreate(
                                userID: authorData.userID,
                                username: authorData.username,
                                in: backgroundContext
                            )
                        }
                    }
                }
            }
            
            // Update thread metadata
            backgroundThread.numberOfPosts = Int32(scrapedPosts.count)
            backgroundThread.lastPostDate = scrapedPosts.last?.postDate
            
            // Save changes
            try backgroundContext.save()
        }
    }
}
```

### 3. Child Context Pattern

Temporary contexts for isolated operations:

```swift
// EditPostViewController.swift - Child context for editing
class EditPostViewController: UIViewController {
    private var editingContext: NSManagedObjectContext!
    private var editingPost: Post!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupEditingContext()
    }
    
    private func setupEditingContext() {
        // Create child context for editing
        editingContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        editingContext.parent = DataStore.shared.mainManagedObjectContext
        
        // Get post in editing context
        editingPost = editingContext.object(with: originalPost.objectID) as? Post
    }
    
    @IBAction func savePost() {
        // Update post content
        editingPost.innerHTML = textView.text
        
        do {
            // Save to child context first
            try editingContext.save()
            
            // Save to parent context (main context)
            try DataStore.shared.mainManagedObjectContext.save()
            
            navigationController?.popViewController(animated: true)
        } catch {
            presentError(error)
        }
    }
    
    @IBAction func cancelEditing() {
        // Discard changes by not saving child context
        navigationController?.popViewController(animated: true)
    }
}
```

## Performance Optimization

### 1. Fault Management

Efficient fault handling prevents unnecessary data loading:

```swift
// Managed.swift - Fault-aware fetching
extension Managed where Self: NSManagedObject {
    static func fetch(
        in context: NSManagedObjectContext,
        configurationBlock: (NSFetchRequest<Self>) -> Void = { _ in }
    ) -> [Self] {
        let request = fetchRequest() as! NSFetchRequest<Self>
        
        // Configure fetch request
        configurationBlock(request)
        
        // Set fault handling behavior
        request.returnsObjectsAsFaults = true
        request.includesSubentities = false
        
        do {
            return try context.fetch(request)
        } catch {
            logger.error("Fetch failed: \(error)")
            return []
        }
    }
}
```

### 2. Batch Operations

Batch operations for improved performance:

```swift
// BatchOperations.swift - Efficient batch processing
extension NSManagedObjectContext {
    func performBatchUpdate<T: NSManagedObject>(
        entity: T.Type,
        predicate: NSPredicate?,
        propertiesToUpdate: [String: Any]
    ) throws -> NSBatchUpdateResult {
        
        let batchUpdateRequest = NSBatchUpdateRequest(entity: T.entity())
        batchUpdateRequest.predicate = predicate
        batchUpdateRequest.propertiesToUpdate = propertiesToUpdate
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        
        let result = try execute(batchUpdateRequest) as! NSBatchUpdateResult
        
        // Merge changes to avoid stale objects
        if let objectIDs = result.result as? [NSManagedObjectID] {
            let changes = [NSUpdatedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
        }
        
        return result
    }
    
    func performBatchDelete<T: NSManagedObject>(
        entity: T.Type,
        predicate: NSPredicate?
    ) throws -> NSBatchDeleteResult {
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: T.fetchRequest())
        batchDeleteRequest.fetchRequest.predicate = predicate
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        
        let result = try execute(batchDeleteRequest) as! NSBatchDeleteResult
        
        // Merge changes to avoid stale objects
        if let objectIDs = result.result as? [NSManagedObjectID] {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
        }
        
        return result
    }
}
```

### 3. Memory Management

Proactive memory management for long-running operations:

```swift
// MemoryManagedOperation.swift - Memory-conscious operations
class MemoryManagedOperation: Operation {
    private let context: NSManagedObjectContext
    
    override func main() {
        context.performAndWait {
            autoreleasepool {
                do {
                    try performWork()
                    
                    // Save and reset context to free memory
                    try context.save()
                    context.reset()
                    
                } catch {
                    logger.error("Operation failed: \(error)")
                    context.reset()
                }
            }
        }
    }
    
    private func performWork() throws {
        // Heavy data processing work
        let largeFetch = createLargeFetchRequest()
        let results = try context.fetch(largeFetch)
        
        for batch in results.chunked(into: 100) {
            autoreleasepool {
                processBatch(batch)
            }
        }
    }
}
```

## Error Handling

### 1. Context Threading Violations

Detect and handle threading violations:

```swift
// ContextValidator.swift - Threading violation detection
extension NSManagedObjectContext {
    func performSafely(_ block: @escaping () throws -> Void) rethrows {
        var thrownError: Error?
        
        performAndWait {
            do {
                try block()
            } catch {
                thrownError = error
            }
        }
        
        if let error = thrownError {
            throw error
        }
    }
    
    func validateThreading() {
        switch concurrencyType {
        case .mainQueueConcurrencyType:
            assert(Thread.isMainThread, "Main queue context accessed from background thread")
        case .privateQueueConcurrencyType:
            // Private queue contexts handle their own threading
            break
        case .confinementConcurrencyType:
            // Legacy concurrency type - should not be used
            assertionFailure("Confinement concurrency type is deprecated")
        @unknown default:
            assertionFailure("Unknown concurrency type")
        }
    }
}
```

### 2. Save Conflict Resolution

Handle save conflicts gracefully:

```swift
// ConflictResolution.swift - Save conflict handling
extension NSManagedObjectContext {
    func saveWithConflictResolution() throws {
        do {
            try save()
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSValidationMultipleErrorsError {
                // Handle multiple validation errors
                if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                    for detailedError in detailedErrors {
                        logger.error("Validation error: \(detailedError.localizedDescription)")
                    }
                }
                throw error
            } else if error.domain == NSCocoaErrorDomain && error.code == NSManagedObjectMergeError {
                // Handle merge conflicts
                try resolveMergeConflict(error)
                try save() // Retry save after resolving conflict
            } else {
                throw error
            }
        }
    }
    
    private func resolveMergeConflict(_ error: NSError) throws {
        guard let conflictedObjects = error.userInfo[NSPersistentStoreSaveConflictsErrorKey] as? [NSMergeConflict] else {
            throw error
        }
        
        for conflict in conflictedObjects {
            // Resolve conflict by preferring newer data
            if let newerSnapshot = conflict.newVersionNumber > conflict.oldVersionNumber ? 
                conflict.sourceObject : conflict.objectSnapshot {
                conflict.sourceObject.setValuesForKeys(newerSnapshot)
            }
        }
    }
}
```

## Testing Context Management

### 1. Test Context Setup

Create isolated test contexts:

```swift
// TestContextManager.swift - Test context management
class TestContextManager {
    let testContainer: NSPersistentContainer
    let mainContext: NSManagedObjectContext
    let backgroundContext: NSManagedObjectContext
    
    init() {
        // Create in-memory store for testing
        testContainer = NSPersistentContainer(name: "Awful", managedObjectModel: DataStore.model)
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        testContainer.persistentStoreDescriptions = [description]
        
        testContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Test store failed to load: \(error)")
            }
        }
        
        mainContext = testContainer.viewContext
        backgroundContext = testContainer.newBackgroundContext()
    }
    
    func reset() {
        mainContext.reset()
        backgroundContext.reset()
    }
}
```

### 2. Context Synchronization Tests

Test context merging behavior:

```swift
// ContextSynchronizationTests.swift - Context sync testing
class ContextSynchronizationTests: XCTestCase {
    var testManager: TestContextManager!
    
    override func setUp() {
        super.setUp()
        testManager = TestContextManager()
    }
    
    func testBackgroundToMainMerging() {
        // Given: Object in background context
        let expectation = XCTestExpectation(description: "Context merge")
        
        testManager.backgroundContext.perform {
            let thread = Thread.insert(into: self.testManager.backgroundContext)
            thread.threadID = "test-thread"
            thread.title = "Original Title"
            
            try! self.testManager.backgroundContext.save()
        }
        
        // When: Object is updated in background
        testManager.backgroundContext.perform {
            let thread = Thread.fetch(in: self.testManager.backgroundContext) {
                $0.predicate = NSPredicate(format: "threadID == %@", "test-thread")
            }.first!
            
            thread.title = "Updated Title"
            try! self.testManager.backgroundContext.save()
        }
        
        // Then: Changes should merge to main context
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let threads = Thread.fetch(in: self.testManager.mainContext) {
                $0.predicate = NSPredicate(format: "threadID == %@", "test-thread")
            }
            
            XCTAssertEqual(threads.count, 1)
            XCTAssertEqual(threads.first?.title, "Updated Title")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConflictResolution() {
        // Given: Object exists in both contexts
        let thread = Thread.insert(into: testManager.mainContext)
        thread.threadID = "conflict-thread"
        thread.title = "Original"
        try! testManager.mainContext.save()
        
        let objectID = thread.objectID
        
        // When: Object is modified in both contexts
        testManager.backgroundContext.perform {
            let backgroundThread = self.testManager.backgroundContext.object(with: objectID) as! Thread
            backgroundThread.title = "Background Update"
            try! self.testManager.backgroundContext.save()
        }
        
        thread.title = "Main Update"
        
        // Then: Save should handle conflict appropriately
        XCTAssertNoThrow(try testManager.mainContext.saveWithConflictResolution())
    }
}
```

## SwiftUI Integration

### 1. Environment Context

Provide contexts through SwiftUI environment:

```swift
// ContextEnvironment.swift - SwiftUI context environment
struct ContextEnvironment: EnvironmentKey {
    static let defaultValue: NSManagedObjectContext = DataStore.shared.mainManagedObjectContext
}

extension EnvironmentValues {
    var managedObjectContext: NSManagedObjectContext {
        get { self[ContextEnvironment.self] }
        set { self[ContextEnvironment.self] = newValue }
    }
}

// Usage in SwiftUI app
@main
struct AwfulApp: App {
    let dataStore = DataStore.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataStore.mainManagedObjectContext)
        }
    }
}
```

### 2. SwiftUI Data Sources

Create SwiftUI-compatible data sources:

```swift
// SwiftUIDataSource.swift - SwiftUI context management
@MainActor
class SwiftUIDataSource: ObservableObject {
    private let mainContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    
    @Published var isLoading = false
    @Published var error: Error?
    
    init(mainContext: NSManagedObjectContext, backgroundContext: NSManagedObjectContext) {
        self.mainContext = mainContext
        self.backgroundContext = backgroundContext
    }
    
    func performBackgroundOperation<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let result = try operation(self.backgroundContext)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

## Migration Considerations

### 1. Context Compatibility

Ensure context patterns work with SwiftUI:

```swift
// ContextCompatibility.swift - SwiftUI migration support
extension NSManagedObjectContext {
    /// SwiftUI-compatible async save
    @MainActor
    func asyncSave() async throws {
        guard hasChanges else { return }
        
        try await withCheckedThrowingContinuation { continuation in
            perform {
                do {
                    try self.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

### 2. Future Enhancements

Plan for SwiftData integration:

```swift
// FutureDataLayer.swift - SwiftData preparation
protocol DataLayerProtocol {
    associatedtype Context
    
    func mainContext() -> Context
    func backgroundContext() -> Context
    func save(_ context: Context) async throws
}

// Core Data implementation
struct CoreDataLayer: DataLayerProtocol {
    typealias Context = NSManagedObjectContext
    
    func mainContext() -> NSManagedObjectContext {
        return DataStore.shared.mainManagedObjectContext
    }
    
    func backgroundContext() -> NSManagedObjectContext {
        return DataStore.shared.createBackgroundContext()
    }
    
    func save(_ context: NSManagedObjectContext) async throws {
        try await context.asyncSave()
    }
}

// Future SwiftData implementation
@available(iOS 17.0, *)
struct SwiftDataLayer: DataLayerProtocol {
    typealias Context = ModelContext
    
    // SwiftData implementation...
}
```

The context management system provides a robust foundation for Core Data operations while maintaining compatibility with future SwiftUI and SwiftData migrations.