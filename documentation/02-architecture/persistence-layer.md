# Persistence Layer

## Overview

The persistence layer manages all data storage and retrieval in the Awful app, primarily using Core Data for local caching and SQLite for structured data. This document covers the current implementation and best practices.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Persistence Layer                           │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Core Data      │  │  Data Models    │  │  Migration      │  │
│  │                 │  │                 │  │                 │  │
│  │ • NSPersistent  │  │ • Forum         │  │ • Schema        │  │
│  │   Container     │  │ • Thread        │  │ • Progressive   │  │
│  │ • Contexts      │  │ • Post          │  │ • Lightweight   │  │
│  │ • Fetch Requests│  │ • User          │  │ • Custom        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Repositories   │  │  Query Builder  │  │  Cache Management│ │
│  │                 │  │                 │  │                 │  │
│  │ • Forums        │  │ • Predicates    │  │ • Memory        │  │
│  │ • Threads       │  │ • Sort Desc.    │  │ • Disk          │  │
│  │ • Posts         │  │ • Batching      │  │ • TTL Policies  │  │
│  │ • Users         │  │ • Performance   │  │ • Cleanup       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Core Data Stack

### Persistent Container Setup
```swift
import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AwfulModel")
        
        // Configure store description
        let storeDescription = container.persistentStoreDescriptions.first!
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Handle store loading error
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Contexts
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Saving
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Handle save error
                let nsError = error as NSError
                fatalError("Unresolved Core Data save error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func saveContext(context: NSManagedObjectContext) {
        context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    // Handle background context save error
                    print("Background context save error: \(error)")
                }
            }
        }
    }
}
```

### Context Management
```swift
extension PersistenceController {
    // Background import context
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = newBackgroundContext()
        context.perform {
            block(context)
            self.saveContext(context: context)
        }
    }
    
    // Main queue operations
    func performMainQueueTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = viewContext
        context.perform {
            block(context)
            self.save()
        }
    }
    
    // Batch operations
    func performBatchOperation<T>(_ operation: @escaping (NSManagedObjectContext) -> T) -> T? {
        let context = newBackgroundContext()
        var result: T?
        
        context.performAndWait {
            result = operation(context)
            self.saveContext(context: context)
        }
        
        return result
    }
}
```

## Data Models

### Core Entities

#### Forum Entity
```swift
@objc(Forum)
public class Forum: NSManagedObject {
    @NSManaged public var id: Int32
    @NSManaged public var title: String
    @NSManaged public var subtitle: String?
    @NSManaged public var lastRefresh: Date?
    @NSManaged public var isHidden: Bool
    @NSManaged public var index: Int32
    @NSManaged public var category: ForumCategory?
    @NSManaged public var threads: NSSet?
    @NSManaged public var metadata: ForumMetadata?
}

// MARK: - Generated accessors for threads
extension Forum {
    @objc(addThreadsObject:)
    @NSManaged public func addToThreads(_ value: Thread)
    
    @objc(removeThreadsObject:)
    @NSManaged public func removeFromThreads(_ value: Thread)
    
    @objc(addThreads:)
    @NSManaged public func addToThreads(_ values: NSSet)
    
    @objc(removeThreads:)
    @NSManaged public func removeFromThreads(_ values: NSSet)
}
```

#### Thread Entity
```swift
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
    @NSManaged public var metadata: ThreadMetadata?
}
```

#### Post Entity
```swift
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
}
```

### Entity Extensions
```swift
// MARK: - Business Logic Extensions

extension Forum {
    var threadsArray: [Thread] {
        return threads?.allObjects as? [Thread] ?? []
    }
    
    var sortedThreads: [Thread] {
        return threadsArray.sorted { $0.lastPostDate ?? Date.distantPast > $1.lastPostDate ?? Date.distantPast }
    }
    
    func addThread(_ thread: Thread) {
        thread.forum = self
        addToThreads(thread)
    }
    
    var hasUnreadThreads: Bool {
        return threadsArray.contains { $0.hasUnreadPosts }
    }
}

extension Thread {
    var postsArray: [Post] {
        return posts?.allObjects as? [Post] ?? []
    }
    
    var sortedPosts: [Post] {
        return postsArray.sorted { $0.index < $1.index }
    }
    
    var unreadPostCount: Int32 {
        return max(0, postCount - lastReadPostIndex)
    }
    
    func markAsRead() {
        hasUnreadPosts = false
        lastReadPostIndex = postCount
    }
    
    func addPost(_ post: Post) {
        post.thread = self
        addToPosts(post)
        postCount = Int32(postsArray.count)
    }
}

extension Post {
    var formattedDate: String {
        guard let date = postDate else { return "" }
        return DateFormatter.postDateFormatter.string(from: date)
    }
    
    var htmlContent: String {
        return innerHTML ?? content
    }
}
```

