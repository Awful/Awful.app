# Core Data Stack

## Overview

The Core Data stack manages all persistent data for the Awful app, providing efficient storage and retrieval of forums, threads, posts, and user data. This system must maintain data integrity during the SwiftUI migration.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       Core Data Stack                          │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Persistent      │  │   Contexts      │  │  Entity Models  │  │
│  │ Container       │  │                 │  │                 │  │
│  │ • Store Setup   │  │ • View Context  │  │ • Forum         │  │
│  │ • Configuration │  │ • Background    │  │ • Thread        │  │
│  │ • Migration     │  │ • Import        │  │ • Post          │  │
│  │ • Optimization  │  │ • Private       │  │ • User          │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Fetch Requests  │  │  Relationships  │  │  Operations     │  │
│  │                 │  │                 │  │                 │  │
│  │ • Predicates    │  │ • One-to-Many   │  │ • Saves         │  │
│  │ • Sort Desc.    │  │ • Many-to-Many  │  │ • Fetches       │  │
│  │ • Batching      │  │ • Inverse       │  │ • Deletes       │  │
│  │ • Performance   │  │ • Cascading     │  │ • Batch Ops     │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Persistent Container Setup

### Core Configuration
```swift
import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    
    // MARK: - Container Setup
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AwfulModel")
        
        // Configure store description
        configureStoreDescription(container)
        
        // Load persistent stores
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                self?.handleStoreLoadingError(error)
            } else {
                self?.logStoreLoadingSuccess(storeDescription)
            }
        }
        
        // Configure view context
        configureViewContext(container.viewContext)
        
        return container
    }()
    
    private func configureStoreDescription(_ container: NSPersistentContainer) {
        guard let storeDescription = container.persistentStoreDescriptions.first else {
            fatalError("No store description found")
        }
        
        // Enable persistent history tracking
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // Enable remote change notifications
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Configure WAL mode for better concurrency
        storeDescription.setOption("WAL" as NSString, forKey: NSSQLitePragmasOption)
        
        // Set memory map threshold for large databases
        storeDescription.setOption(128 * 1024 * 1024 as NSNumber, forKey: NSSQLiteMemoryMapThresholdOption)
        
        // Enable lightweight migration
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
    }
    
    private func configureViewContext(_ context: NSManagedObjectContext) {
        // Automatically merge changes from parent
        context.automaticallyMergesChangesFromParent = true
        
        // Set merge policy for conflicts
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Disable undo manager for performance
        context.undoManager = nil
        
        // Set fetch batch size
        context.stalenessInterval = 0.0
    }
    
    private func handleStoreLoadingError(_ error: NSError) {
        AwfulLogger.shared.log("Core Data store loading failed: \(error)", level: .error)
        
        // Check if this is a migration error
        if error.domain == NSCocoaErrorDomain && error.code == NSPersistentStoreIncompatibleVersionHashError {
            // Attempt to handle migration manually
            attemptManualMigration()
        } else {
            // For now, crash in debug, but consider recovery strategies
            #if DEBUG
            fatalError("Core Data error: \(error), \(error.userInfo)")
            #else
            // In production, attempt to delete and recreate store
            attemptStoreRecovery()
            #endif
        }
    }
}
```

### Context Management
```swift
extension PersistenceController {
    // MARK: - Context Access
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        configureBackgroundContext(context)
        return context
    }
    
    func newPrivateContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = viewContext
        configurePrivateContext(context)
        return context
    }
    
    private func configureBackgroundContext(_ context: NSManagedObjectContext) {
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        
        // Set up automatic merging
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: context,
            queue: .main
        ) { [weak self] notification in
            self?.mergeChangesToViewContext(from: notification)
        }
    }
    
    private func configurePrivateContext(_ context: NSManagedObjectContext) {
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
    }
    
    private func mergeChangesToViewContext(from notification: Notification) {
        viewContext.perform {
            self.viewContext.mergeChanges(fromContextDidSave: notification)
        }
    }
}
```

## Entity Models

