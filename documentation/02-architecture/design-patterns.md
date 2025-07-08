# Design Patterns

## Overview

This document outlines the key design patterns used throughout the Awful app, both in the existing UIKit implementation and the planned SwiftUI migration.

## Current UIKit Patterns

### Model-View-Controller (MVC)
The traditional iOS architecture pattern used throughout the app.

```swift
// Example: PostsPageViewController
class PostsPageViewController: UIViewController {
    // Model
    var thread: Thread?
    var posts: [Post] = []
    
    // View
    @IBOutlet weak var webView: WKWebView!
    
    // Controller logic
    override func viewDidLoad() {
        super.viewDidLoad()
        loadPosts()
    }
    
    private func loadPosts() {
        // Fetch and display posts
    }
}
```

### Delegation Pattern
Used extensively for communication between components.

```swift
// ForumsClient uses delegation for network responses
protocol ForumsClientDelegate: AnyObject {
    func forumsClient(_ client: ForumsClient, didLoadForum forum: Forum)
    func forumsClient(_ client: ForumsClient, didFailWithError error: Error)
}
```

### Observer Pattern
Core Data and NSNotificationCenter for data updates.

```swift
// NSFetchedResultsController for table view updates
class ThreadsTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
```

## SwiftUI Migration Patterns

### Model-View-ViewModel (MVVM)
The preferred pattern for SwiftUI architecture.

```swift
// ViewModel for thread list
class ThreadsViewModel: ObservableObject {
    @Published var threads: [Thread] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let forumsClient = ForumsClient.shared
    
    func loadThreads(for forum: Forum) {
        isLoading = true
        forumsClient.loadThreads(for: forum) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let threads):
                    self?.threads = threads
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }
}

// SwiftUI View
struct ThreadsListView: View {
    @StateObject private var viewModel = ThreadsViewModel()
    let forum: Forum
    
    var body: some View {
        List(viewModel.threads) { thread in
            ThreadRowView(thread: thread)
        }
        .onAppear {
            viewModel.loadThreads(for: forum)
        }
    }
}
```

### Unidirectional Data Flow
Data flows in one direction: View → ViewModel → Model.

```swift
// User action flows down
Button("Refresh") {
    viewModel.refresh() // View → ViewModel
}

// Data updates flow up
@Published var posts: [Post] = [] // Model → ViewModel → View
```

### Dependency Injection
Injecting dependencies for better testability.

```swift
// Protocol for testability
protocol ForumsClientProtocol {
    func loadThreads(for forum: Forum, completion: @escaping (Result<[Thread], Error>) -> Void)
}

// Production implementation
class ForumsClient: ForumsClientProtocol {
    // Implementation
}

// Mock for testing
class MockForumsClient: ForumsClientProtocol {
    // Mock implementation
}

// ViewModel with dependency injection
class ThreadsViewModel: ObservableObject {
    private let forumsClient: ForumsClientProtocol
    
    init(forumsClient: ForumsClientProtocol = ForumsClient.shared) {
        self.forumsClient = forumsClient
    }
}
```

## Core Data Patterns

### Active Record Pattern
Core Data entities with business logic methods.

```swift
// Thread entity with business logic
extension Thread {
    func markAsRead() {
        hasUnreadPosts = false
        lastReadPostIndex = postCount
    }
    
    func addPost(_ post: Post) {
        addToPosts(post)
        postCount += 1
    }
}
```

### Repository Pattern
Abstracting data access behind repositories.

```swift
// Repository protocol
protocol ThreadsRepository {
    func fetchThreads(for forum: Forum) -> [Thread]
    func save(_ thread: Thread)
    func delete(_ thread: Thread)
}

// Core Data implementation
class CoreDataThreadsRepository: ThreadsRepository {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchThreads(for forum: Forum) -> [Thread] {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.predicate = NSPredicate(format: "forum == %@", forum)
        return (try? context.fetch(request)) ?? []
    }
}
```

### Unit of Work Pattern
Batching multiple operations into a single transaction.

```swift
// Background context for bulk operations
private func performBulkUpdate(_ updates: @escaping (NSManagedObjectContext) -> Void) {
    let backgroundContext = container.newBackgroundContext()
    backgroundContext.perform {
        updates(backgroundContext)
        
        do {
            try backgroundContext.save()
        } catch {
            print("Background save failed: \(error)")
        }
    }
}
```

## Networking Patterns

### Adapter Pattern
Converting HTML responses to model objects.

```swift
// HTML to model adapter
class ForumScraper {
    func parseForums(from html: String) -> [Forum] {
        let document = HTMLDocument(string: html)
        return document.nodes(matchingSelector: "tr.forum")
            .compactMap { node in
                guard let title = node.firstNode(matchingSelector: "a.forum")?.textContent else {
                    return nil
                }
                let forum = Forum(context: context)
                forum.title = title
                return forum
            }
    }
}
```

### Strategy Pattern
Different parsing strategies for different forum sections.