## Repository Pattern

### Base Repository
```swift
protocol Repository {
    associatedtype Entity: NSManagedObject
    
    func fetch(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?) -> [Entity]
    func fetchFirst(predicate: NSPredicate?) -> Entity?
    func create() -> Entity
    func save(_ entity: Entity)
    func delete(_ entity: Entity)
    func deleteAll(predicate: NSPredicate?)
}

class BaseRepository<T: NSManagedObject>: Repository {
    typealias Entity = T
    
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        self.context = context
    }
    
    func fetch(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        do {
            return try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }
    
    func fetchFirst(predicate: NSPredicate? = nil) -> T? {
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
        request.predicate = predicate
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Fetch first error: \(error)")
            return nil
        }
    }
    
    func create() -> T {
        return T(context: context)
    }
    
    func save(_ entity: T) {
        do {
            try context.save()
        } catch {
            print("Save error: \(error)")
        }
    }
    
    func delete(_ entity: T) {
        context.delete(entity)
        
        do {
            try context.save()
        } catch {
            print("Delete error: \(error)")
        }
    }
    
    func deleteAll(predicate: NSPredicate? = nil) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: T.self))
        request.predicate = predicate
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
        } catch {
            print("Batch delete error: \(error)")
        }
    }
}
```

### Specific Repositories
```swift
class ForumsRepository: BaseRepository<Forum> {
    func fetchVisibleForums() -> [Forum] {
        let predicate = NSPredicate(format: "isHidden == NO")
        let sortDescriptors = [NSSortDescriptor(keyPath: \Forum.index, ascending: true)]
        return fetch(predicate: predicate, sortDescriptors: sortDescriptors)
    }
    
    func fetchForum(by id: Int32) -> Forum? {
        let predicate = NSPredicate(format: "id == %d", id)
        return fetchFirst(predicate: predicate)
    }
    
    func updateLastRefresh(for forum: Forum) {
        forum.lastRefresh = Date()
        save(forum)
    }
}

class ThreadsRepository: BaseRepository<Thread> {
    func fetchThreads(for forum: Forum, includeSticky: Bool = true) -> [Thread] {
        var predicateFormat = "forum == %@"
        if !includeSticky {
            predicateFormat += " AND isSticky == NO"
        }
        
        let predicate = NSPredicate(format: predicateFormat, forum)
        let sortDescriptors = [
            NSSortDescriptor(keyPath: \Thread.isSticky, ascending: false),
            NSSortDescriptor(keyPath: \Thread.lastPostDate, ascending: false)
        ]
        
        return fetch(predicate: predicate, sortDescriptors: sortDescriptors)
    }
    
    func fetchUnreadThreads() -> [Thread] {
        let predicate = NSPredicate(format: "hasUnreadPosts == YES")
        let sortDescriptors = [NSSortDescriptor(keyPath: \Thread.lastPostDate, ascending: false)]
        return fetch(predicate: predicate, sortDescriptors: sortDescriptors)
    }
    
    func markThreadAsRead(_ thread: Thread) {
        thread.markAsRead()
        save(thread)
    }
}

class PostsRepository: BaseRepository<Post> {
    func fetchPosts(for thread: Thread, page: Int = 1, postsPerPage: Int = 40) -> [Post] {
        let predicate = NSPredicate(format: "thread == %@", thread)
        let sortDescriptors = [NSSortDescriptor(keyPath: \Post.index, ascending: true)]
        
        let request = NSFetchRequest<Post>(entityName: "Post")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        request.fetchOffset = (page - 1) * postsPerPage
        request.fetchLimit = postsPerPage
        
        do {
            return try context.fetch(request)
        } catch {
            print("Fetch posts error: \(error)")
            return []
        }
    }
    
    func fetchPost(by id: Int32) -> Post? {
        let predicate = NSPredicate(format: "id == %d", id)
        return fetchFirst(predicate: predicate)
    }
}
```