### Core Entity Definitions
```swift
// MARK: - Forum Entity

@objc(Forum)
public class Forum: NSManagedObject {
    @NSManaged public var id: Int32
    @NSManaged public var title: String
    @NSManaged public var subtitle: String?
    @NSManaged public var lastRefresh: Date?
    @NSManaged public var isHidden: Bool
    @NSManaged public var index: Int32
    @NSManaged public var iconURL: String?
    @NSManaged public var category: ForumCategory?
    @NSManaged public var threads: NSSet?
    @NSManaged public var metadata: ForumMetadata?
    
    // Computed properties
    public var threadsArray: [Thread] {
        return threads?.allObjects as? [Thread] ?? []
    }
    
    public var sortedThreads: [Thread] {
        return threadsArray.sorted { thread1, thread2 in
            if thread1.isSticky != thread2.isSticky {
                return thread1.isSticky && !thread2.isSticky
            }
            return (thread1.lastPostDate ?? Date.distantPast) > (thread2.lastPostDate ?? Date.distantPast)
        }
    }
    
    public var hasUnreadThreads: Bool {
        return threadsArray.contains { $0.hasUnreadPosts }
    }
}

// MARK: - Thread Entity

@objc(Thread)
public class Thread: NSManagedObject {
    @NSManaged public var id: Int32
    @NSManaged public var title: String
    @NSManaged public var author: String?
    @NSManaged public var authorID: Int32
    @NSManaged public var lastPostDate: Date?
    @NSManaged public var postCount: Int32
    @NSManaged public var lastReadPostIndex: Int32
    @NSManaged public var hasUnreadPosts: Bool
    @NSManaged public var isSticky: Bool
    @NSManaged public var isAnnouncement: Bool
    @NSManaged public var isLocked: Bool
    @NSManaged public var rating: Double
    @NSManaged public var lastRefresh: Date?
    @NSManaged public var forum: Forum?
    @NSManaged public var posts: NSSet?
    @NSManaged public var bookmarks: NSSet?
    
    // Computed properties
    public var postsArray: [Post] {
        return posts?.allObjects as? [Post] ?? []
    }
    
    public var sortedPosts: [Post] {
        return postsArray.sorted { $0.index < $1.index }
    }
    
    public var unreadPostCount: Int32 {
        return max(0, postCount - lastReadPostIndex)
    }
    
    public var isBookmarked: Bool {
        return bookmarks?.count ?? 0 > 0
    }
    
    // Business logic
    public func markAsRead() {
        hasUnreadPosts = false
        lastReadPostIndex = postCount
    }
    
    public func addPost(_ post: Post) {
        post.thread = self
        addToPosts(post)
        updatePostCount()
    }
    
    private func updatePostCount() {
        postCount = Int32(postsArray.count)
    }
}

// MARK: - Post Entity

@objc(Post)
public class Post: NSManagedObject {
    @NSManaged public var id: Int32
    @NSManaged public var content: String
    @NSManaged public var innerHTML: String?
    @NSManaged public var author: String?
    @NSManaged public var authorID: Int32
    @NSManaged public var postDate: Date?
    @NSManaged public var editDate: Date?
    @NSManaged public var index: Int32
    @NSManaged public var thread: Thread?
    @NSManaged public var attachments: NSSet?
    @NSManaged public var seenState: SeenState?
    
    // Computed properties
    public var attachmentsArray: [PostAttachment] {
        return attachments?.allObjects as? [PostAttachment] ?? []
    }
    
    public var formattedDate: String {
        guard let date = postDate else { return "" }
        return DateFormatter.postDateFormatter.string(from: date)
    }
    
    public var htmlContent: String {
        return innerHTML ?? content
    }
    
    public var hasBeenEdited: Bool {
        guard let editDate = editDate,
              let postDate = postDate else {
            return false
        }
        return editDate > postDate.addingTimeInterval(60) // 1 minute grace period
    }
}
```

