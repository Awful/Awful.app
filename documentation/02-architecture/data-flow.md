# Data Flow

## Overview

This document describes how data flows through the Awful app, from network requests to UI updates, covering both the current UIKit implementation and the planned SwiftUI migration.

## Current UIKit Data Flow

### High-Level Architecture
```
UI (View Controllers) ← → NSFetchedResultsController ← → Core Data ← → ForumsClient ← → Network
```

### Detailed Flow Diagram
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  View Controller │────→│ NSFetchedResults │────→│   Core Data     │
│                 │     │   Controller     │     │    Context      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         ↑                        ↑                        ↑
         │                        │                        │
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
                                  ↓
                         ┌─────────────────┐
                         │  ForumsClient   │
                         │                 │
                         └─────────────────┘
                                  │
                                  ↓
                         ┌─────────────────┐
                         │    Network      │
                         │   (URLSession)  │
                         └─────────────────┘
```

### Example: Loading Forum Threads

#### 1. User Action
```swift
// ThreadsTableViewController
override func viewDidLoad() {
    super.viewDidLoad()
    setupFetchedResultsController()
    refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
}

@objc private func refresh() {
    ForumsClient.shared.loadThreads(for: forum) { [weak self] result in
        DispatchQueue.main.async {
            self?.refreshControl?.endRefreshing()
            // Handle result
        }
    }
}
```

#### 2. Network Request
```swift
// ForumsClient
func loadThreads(for forum: Forum, completion: @escaping (Result<[Thread], Error>) -> Void) {
    let url = URL(string: "https://forums.somethingawful.com/forumdisplay.php?forumid=\(forum.id)")!
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data, let html = String(data: data, encoding: .utf8) else {
            completion(.failure(NetworkError.invalidData))
            return
        }
        
        // Parse HTML and save to Core Data
        self.parseAndSaveThreads(html: html, forum: forum) { result in
            completion(result)
        }
    }.resume()
}
```

#### 3. HTML Parsing and Core Data Storage
```swift
// ForumsClient
private func parseAndSaveThreads(html: String, forum: Forum, completion: @escaping (Result<[Thread], Error>) -> Void) {
    let backgroundContext = persistentContainer.newBackgroundContext()
    
    backgroundContext.perform {
        do {
            let threads = self.parseThreadsFromHTML(html, context: backgroundContext, forum: forum)
            try backgroundContext.save()
            
            DispatchQueue.main.async {
                completion(.success(threads))
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
}
```

#### 4. UI Updates via NSFetchedResultsController
```swift
// ThreadsTableViewController
func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
}

func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, 
               didChange anObject: Any, 
               at indexPath: IndexPath?, 
               for type: NSFetchedResultsChangeType, 
               newIndexPath: IndexPath?) {
    switch type {
    case .insert:
        tableView.insertRows(at: [newIndexPath!], with: .automatic)
    case .update:
        tableView.reloadRows(at: [indexPath!], with: .automatic)
    case .delete:
        tableView.deleteRows(at: [indexPath!], with: .automatic)
    case .move:
        tableView.moveRow(at: indexPath!, to: newIndexPath!)
    @unknown default:
        tableView.reloadData()
    }
}
```

## SwiftUI Data Flow

### High-Level Architecture
```
SwiftUI Views ← → ObservableObject ViewModels ← → Repository/Service Layer ← → Core Data ← → Network
```

### Detailed Flow Diagram
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  SwiftUI View   │────→│ ObservableObject │────→│   Repository/   │
│                 │     │   ViewModel     │     │   Service       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         ↑                        ↑                        ↑
         │                        │                        │
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
                                  ↓
                         ┌─────────────────┐
                         │   Core Data     │
                         │  (@FetchRequest │
                         │ or Repository)  │
                         └─────────────────┘
                                  │
                                  ↓
                         ┌─────────────────┐
                         │    Network      │
                         │ (ForumsClient)  │
                         └─────────────────┘
```

### Example: SwiftUI Thread Loading

#### 1. SwiftUI View
```swift
struct ThreadsListView: View {
    @StateObject private var viewModel: ThreadsViewModel
    @FetchRequest private var threads: FetchedResults<Thread>
    
    init(forum: Forum) {
        self._viewModel = StateObject(wrappedValue: ThreadsViewModel(forum: forum))
        self._threads = FetchRequest(
            entity: Thread.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Thread.lastPostDate, ascending: false)],
            predicate: NSPredicate(format: "forum == %@", forum)
        )
    }
    
    var body: some View {
        List(threads) { thread in
            ThreadRowView(thread: thread)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            Task {
                await viewModel.loadThreadsIfNeeded()
            }
        }
    }
}
```

#### 2. ViewModel (ObservableObject)
```swift
@MainActor
class ThreadsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    
    private let forum: Forum
    private let threadsService: ThreadsService
    
    init(forum: Forum, threadsService: ThreadsService = ThreadsService()) {
        self.forum = forum
        self.threadsService = threadsService
    }
    
    func loadThreadsIfNeeded() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            try await threadsService.loadThreads(for: forum)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadThreadsIfNeeded()
    }
}
```

#### 3. Service Layer
```swift
class ThreadsService {
    private let forumsClient: ForumsClient
    private let repository: ThreadsRepository
    
    init(forumsClient: ForumsClient = .shared, repository: ThreadsRepository = CoreDataThreadsRepository()) {
        self.forumsClient = forumsClient
        self.repository = repository
    }
    
    func loadThreads(for forum: Forum) async throws {
        let threads = try await forumsClient.loadThreads(for: forum)
        await repository.save(threads)
    }
}
```

#### 4. Repository Layer
```swift
actor CoreDataThreadsRepository: ThreadsRepository {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    func save(_ threads: [Thread]) async {
        await context.perform {
            // Update existing threads or create new ones
            for thread in threads {
                // Core Data update logic
            }
            
            do {
                try self.context.save()
            } catch {
                print("Save failed: \(error)")
            }
        }
    }
}
```

## Data Flow Patterns

### 1. One-Way Data Flow
Data flows in a single direction to maintain predictability.

```swift
// SwiftUI: Action → State → View
struct ContentView: View {
    @State private var counter = 0
    
    var body: some View {
        VStack {
            Text("Count: \(counter)")  // State → View
            Button("Increment") {
                counter += 1           // Action → State
            }
        }
    }
}
```

### 2. Reactive Data Flow
Using Combine for reactive programming.

```swift
class ThreadsViewModel: ObservableObject {
    @Published var threads: [Thread] = []
    @Published var searchText = ""
    @Published var filteredThreads: [Thread] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Reactive filtering
        Publishers.CombineLatest($threads, $searchText)
            .map { threads, searchText in
                if searchText.isEmpty {
                    return threads
                } else {
                    return threads.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                }
            }
            .assign(to: \.filteredThreads, on: self)
            .store(in: &cancellables)
    }
}
```

### 3. Event-Driven Data Flow
Using notifications for decoupled communication.

```swift
// Publisher
extension Notification.Name {
    static let threadUpdated = Notification.Name("threadUpdated")
}

// Publisher
class ForumsClient {
    func markThreadAsRead(_ thread: Thread) {
        thread.hasUnreadPosts = false
        
        NotificationCenter.default.post(
            name: .threadUpdated, 
            object: thread
        )
    }
}

// Subscriber
class ThreadsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(threadUpdated),
            name: .threadUpdated,
            object: nil
        )
    }
    
    @objc private func threadUpdated(_ notification: Notification) {
        // Update UI
    }
}
```

## Core Data Integration

### Context Management
```swift
// Persistent container setup
class PersistenceController {
    static let shared = PersistenceController()
    
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
}
```

### Background Processing
```swift
// Background context for imports
private func performBackgroundImport(_ operation: @escaping (NSManagedObjectContext) -> Void) {
    let backgroundContext = PersistenceController.shared.newBackgroundContext()
    
    backgroundContext.perform {
        operation(backgroundContext)
        
        do {
            try backgroundContext.save()
        } catch {
            print("Background save failed: \(error)")
        }
    }
}
```

### Context Merging
```swift
// Automatic context merging
class DataManager {
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    @objc private func contextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        guard context != PersistenceController.shared.viewContext else { return }
        
        // Merge changes to main context
        PersistenceController.shared.viewContext.mergeChanges(fromContextDidSave: notification)
    }
}
```

## Error Handling in Data Flow

### Error Propagation
```swift
// Error handling through the data flow
enum DataError: Error {
    case networkError(Error)
    case parsingError(String)
    case coreDataError(Error)
}

// Service layer error handling
class ThreadsService {
    func loadThreads(for forum: Forum) async throws {
        do {
            let html = try await forumsClient.fetchHTML(for: forum)
            let threads = try parseThreads(from: html)
            try await repository.save(threads)
        } catch let error as NetworkError {
            throw DataError.networkError(error)
        } catch let error as ParsingError {
            throw DataError.parsingError(error.localizedDescription)
        } catch {
            throw DataError.coreDataError(error)
        }
    }
}
```

### SwiftUI Error Handling
```swift
struct ThreadsListView: View {
    @StateObject private var viewModel = ThreadsViewModel()
    
    var body: some View {
        List(viewModel.threads) { thread in
            ThreadRowView(thread: thread)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}
```

## Performance Considerations

### Lazy Loading
```swift
// Lazy loading for large datasets
struct ThreadsListView: View {
    @FetchRequest private var threads: FetchedResults<Thread>
    
    var body: some View {
        List {
            ForEach(threads) { thread in
                ThreadRowView(thread: thread)
                    .onAppear {
                        if thread == threads.last {
                            // Load more threads
                        }
                    }
            }
        }
    }
}
```

### Background Processing
```swift
// Offload heavy processing to background
class ForumsClient {
    func processLargeDataset() {
        DispatchQueue.global(qos: .background).async {
            // Heavy processing
            let result = self.performHeavyOperation()
            
            DispatchQueue.main.async {
                // Update UI
                self.updateUI(with: result)
            }
        }
    }
}
```

## Testing Data Flow

### Unit Testing ViewModels
```swift
class ThreadsViewModelTests: XCTestCase {
    func testLoadThreads() async {
        // Given
        let mockService = MockThreadsService()
        let viewModel = ThreadsViewModel(forum: testForum, threadsService: mockService)
        
        // When
        await viewModel.loadThreadsIfNeeded()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(mockService.loadThreadsCalled)
    }
}
```

### Integration Testing
```swift
class DataFlowIntegrationTests: XCTestCase {
    func testEndToEndDataFlow() async {
        // Given
        let expectation = XCTestExpectation(description: "Data flow completes")
        
        // When
        let viewModel = ThreadsViewModel(forum: testForum)
        await viewModel.loadThreadsIfNeeded()
        
        // Then
        // Verify data flows through all layers
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}
```

## Best Practices

1. **Single Source of Truth**: Use Core Data as the single source of truth
2. **Unidirectional Flow**: Data flows in one direction for predictability
3. **Separation of Concerns**: Keep network, parsing, and storage separate
4. **Error Handling**: Handle errors at appropriate levels
5. **Performance**: Use background contexts for heavy operations
6. **Testing**: Design data flow for testability