## Query Builder

### Advanced Querying
```swift
class QueryBuilder<T: NSManagedObject> {
    private var fetchRequest: NSFetchRequest<T>
    private var predicates: [NSPredicate] = []
    private var sortDescriptors: [NSSortDescriptor] = []
    
    init(entityName: String) {
        fetchRequest = NSFetchRequest<T>(entityName: entityName)
    }
    
    func `where`(_ predicate: NSPredicate) -> QueryBuilder<T> {
        predicates.append(predicate)
        return self
    }
    
    func `where`(_ format: String, _ args: CVarArg...) -> QueryBuilder<T> {
        let predicate = NSPredicate(format: format, arguments: getVaList(args))
        return self.where(predicate)
    }
    
    func orderBy(_ keyPath: String, ascending: Bool = true) -> QueryBuilder<T> {
        let sortDescriptor = NSSortDescriptor(key: keyPath, ascending: ascending)
        sortDescriptors.append(sortDescriptor)
        return self
    }
    
    func limit(_ limit: Int) -> QueryBuilder<T> {
        fetchRequest.fetchLimit = limit
        return self
    }
    
    func offset(_ offset: Int) -> QueryBuilder<T> {
        fetchRequest.fetchOffset = offset
        return self
    }
    
    func execute(in context: NSManagedObjectContext) -> [T] {
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        if !sortDescriptors.isEmpty {
            fetchRequest.sortDescriptors = sortDescriptors
        }
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Query execution error: \(error)")
            return []
        }
    }
    
    func executeFirst(in context: NSManagedObjectContext) -> T? {
        return limit(1).execute(in: context).first
    }
}

// Usage examples
let unreadThreads = QueryBuilder<Thread>(entityName: "Thread")
    .where("hasUnreadPosts == YES")
    .orderBy("lastPostDate", ascending: false)
    .execute(in: context)

let forumThreads = QueryBuilder<Thread>(entityName: "Thread")
    .where("forum.id == %d", forumId)
    .where("isHidden == NO")
    .orderBy("isSticky", ascending: false)
    .orderBy("lastPostDate", ascending: false)
    .limit(50)
    .execute(in: context)
```

## Migration Strategy

### Core Data Migration
```swift
// Migration manager
class CoreDataMigrationManager {
    static let shared = CoreDataMigrationManager()
    
    private let modelName = "AwfulModel"
    
    func migrateStoreIfNeeded() -> Bool {
        guard let storeURL = storeURL,
              let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil) else {
            return false
        }
        
        let currentModel = currentManagedObjectModel()
        
        if currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
            return true // No migration needed
        }
        
        return performMigration(storeURL: storeURL, metadata: metadata)
    }
    
    private func performMigration(storeURL: URL, metadata: [String: Any]) -> Bool {
        let migrationSteps = getMigrationSteps(for: metadata)
        
        for step in migrationSteps {
            do {
                try performMigrationStep(step, storeURL: storeURL)
            } catch {
                print("Migration step failed: \(error)")
                return false
            }
        }
        
        return true
    }
    
    private func performMigrationStep(_ step: MigrationStep, storeURL: URL) throws {
        let migrationManager = NSMigrationManager(sourceModel: step.sourceModel, destinationModel: step.destinationModel)
        
        let mappingModel = try NSMappingModel.inferredMappingModel(forSourceModel: step.sourceModel, destinationModel: step.destinationModel)
        
        let tempURL = storeURL.appendingPathExtension("temp")
        
        try migrationManager.migrateStore(
            from: storeURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            to: tempURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil,
            mappingModel: mappingModel
        )
        
        // Replace original store with migrated store
        try FileManager.default.removeItem(at: storeURL)
        try FileManager.default.moveItem(at: tempURL, to: storeURL)
    }
}

struct MigrationStep {
    let sourceModel: NSManagedObjectModel
    let destinationModel: NSManagedObjectModel
}
```

### Custom Migration Policies
```swift
class ThreadMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Custom migration logic for Thread entities
        let destinationThread = NSEntityDescription.entity(forEntityName: "Thread", in: manager.destinationContext)!
        let newThread = NSManagedObject(entity: destinationThread, insertInto: manager.destinationContext)
        
        // Migrate basic properties
        newThread.setValue(sInstance.value(forKey: "id"), forKey: "id")
        newThread.setValue(sInstance.value(forKey: "title"), forKey: "title")
        
        // Custom migration logic for new properties
        newThread.setValue(false, forKey: "hasUnreadPosts") // Default value for new property
        
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newThread, for: mapping)
    }
}
```