### Entity Extensions
```swift
// MARK: - Forum Extensions

extension Forum {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Forum> {
        return NSFetchRequest<Forum>(entityName: "Forum")
    }
    
    public static func findOrCreate(id: Int32, in context: NSManagedObjectContext) -> Forum {
        let request: NSFetchRequest<Forum> = fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", id)
        request.fetchLimit = 1
        
        if let existingForum = try? context.fetch(request).first {
            return existingForum
        }
        
        let newForum = Forum(context: context)
        newForum.id = id
        newForum.lastRefresh = Date()
        return newForum
    }
    
    public func updateFromScraping(_ scrapedData: ScrapedForum) {
        title = scrapedData.title
        subtitle = scrapedData.description
        index = Int32(scrapedData.index)
        lastRefresh = Date()
    }
}

// MARK: - Thread Extensions

extension Thread {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Thread> {
        return NSFetchRequest<Thread>(entityName: "Thread")
    }
    
    public static func findOrCreate(id: Int32, in context: NSManagedObjectContext) -> Thread {
        let request: NSFetchRequest<Thread> = fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", id)
        request.fetchLimit = 1
        
        if let existingThread = try? context.fetch(request).first {
            return existingThread
        }
        
        let newThread = Thread(context: context)
        newThread.id = id
        newThread.lastRefresh = Date()
        return newThread
    }
    
    public func updateFromScraping(_ scrapedData: ScrapedThread) {
        title = scrapedData.title
        author = scrapedData.author
        authorID = Int32(scrapedData.authorId ?? 0)
        postCount = scrapedData.postCount
        lastPostDate = scrapedData.lastPostDate
        isSticky = scrapedData.isSticky
        isAnnouncement = scrapedData.isAnnouncement
        isLocked = scrapedData.isLocked
        hasUnreadPosts = scrapedData.hasUnreadPosts
        rating = scrapedData.rating ?? 0.0
        lastRefresh = Date()
    }
}
```

## Fetch Operations

### Fetch Request Builders
```swift
class FetchRequestBuilder {
    // MARK: - Forum Fetch Requests
    
    static func visibleForums() -> NSFetchRequest<Forum> {
        let request: NSFetchRequest<Forum> = Forum.fetchRequest()
        request.predicate = NSPredicate(format: "isHidden == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Forum.index, ascending: true)
        ]
        return request
    }
    
    static func forumsWithUnreadThreads() -> NSFetchRequest<Forum> {
        let request: NSFetchRequest<Forum> = Forum.fetchRequest()
        request.predicate = NSPredicate(format: "ANY threads.hasUnreadPosts == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Forum.index, ascending: true)
        ]
        return request
    }
    
    // MARK: - Thread Fetch Requests
    
    static func threads(for forum: Forum) -> NSFetchRequest<Thread> {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.predicate = NSPredicate(format: "forum == %@", forum)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Thread.isSticky, ascending: false),
            NSSortDescriptor(keyPath: \Thread.lastPostDate, ascending: false)
        ]
        return request
    }
    
    static func unreadThreads() -> NSFetchRequest<Thread> {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.predicate = NSPredicate(format: "hasUnreadPosts == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Thread.lastPostDate, ascending: false)
        ]
        return request
    }
    
    static func bookmarkedThreads() -> NSFetchRequest<Thread> {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.predicate = NSPredicate(format: "bookmarks.@count > 0")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Thread.lastPostDate, ascending: false)
        ]
        return request
    }
    
    // MARK: - Post Fetch Requests
    
    static func posts(for thread: Thread, page: Int = 1, postsPerPage: Int = 40) -> NSFetchRequest<Post> {
        let request: NSFetchRequest<Post> = Post.fetchRequest()
        request.predicate = NSPredicate(format: "thread == %@", thread)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Post.index, ascending: true)
        ]
        
        // Pagination
        request.fetchOffset = (page - 1) * postsPerPage
        request.fetchLimit = postsPerPage
        
        // Performance optimization
        request.fetchBatchSize = 20
        request.relationshipKeyPathsForPrefetching = ["attachments"]
        
        return request
    }
    
    static func recentPosts(limit: Int = 20) -> NSFetchRequest<Post> {
        let request: NSFetchRequest<Post> = Post.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Post.postDate, ascending: false)
        ]
        request.fetchLimit = limit
        return request
    }
}
```

