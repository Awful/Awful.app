# Data Binding Migration Guide

## Overview

This guide covers migrating Awful.app's Core Data integration from UIKit to SwiftUI, including NSFetchedResultsController replacement, data observation patterns, and maintaining data consistency.

## Current Data Architecture

### UIKit Implementation
```swift
// Current Core Data stack
class CoreDataManager: NSObject {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Awful")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
        return container
    }()
    
    var mainContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            try? context.save()
        }
    }
}

// Current view controller data binding
class ForumsTableViewController: UITableViewController {
    private var fetchedResultsController: NSFetchedResultsController<Forum>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFetchedResultsController()
    }
    
    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Forum> = Forum.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: CoreDataManager.shared.mainContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()
    }
}

// NSFetchedResultsControllerDelegate implementation
extension ForumsTableViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.reloadData()
    }
}
```

### Key Data Patterns
1. **NSFetchedResultsController**: Automatic data observation
2. **Background Context**: Data import and processing
3. **Main Context**: UI operations
4. **Manual Refresh**: Pull-to-refresh implementations
5. **Data Synchronization**: Server sync with local caching

## SwiftUI Migration Strategy

### Phase 1: Core Data Environment

Create SwiftUI Core Data environment:

```swift
// New CoreDataEnvironment.swift
@MainActor
class CoreDataEnvironment: ObservableObject {
    static let shared = CoreDataEnvironment()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Awful")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
        
        // Configure automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return container
    }()
    
    var mainContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func backgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return context
    }
    
    func save() {
        if mainContext.hasChanges {
            do {
                try mainContext.save()
            } catch {
                print("Core Data save error: \(error)")
            }
        }
    }
    
    func saveBackground(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Background context save error: \(error)")
            }
        }
    }
}

// Core Data environment key
private struct CoreDataEnvironmentKey: EnvironmentKey {
    static let defaultValue = CoreDataEnvironment.shared
}

extension EnvironmentValues {
    var coreData: CoreDataEnvironment {
        get { self[CoreDataEnvironmentKey.self] }
        set { self[CoreDataEnvironmentKey.self] = newValue }
    }
}
```

### Phase 2: SwiftUI Data Fetching

Replace NSFetchedResultsController with SwiftUI @FetchRequest:

```swift
// New SwiftUI data fetching
struct ForumsListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "index", ascending: true)],
        animation: .default
    ) private var forums: FetchedResults<Forum>
    
    @Environment(\.coreData) private var coreData
    @StateObject private var viewModel = ForumsViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(forums) { forum in
                    ForumRowView(forum: forum)
                }
            }
            .navigationTitle("Forums")
            .refreshable {
                await viewModel.refreshForums()
            }
            .onAppear {
                Task {
                    await viewModel.loadForumsIfNeeded()
                }
            }
        }
        .environmentObject(viewModel)
    }
}

// Forum row view
struct ForumRowView: View {
    let forum: Forum
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(forum.name ?? "Unknown Forum")
                .font(.headline)
            
            if let description = forum.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
```

### Phase 3: View Models for Data Management

Create view models that handle data operations:

```swift
// New ForumsViewModel.swift
@MainActor
class ForumsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastRefresh: Date?
    
    private let forumsClient = ForumsClient.shared
    private let coreData = CoreDataEnvironment.shared
    
    func loadForumsIfNeeded() async {
        guard shouldRefresh() else { return }
        await loadForums()
    }
    
    func refreshForums() async {
        await loadForums()
    }
    
    private func loadForums() async {
        isLoading = true
        error = nil
        
        do {
            let forums = try await forumsClient.loadForums()
            await updateForums(forums)
            lastRefresh = Date()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func updateForums(_ serverForums: [ForumData]) async {
        let backgroundContext = coreData.backgroundContext()
        
        await backgroundContext.perform {
            // Update or create forums
            for forumData in serverForums {
                let forum = self.findOrCreateForum(
                    with: forumData.id,
                    in: backgroundContext
                )
                forum.updateFromData(forumData)
            }
            
            // Remove forums no longer on server
            self.removeOldForums(
                keeping: serverForums.map { $0.id },
                in: backgroundContext
            )
            
            self.coreData.saveBackground(backgroundContext)
        }
    }
    
    private func findOrCreateForum(with id: String, in context: NSManagedObjectContext) -> Forum {
        let request: NSFetchRequest<Forum> = Forum.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        let forum = Forum(context: context)
        forum.id = id
        return forum
    }
    
    private func removeOldForums(keeping ids: [String], in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Forum> = Forum.fetchRequest()
        request.predicate = NSPredicate(format: "NOT (id IN %@)", ids)
        
        if let forumsToDelete = try? context.fetch(request) {
            for forum in forumsToDelete {
                context.delete(forum)
            }
        }
    }
    
    private func shouldRefresh() -> Bool {
        guard let lastRefresh = lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > 300 // 5 minutes
    }
}
```

### Phase 4: Complex Data Relationships

Handle complex data relationships and filtering:

```swift
// New ThreadsViewModel.swift
@MainActor
class ThreadsViewModel: ObservableObject {
    @Published var selectedForum: Forum?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let forumsClient = ForumsClient.shared
    private let coreData = CoreDataEnvironment.shared
    
    func loadThreads(for forum: Forum) async {
        selectedForum = forum
        isLoading = true
        error = nil
        
        do {
            let threads = try await forumsClient.loadThreads(for: forum.id ?? "")
            await updateThreads(threads, for: forum)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func updateThreads(_ serverThreads: [ThreadData], for forum: Forum) async {
        let backgroundContext = coreData.backgroundContext()
        
        await backgroundContext.perform {
            // Find forum in background context
            guard let forumId = forum.id,
                  let backgroundForum = self.findForum(with: forumId, in: backgroundContext) else {
                return
            }
            
            // Update threads
            for threadData in serverThreads {
                let thread = self.findOrCreateThread(
                    with: threadData.id,
                    in: backgroundContext
                )
                thread.updateFromData(threadData)
                thread.forum = backgroundForum
            }
            
            self.coreData.saveBackground(backgroundContext)
        }
    }
    
    private func findForum(with id: String, in context: NSManagedObjectContext) -> Forum? {
        let request: NSFetchRequest<Forum> = Forum.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    private func findOrCreateThread(with id: String, in context: NSManagedObjectContext) -> Thread {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        let thread = Thread(context: context)
        thread.id = id
        return thread
    }
}

// Threads view with dynamic filtering
struct ThreadsListView: View {
    let forum: Forum
    
    @FetchRequest private var threads: FetchedResults<Thread>
    @StateObject private var viewModel = ThreadsViewModel()
    
    init(forum: Forum) {
        self.forum = forum
        
        // Dynamic fetch request based on forum
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.predicate = NSPredicate(format: "forum == %@", forum)
        request.sortDescriptors = [
            NSSortDescriptor(key: "sticky", ascending: false),
            NSSortDescriptor(key: "lastPostDate", ascending: false)
        ]
        
        self._threads = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(threads) { thread in
                    ThreadRowView(thread: thread)
                }
            }
            .navigationTitle(forum.name ?? "Threads")
            .refreshable {
                await viewModel.loadThreads(for: forum)
            }
            .onAppear {
                Task {
                    await viewModel.loadThreads(for: forum)
                }
            }
        }
        .environmentObject(viewModel)
    }
}
```

### Phase 5: Advanced Data Operations

Implement advanced data operations and caching:

```swift
// New DataCache.swift
@MainActor
class DataCache: ObservableObject {
    private let coreData = CoreDataEnvironment.shared
    private var cachedQueries: [String: Date] = [:]
    
    func isCacheValid(for key: String, maxAge: TimeInterval = 300) -> Bool {
        guard let cacheDate = cachedQueries[key] else { return false }
        return Date().timeIntervalSince(cacheDate) < maxAge
    }
    
    func markCacheUpdated(for key: String) {
        cachedQueries[key] = Date()
    }
    
    func clearCache() {
        cachedQueries.removeAll()
    }
    
    // Batch operations
    func batchUpdate<T: NSManagedObject>(
        _ type: T.Type,
        updates: [(T) -> Void]
    ) async {
        let backgroundContext = coreData.backgroundContext()
        
        await backgroundContext.perform {
            for update in updates {
                let object = T(context: backgroundContext)
                update(object)
            }
            
            self.coreData.saveBackground(backgroundContext)
        }
    }
    
    // Efficient deletion
    func batchDelete<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate
    ) async {
        let backgroundContext = coreData.backgroundContext()
        
        await backgroundContext.perform {
            let request = NSFetchRequest<T>(entityName: String(describing: type))
            request.predicate = predicate
            
            if let objects = try? backgroundContext.fetch(request) {
                for object in objects {
                    backgroundContext.delete(object)
                }
            }
            
            self.coreData.saveBackground(backgroundContext)
        }
    }
}
```

## Migration Steps

### Step 1: Setup Core Data Environment (Week 1)
1. **Create CoreDataEnvironment**: Observable Core Data manager
2. **Setup Environment Integration**: Inject into SwiftUI environment
3. **Test Basic Operations**: Verify save/fetch works
4. **Migrate Simple Views**: Convert basic list views

### Step 2: Replace NSFetchedResultsController (Week 2)
1. **Convert @FetchRequest**: Replace fetched results controllers
2. **Create View Models**: Data management layer
3. **Implement Refresh Logic**: Pull-to-refresh functionality
4. **Test Data Updates**: Verify automatic UI updates

### Step 3: Advanced Data Operations (Week 3)
1. **Implement Data Cache**: Efficient caching layer
2. **Add Batch Operations**: Bulk data updates
3. **Handle Relationships**: Complex data relationships
4. **Optimize Performance**: Memory and CPU optimization

### Step 4: Data Synchronization (Week 3)
1. **Background Sync**: Server synchronization
2. **Conflict Resolution**: Data merge strategies
3. **Offline Support**: Cached data handling
4. **Error Recovery**: Data consistency checks

## Custom Data Patterns

### Custom FetchRequest
```swift
// Custom fetch request for complex filtering
struct DynamicFetchRequest<T: NSManagedObject>: View {
    let fetchRequest: NSFetchRequest<T>
    let content: (FetchedResults<T>) -> Content
    
    @FetchRequest private var results: FetchedResults<T>
    
    init(
        fetchRequest: NSFetchRequest<T>,
        @ViewBuilder content: @escaping (FetchedResults<T>) -> Content
    ) {
        self.fetchRequest = fetchRequest
        self.content = content
        self._results = FetchRequest(fetchRequest: fetchRequest)
    }
    
    var body: some View {
        content(results)
    }
}
```

### Data Observation
```swift
// Custom data observer for non-FetchRequest scenarios
@MainActor
class DataObserver<T: NSManagedObject>: ObservableObject {
    @Published var objects: [T] = []
    
    private let context: NSManagedObjectContext
    private let predicate: NSPredicate?
    private var observer: NSObjectProtocol?
    
    init(context: NSManagedObjectContext, predicate: NSPredicate? = nil) {
        self.context = context
        self.predicate = predicate
        setupObserver()
        loadObjects()
    }
    
    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: context,
            queue: .main
        ) { [weak self] _ in
            self?.loadObjects()
        }
    }
    
    private func loadObjects() {
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
        request.predicate = predicate
        
        do {
            objects = try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
```

## Risk Mitigation

### High-Risk Areas
1. **Data Migration**: Existing data compatibility
2. **Performance**: Large dataset handling
3. **Relationships**: Complex object relationships
4. **Concurrency**: Background/main context synchronization