## Performance Optimization

### Batch Operations
```swift
extension PersistenceController {
    func batchInsert<T: NSManagedObject>(entities: [T], batchSize: Int = 1000) {
        let entityName = String(describing: T.self)
        
        for chunk in entities.chunked(into: batchSize) {
            performBackgroundTask { context in
                for entity in chunk {
                    // Create new entity in this context
                    let newEntity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
                    // Copy properties from original entity
                    self.copyProperties(from: entity, to: newEntity)
                }
            }
        }
    }
    
    func batchUpdate(entityName: String, predicate: NSPredicate, propertiesToUpdate: [String: Any]) {
        let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)
        batchUpdateRequest.predicate = predicate
        batchUpdateRequest.propertiesToUpdate = propertiesToUpdate
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        
        do {
            let result = try viewContext.execute(batchUpdateRequest) as? NSBatchUpdateResult
            
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes = [NSUpdatedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
            }
        } catch {
            print("Batch update error: \(error)")
        }
    }
    
    func batchDelete(entityName: String, predicate: NSPredicate) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = predicate
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try viewContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
            
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
            }
        } catch {
            print("Batch delete error: \(error)")
        }
    }
}
```

### Fetch Request Optimization
```swift
extension NSFetchRequest {
    func optimizeForPerformance() {
        // Optimize for performance
        includesSubentities = false
        includesPropertyValues = true
        returnsObjectsAsFaults = false
        
        // Set reasonable batch size
        fetchBatchSize = 20
        
        // Use appropriate relationship key paths
        relationshipKeyPathsForPrefetching = ["forum", "posts"]
    }
    
    func optimizeForMemory() {
        // Optimize for memory usage
        includesPropertyValues = false
        returnsObjectsAsFaults = true
        
        // Smaller batch size
        fetchBatchSize = 10
    }
}
```

## Cache Management

### Memory Management
```swift
class CacheManager {
    static let shared = CacheManager()
    
    private let memoryCache = NSCache<NSString, AnyObject>()
    private let diskCacheURL: URL
    
    init() {
        diskCacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DataCache")
        
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    func cleanupOldData() {
        // Remove data older than 30 days
        let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        
        let threadsRepository = ThreadsRepository()
        let oldThreadsPredicate = NSPredicate(format: "lastRefresh < %@", cutoffDate as NSDate)
        threadsRepository.deleteAll(predicate: oldThreadsPredicate)
        
        let postsRepository = PostsRepository()
        let oldPostsPredicate = NSPredicate(format: "thread.lastRefresh < %@", cutoffDate as NSDate)
        postsRepository.deleteAll(predicate: oldPostsPredicate)
    }
}
```

## Testing

### Core Data Testing
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
}

// Test example
class ForumsRepositoryTests: XCTestCase {
    var testStack: CoreDataTestStack!
    var repository: ForumsRepository!
    
    override func setUp() {
        super.setUp()
        testStack = CoreDataTestStack()
        repository = ForumsRepository(context: testStack.viewContext)
    }
    
    func testFetchVisibleForums() {
        // Given
        let forum1 = repository.create()
        forum1.id = 1
        forum1.title = "Forum 1"
        forum1.isHidden = false
        
        let forum2 = repository.create()
        forum2.id = 2
        forum2.title = "Forum 2"
        forum2.isHidden = true
        
        repository.save(forum1)
        repository.save(forum2)
        
        // When
        let visibleForums = repository.fetchVisibleForums()
        
        // Then
        XCTAssertEqual(visibleForums.count, 1)
        XCTAssertEqual(visibleForums[0].title, "Forum 1")
    }
}
```

## Best Practices

1. **Context Management**: Use appropriate contexts for different operations
2. **Performance**: Optimize fetch requests and use batch operations
3. **Memory Management**: Implement proper cache cleanup and memory warnings handling
4. **Migration**: Plan for schema changes with progressive migration
5. **Testing**: Use in-memory stores for testing
6. **Thread Safety**: Always perform Core Data operations on the correct queue
7. **Error Handling**: Implement comprehensive error handling for all operations
8. **Monitoring**: Track performance metrics and memory usage