### Advanced Querying
```swift
class CoreDataQueryBuilder {
    private var fetchRequest: NSFetchRequest<NSManagedObject>
    private var predicates: [NSPredicate] = []
    private var sortDescriptors: [NSSortDescriptor] = []
    
    init<T: NSManagedObject>(entityType: T.Type) {
        let entityName = String(describing: entityType)
        fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
    }
    
    func `where`(_ predicate: NSPredicate) -> CoreDataQueryBuilder {
        predicates.append(predicate)
        return self
    }
    
    func `where`(_ format: String, _ arguments: CVarArg...) -> CoreDataQueryBuilder {
        let predicate = NSPredicate(format: format, arguments: arguments)
        return self.where(predicate)
    }
    
    func orderBy<T: NSManagedObject>(_ keyPath: KeyPath<T, Any>, ascending: Bool = true) -> CoreDataQueryBuilder {
        let sortDescriptor = NSSortDescriptor(keyPath: keyPath, ascending: ascending)
        sortDescriptors.append(sortDescriptor)
        return self
    }
    
    func limit(_ limit: Int) -> CoreDataQueryBuilder {
        fetchRequest.fetchLimit = limit
        return self
    }
    
    func offset(_ offset: Int) -> CoreDataQueryBuilder {
        fetchRequest.fetchOffset = offset
        return self
    }
    
    func batchSize(_ size: Int) -> CoreDataQueryBuilder {
        fetchRequest.fetchBatchSize = size
        return self
    }
    
    func prefetch(_ relationships: [String]) -> CoreDataQueryBuilder {
        fetchRequest.relationshipKeyPathsForPrefetching = relationships
        return self
    }
    
    func execute<T: NSManagedObject>(in context: NSManagedObjectContext) throws -> [T] {
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        if !sortDescriptors.isEmpty {
            fetchRequest.sortDescriptors = sortDescriptors
        }
        
        let results = try context.fetch(fetchRequest)
        return results as? [T] ?? []
    }
    
    func executeFirst<T: NSManagedObject>(in context: NSManagedObjectContext) throws -> T? {
        return try limit(1).execute(in: context).first
    }
}

// Usage example
let recentThreads = try CoreDataQueryBuilder(entityType: Thread.self)
    .where("hasUnreadPosts == YES")
    .orderBy(\Thread.lastPostDate, ascending: false)
    .limit(50)
    .prefetch(["forum", "posts"])
    .execute(in: context)
```

## Save Operations

### Context Saving
```swift
extension PersistenceController {
    // MARK: - Save Operations
    
    func save() {
        save(context: viewContext)
    }
    
    func save(context: NSManagedObjectContext) {
        context.perform {
            guard context.hasChanges else { return }
            
            do {
                try context.save()
                AwfulLogger.shared.log("Core Data save successful", level: .debug)
            } catch {
                AwfulLogger.shared.log("Core Data save failed: \(error)", level: .error)
                self.handleSaveError(error, in: context)
            }
        }
    }
    
    func saveAndWait(context: NSManagedObjectContext) throws {
        var saveError: Error?
        
        context.performAndWait {
            guard context.hasChanges else { return }
            
            do {
                try context.save()
            } catch {
                saveError = error
            }
        }
        
        if let error = saveError {
            throw error
        }
    }
    
    private func handleSaveError(_ error: Error, in context: NSManagedObjectContext) {
        let nsError = error as NSError
        
        // Handle validation errors
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSValidationMissingMandatoryPropertyError:
                AwfulLogger.shared.log("Validation error: Missing mandatory property", level: .error)
                rollbackContext(context)
                
            case NSValidationRelationshipDeniedDeleteError:
                AwfulLogger.shared.log("Validation error: Relationship denied delete", level: .error)
                rollbackContext(context)
                
            case NSManagedObjectMergeError:
                AwfulLogger.shared.log("Merge conflict detected, attempting resolution", level: .warning)
                resolveMergeConflict(in: context)
                
            default:
                AwfulLogger.shared.log("Unknown Core Data error: \(error)", level: .error)
                rollbackContext(context)
            }
        }
    }
    
    private func rollbackContext(_ context: NSManagedObjectContext) {
        context.rollback()
        AwfulLogger.shared.log("Context rolled back due to save error", level: .warning)
    }
    
    private func resolveMergeConflict(in context: NSManagedObjectContext) {
        // Implement merge conflict resolution strategy
        context.refreshAllObjects()
        
        // Retry save after refresh
        save(context: context)
    }
}
```

### Batch Operations
```swift
extension PersistenceController {
    // MARK: - Batch Operations
    
    func batchInsert<T: NSManagedObject>(
        entityType: T.Type,
        objects: [[String: Any]],
        batchSize: Int = 1000
    ) throws {
        let entityName = String(describing: entityType)
        
        for batch in objects.chunked(into: batchSize) {
            let batchInsertRequest = NSBatchInsertRequest(
                entityName: entityName,
                objects: batch
            )
            
            batchInsertRequest.resultType = .objectIDs
            
            let result = try viewContext.execute(batchInsertRequest) as? NSBatchInsertResult
            
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes = [NSInsertedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: changes,
                    into: [viewContext]
                )
            }
        }
    }
    
    func batchUpdate(
        entityName: String,
        predicate: NSPredicate,
        propertiesToUpdate: [String: Any]
    ) throws {
        let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)
        batchUpdateRequest.predicate = predicate
        batchUpdateRequest.propertiesToUpdate = propertiesToUpdate
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        
        let result = try viewContext.execute(batchUpdateRequest) as? NSBatchUpdateResult
        
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            let changes = [NSUpdatedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: changes,
                into: [viewContext]
            )
        }
    }
    
    func batchDelete(
        entityName: String,
        predicate: NSPredicate
    ) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = predicate
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        
        let result = try viewContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
        
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: changes,
                into: [viewContext]
            )
        }
    }
}
```