### Mitigation Strategies
1. **Incremental Migration**: Migrate views one at a time
2. **Performance Testing**: Monitor memory and CPU usage
3. **Data Validation**: Verify data integrity
4. **Backup Strategy**: Maintain data backups

## Testing Strategy

### Unit Tests
```swift
// CoreDataEnvironmentTests.swift
class CoreDataEnvironmentTests: XCTestCase {
    var coreData: CoreDataEnvironment!
    
    override func setUp() {
        coreData = CoreDataEnvironment()
    }
    
    func testSaveContext() {
        let forum = Forum(context: coreData.mainContext)
        forum.name = "Test Forum"
        
        coreData.save()
        
        XCTAssertFalse(coreData.mainContext.hasChanges)
    }
    
    func testBackgroundContextSave() async {
        let backgroundContext = coreData.backgroundContext()
        
        await backgroundContext.perform {
            let forum = Forum(context: backgroundContext)
            forum.name = "Background Forum"
            
            self.coreData.saveBackground(backgroundContext)
        }
        
        // Verify main context received update
        let request: NSFetchRequest<Forum> = Forum.fetchRequest()
        let forums = try? coreData.mainContext.fetch(request)
        XCTAssertEqual(forums?.count, 1)
    }
}
```

### Integration Tests
```swift
// DataBindingIntegrationTests.swift
class DataBindingIntegrationTests: XCTestCase {
    func testFetchRequestUpdates() {
        // Test @FetchRequest automatic updates
        // Create view with @FetchRequest
        // Modify data in background
        // Verify UI updates automatically
    }
    
    func testViewModelDataFlow() {
        // Test view model data operations
        // Load data through view model
        // Verify Core Data updates
        // Test error handling
    }
}
```

## Performance Considerations

### Memory Management
- Use background contexts for data imports
- Implement proper fault handling
- Use `NSFetchRequest` batch sizes
- Clean up unused objects

### Query Optimization
- Use proper fetch request predicates
- Implement efficient sorting
- Use `NSFetchedResultsController` alternatives
- Minimize object faulting

### Batch Operations
- Use batch inserts for large datasets
- Implement efficient batch deletions
- Use `NSBatchUpdateRequest` for bulk updates
- Minimize context saves

## Timeline Estimation

### Conservative Estimate: 3 weeks
- **Week 1**: Core Data environment setup
- **Week 2**: Basic data binding migration
- **Week 3**: Advanced operations and optimization

### Aggressive Estimate: 2 weeks
- Assumes simple data operations
- Minimal performance optimization
- No complex relationship handling

## Dependencies

### Internal Dependencies
- CoreDataEnvironment: Core Data management
- View Models: Data operation layer
- DataCache: Caching layer

### External Dependencies
- Core Data: Data persistence
- SwiftUI: UI framework
- Combine: Reactive programming

## Success Criteria

### Functional Requirements
- [ ] All data operations work identically
- [ ] Automatic UI updates work correctly
- [ ] Background data sync works
- [ ] Data relationships preserved
- [ ] Error handling works properly

### Technical Requirements
- [ ] No memory leaks in data operations
- [ ] Efficient query performance
- [ ] Proper context management
- [ ] Thread-safe operations
- [ ] Data integrity maintained

### Performance Requirements
- [ ] Smooth scrolling with large datasets
- [ ] Efficient data loading
- [ ] Minimal memory usage
- [ ] Fast app launch times
- [ ] Responsive UI interactions

## Migration Checklist

### Pre-Migration
- [ ] Review current Core Data usage
- [ ] Identify data access patterns
- [ ] Document data relationships
- [ ] Prepare test data

### During Migration
- [ ] Create Core Data environment
- [ ] Convert fetch requests
- [ ] Implement view models
- [ ] Add data caching
- [ ] Test data operations

### Post-Migration
- [ ] Verify data integrity
- [ ] Test all data flows
- [ ] Validate performance
- [ ] Update documentation
- [ ] Deploy to beta testing

This migration guide provides a comprehensive approach to converting Core Data integration while maintaining data integrity and performance.