```swift
// Parsing strategy protocol
protocol ForumParsingStrategy {
    func parse(_ html: String) -> [Forum]
}

// Specific strategies
class MainForumStrategy: ForumParsingStrategy {
    func parse(_ html: String) -> [Forum] {
        // Parse main forum list
    }
}

class PrivateMessagesStrategy: ForumParsingStrategy {
    func parse(_ html: String) -> [Forum] {
        // Parse private messages
    }
}

// Context using strategy
class ForumsParser {
    private var strategy: ForumParsingStrategy
    
    init(strategy: ForumParsingStrategy) {
        self.strategy = strategy
    }
    
    func parse(_ html: String) -> [Forum] {
        return strategy.parse(html)
    }
}
```

## UI Patterns

### Factory Pattern
Creating different cell types based on content.

```swift
// Cell factory
class PostCellFactory {
    static func createCell(for post: Post, in tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        switch post.type {
        case .text:
            return tableView.dequeueReusableCell(withIdentifier: "TextPostCell", for: indexPath)
        case .image:
            return tableView.dequeueReusableCell(withIdentifier: "ImagePostCell", for: indexPath)
        case .video:
            return tableView.dequeueReusableCell(withIdentifier: "VideoPostCell", for: indexPath)
        }
    }
}
```

### Command Pattern
Encapsulating user actions.

```swift
// Command protocol
protocol Command {
    func execute()
    func undo()
}

// Specific commands
class ReplyCommand: Command {
    private let thread: Thread
    private let message: String
    
    init(thread: Thread, message: String) {
        self.thread = thread
        self.message = message
    }
    
    func execute() {
        // Post reply
    }
    
    func undo() {
        // Delete reply
    }
}
```

### Coordinator Pattern
Managing navigation flow.

```swift
// Coordinator protocol
protocol Coordinator {
    func start()
    func showThread(_ thread: Thread)
    func showCompose(for thread: Thread)
}

// Main coordinator
class MainCoordinator: Coordinator {
    private weak var navigationController: UINavigationController?
    
    func start() {
        let forumsVC = ForumsTableViewController()
        forumsVC.coordinator = self
        navigationController?.pushViewController(forumsVC, animated: false)
    }
    
    func showThread(_ thread: Thread) {
        let postsVC = PostsPageViewController()
        postsVC.thread = thread
        navigationController?.pushViewController(postsVC, animated: true)
    }
}
```

## SwiftUI-Specific Patterns

### View Modifier Pattern
Reusable view modifications.

```swift
// Custom view modifier
struct ThemeModifier: ViewModifier {
    @EnvironmentObject var theme: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(theme.textColor)
            .background(theme.backgroundColor)
    }
}

// Extension for easy use
extension View {
    func themed() -> some View {
        self.modifier(ThemeModifier())
    }
}
```

### Environment Pattern
Sharing data across view hierarchy.

```swift
// Environment key
struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// Usage
struct ContentView: View {
    var body: some View {
        VStack {
            // Views here have access to theme
        }
        .environmentObject(ThemeManager.shared)
    }
}
```

### State Management Patterns
Different approaches to state management.

```swift
// Local state
struct CounterView: View {
    @State private var count = 0
    
    var body: some View {
        Button("Count: \(count)") {
            count += 1
        }
    }
}

// Shared state
struct SharedCounterView: View {
    @ObservedObject var counter: Counter
    
    var body: some View {
        Button("Count: \(counter.value)") {
            counter.increment()
        }
    }
}

// Global state
struct GlobalCounterView: View {
    @EnvironmentObject var globalState: GlobalState
    
    var body: some View {
        Button("Count: \(globalState.counter)") {
            globalState.incrementCounter()
        }
    }
}
```

## Testing Patterns

### Mock Pattern
Creating test doubles for dependencies.

```swift
// Mock ForumsClient
class MockForumsClient: ForumsClientProtocol {
    var shouldFail = false
    var mockThreads: [Thread] = []
    
    func loadThreads(for forum: Forum, completion: @escaping (Result<[Thread], Error>) -> Void) {
        if shouldFail {
            completion(.failure(NSError(domain: "Test", code: 0, userInfo: nil)))
        } else {
            completion(.success(mockThreads))
        }
    }
}
```

### Test Builder Pattern
Creating test data builders.

```swift
// Thread builder for tests
class ThreadBuilder {
    private var thread: Thread
    
    init(context: NSManagedObjectContext) {
        thread = Thread(context: context)
    }
    
    func withTitle(_ title: String) -> ThreadBuilder {
        thread.title = title
        return self
    }
    
    func withPostCount(_ count: Int) -> ThreadBuilder {
        thread.postCount = Int32(count)
        return self
    }
    
    func build() -> Thread {
        return thread
    }
}

// Usage in tests
let thread = ThreadBuilder(context: testContext)
    .withTitle("Test Thread")
    .withPostCount(10)
    .build()
```

## Anti-Patterns to Avoid

### 1. Massive View Controller
- Split large view controllers into smaller, focused components
- Use child view controllers or coordinators

### 2. Tight Coupling
- Use protocols and dependency injection
- Avoid direct references to concrete types

### 3. Global State Abuse
- Minimize global state usage
- Use appropriate state management patterns

### 4. SwiftUI State Misuse
- Don't use @State for shared data
- Use @StateObject for creating objects, @ObservedObject for receiving them

## Best Practices

1. **Consistency**: Use consistent patterns throughout the app
2. **Testability**: Design for testability from the beginning
3. **Separation of Concerns**: Keep models, views, and logic separate
4. **Performance**: Consider performance implications of pattern choices
5. **Documentation**: Document pattern usage and decisions