## Performance Optimization

### Memory Management
```swift
extension PersistenceController {
    // MARK: - Memory Management
    
    func optimizeMemoryUsage() {
        viewContext.perform {
            // Refresh objects to free memory
            self.viewContext.refreshAllObjects()
            
            // Clear query plan cache
            self.viewContext.queryGenerationToken = nil
            
            // Reset staleness interval
            self.viewContext.stalenessInterval = 0.0
        }
    }
    
    func cleanupOldData() {
        let backgroundContext = newBackgroundContext()
        
        backgroundContext.perform {
            // Remove posts older than 30 days
            let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            
            do {
                try self.batchDelete(
                    entityName: "Post",
                    predicate: NSPredicate(format: "postDate < %@", cutoffDate as NSDate)
                )
                
                AwfulLogger.shared.log("Old posts cleanup completed", level: .info)
            } catch {
                AwfulLogger.shared.log("Old posts cleanup failed: \(error)", level: .error)
            }
        }
    }
    
    func compactDatabase() {
        let backgroundContext = newBackgroundContext()
        
        backgroundContext.perform {
            do {
                // Trigger database compaction
                let coordinator = self.persistentContainer.persistentStoreCoordinator
                
                for store in coordinator.persistentStores {
                    try coordinator.migratePersistentStore(
                        store,
                        to: store.url!,
                        options: nil,
                        type: store.type
                    )
                }
                
                AwfulLogger.shared.log("Database compaction completed", level: .info)
            } catch {
                AwfulLogger.shared.log("Database compaction failed: \(error)", level: .error)
            }
        }
    }
}
```

## SwiftUI Integration

### Fetch Requests for SwiftUI
```swift
// MARK: - SwiftUI Integration

extension PersistenceController {
    // Pre-configured fetch requests for SwiftUI views
    
    static func forumsFetchRequest() -> NSFetchRequest<Forum> {
        return FetchRequestBuilder.visibleForums()
    }
    
    static func threadsFetchRequest(for forum: Forum) -> NSFetchRequest<Thread> {
        return FetchRequestBuilder.threads(for: forum)
    }
    
    static func postsFetchRequest(for thread: Thread) -> NSFetchRequest<Post> {
        return FetchRequestBuilder.posts(for: thread)
    }
}

// Usage in SwiftUI views
struct ForumsView: View {
    @FetchRequest(
        fetchRequest: PersistenceController.forumsFetchRequest()
    ) var forums: FetchedResults<Forum>
    
    var body: some View {
        List(forums) { forum in
            ForumRow(forum: forum)
        }
    }
}
```

## Testing

### Test Stack Setup
```swift
class CoreDataTestStack {
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AwfulModel")
        
        // Use in-memory store for testing
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Test store loading failed: \(error)")
            }
        }
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func createTestForum() -> Forum {
        let forum = Forum(context: viewContext)
        forum.id = Int32.random(in: 1...1000)
        forum.title = "Test Forum"
        forum.isHidden = false
        return forum
    }
    
    func createTestThread(in forum: Forum) -> Thread {
        let thread = Thread(context: viewContext)
        thread.id = Int32.random(in: 1...10000)
        thread.title = "Test Thread"
        thread.forum = forum
        thread.hasUnreadPosts = false
        return thread
    }
}
```

## Best Practices

1. **Context Management**: Use appropriate context types for different operations
2. **Performance**: Optimize fetch requests with proper predicates and batch sizes
3. **Memory**: Implement regular cleanup and memory management
4. **Concurrency**: Always perform Core Data operations on the correct queue
5. **Error Handling**: Implement comprehensive error handling and recovery
6. **Migration**: Plan for schema changes with proper migration strategies
7. **Testing**: Use in-memory stores for testing
8. **Monitoring**: Track performance metrics and identify bottlenecks