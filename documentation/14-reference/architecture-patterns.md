# Architecture Patterns Reference

Comprehensive guide to the design patterns and architectural approaches used in Awful.app.

## Table of Contents

- [Overall Architecture](#overall-architecture)
- [Model-View-Controller (MVC)](#model-view-controller-mvc)
- [Coordinator Pattern](#coordinator-pattern)
- [Repository Pattern](#repository-pattern)
- [Observer Pattern](#observer-pattern)
- [Delegate Pattern](#delegate-pattern)
- [Factory Pattern](#factory-pattern)
- [Singleton Pattern](#singleton-pattern)
- [Strategy Pattern](#strategy-pattern)
- [Command Pattern](#command-pattern)
- [Builder Pattern](#builder-pattern)
- [Adapter Pattern](#adapter-pattern)

## Overall Architecture

Awful.app follows a modular architecture with clear separation of concerns:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   UI Layer      │    │  Business Layer │    │   Data Layer    │
│                 │    │                 │    │                 │
│ • View Controllers │    │ • ForumsClient   │    │ • Core Data     │
│ • Views         │    │ • Theme System   │    │ • Network Cache │
│ • Storyboards   │    │ • Settings       │    │ • File Storage  │
│ • SwiftUI       │◄──►│ • Use Cases      │◄──►│ • Keychain      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Architectural Layers

1. **UI Layer**: View controllers, views, and user interface components
2. **Business Layer**: Application logic, use cases, and domain models
3. **Data Layer**: Persistence, networking, and data management

### Key Principles

- **Separation of Concerns**: Each component has a single responsibility
- **Dependency Inversion**: High-level modules don't depend on low-level modules
- **Loose Coupling**: Components are minimally dependent on each other
- **High Cohesion**: Related functionality is grouped together

## Model-View-Controller (MVC)

The primary architectural pattern used throughout the iOS app.

### Implementation

```swift
// MARK: - Model
class Thread: AwfulManagedObject {
    @NSManaged var threadID: String
    @NSManaged var title: String?
    @NSManaged var totalReplies: Int32
    
    // Business logic
    func isUnread(for user: User) -> Bool {
        return seenPosts < totalReplies
    }
}

// MARK: - View
class ThreadCell: UITableViewCell {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var replyCountLabel: UILabel!
    @IBOutlet private weak var unreadIndicator: UIView!
    
    func configure(with thread: Thread, user: User) {
        titleLabel.text = thread.title
        replyCountLabel.text = "\(thread.totalReplies)"
        unreadIndicator.isHidden = !thread.isUnread(for: user)
    }
}

// MARK: - Controller
class ThreadsTableViewController: UITableViewController {
    private var forum: Forum?
    private var threads: [Thread] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadThreads()
    }
    
    private func loadThreads() {
        // Coordinate between model and view
        ForumsClient.shared.listThreads(in: forum) { [weak self] result in
            switch result {
            case .success(let threads):
                self?.threads = threads
                self?.tableView.reloadData()
            case .failure(let error):
                self?.showError(error)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ThreadCell", for: indexPath) as! ThreadCell
        let thread = threads[indexPath.row]
        cell.configure(with: thread, user: currentUser)
        return cell
    }
}
```

### MVC Benefits

- **Familiar Pattern**: Well-understood by iOS developers
- **Framework Support**: Native UIKit support
- **Clear Responsibilities**: Distinct roles for each component

### MVC Challenges

- **Massive View Controllers**: Controllers can become large
- **Tight Coupling**: Views often tightly coupled to controllers
- **Testing Difficulty**: Business logic mixed with UI logic

## Coordinator Pattern

Used for navigation flow management and reducing view controller coupling.

### Implementation

```swift
// MARK: - Coordinator Protocol
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    var childCoordinators: [Coordinator] { get set }
    
    func start()
    func finish()
}

// MARK: - Main Coordinator
class MainCoordinator: Coordinator {
    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        showForumsList()
    }
    
    func showForumsList() {
        let forumsVC = ForumsTableViewController()
        forumsVC.coordinator = self
        navigationController.pushViewController(forumsVC, animated: false)
    }
    
    func showThreads(in forum: Forum) {
        let threadsVC = ThreadsTableViewController(forum: forum)
        threadsVC.coordinator = self
        navigationController.pushViewController(threadsVC, animated: true)
    }
    
    func showPosts(in thread: AwfulThread) {
        let postsVC = PostsPageViewController(thread: thread)
        postsVC.coordinator = self
        navigationController.pushViewController(postsVC, animated: true)
    }
}

// MARK: - Forum Coordinator
class ForumCoordinator: Coordinator {
    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    private let forum: Forum
    
    init(navigationController: UINavigationController, forum: Forum) {
        self.navigationController = navigationController
        self.forum = forum
    }
    
    func start() {
        showThreadsList()
    }
    
    private func showThreadsList() {
        let threadsVC = ThreadsTableViewController(forum: forum)
        threadsVC.delegate = self
        navigationController.pushViewController(threadsVC, animated: true)
    }
}

extension ForumCoordinator: ThreadsTableViewControllerDelegate {
    func threadsViewController(_ controller: ThreadsTableViewController, didSelectThread thread: AwfulThread) {
        let postsCoordinator = PostsCoordinator(navigationController: navigationController, thread: thread)
        childCoordinators.append(postsCoordinator)
        postsCoordinator.start()
    }
}
```

### Coordinator Benefits

- **Decoupled Navigation**: View controllers don't know about navigation
- **Reusable Flows**: Navigation flows can be reused
- **Testable**: Navigation logic can be unit tested
- **Clear Flow**: Complex navigation flows are clearly defined

## Repository Pattern

Abstracts data access and provides a clean API for data operations.

### Implementation

```swift
// MARK: - Repository Protocol
protocol ThreadRepository {
    func getThreads(in forum: Forum, page: Int) async throws -> [AwfulThread]
    func getBookmarkedThreads(page: Int) async throws -> [AwfulThread]
    func bookmarkThread(_ thread: AwfulThread) async throws
    func unbookmarkThread(_ thread: AwfulThread) async throws
}

// MARK: - Core Data Repository
class CoreDataThreadRepository: ThreadRepository {
    private let managedObjectContext: NSManagedObjectContext
    private let forumsClient: ForumsClient
    
    init(managedObjectContext: NSManagedObjectContext, forumsClient: ForumsClient) {
        self.managedObjectContext = managedObjectContext
        self.forumsClient = forumsClient
    }
    
    func getThreads(in forum: Forum, page: Int) async throws -> [AwfulThread] {
        // Try to get from cache first
        let cachedThreads = try fetchCachedThreads(in: forum, page: page)
        if !cachedThreads.isEmpty && isCacheValid(for: forum) {
            return cachedThreads
        }
        
        // Fetch from network
        let networkThreads = try await forumsClient.listThreads(in: forum, page: page)
        
        // Update cache
        try await updateCache(with: networkThreads, in: forum, page: page)
        
        return networkThreads
    }
    
    func getBookmarkedThreads(page: Int) async throws -> [AwfulThread] {
        return try await forumsClient.listBookmarkedThreads(page: page)
    }
    
    func bookmarkThread(_ thread: AwfulThread) async throws {
        try await forumsClient.setThread(thread, isBookmarked: true)
        
        // Update local cache
        await managedObjectContext.perform {
            thread.bookmarked = true
            try? self.managedObjectContext.save()
        }
    }
    
    func unbookmarkThread(_ thread: AwfulThread) async throws {
        try await forumsClient.setThread(thread, isBookmarked: false)
        
        // Update local cache
        await managedObjectContext.perform {
            thread.bookmarked = false
            try? self.managedObjectContext.save()
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchCachedThreads(in forum: Forum, page: Int) throws -> [AwfulThread] {
        let request: NSFetchRequest<AwfulThread> = AwfulThread.fetchRequest()
        request.predicate = NSPredicate(format: "forum == %@ AND threadListPage == %d", forum, page)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AwfulThread.lastPostDate, ascending: false)]
        
        return try managedObjectContext.fetch(request)
    }
    
    private func isCacheValid(for forum: Forum) -> Bool {
        guard let lastRefresh = forum.lastRefresh else { return false }
        return Date().timeIntervalSince(lastRefresh) < 300 // 5 minutes
    }
    
    private func updateCache(with threads: [AwfulThread], in forum: Forum, page: Int) async throws {
        try await managedObjectContext.perform {
            forum.lastRefresh = Date()
            for thread in threads {
                thread.threadListPage = Int32(page)
            }
            try self.managedObjectContext.save()
        }
    }
}

// MARK: - Usage
class ThreadsViewController: UIViewController {
    private let repository: ThreadRepository
    
    init(repository: ThreadRepository) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }
    
    private func loadThreads() async {
        do {
            let threads = try await repository.getThreads(in: forum, page: currentPage)
            await updateUI(with: threads)
        } catch {
            await showError(error)
        }
    }
}
```

### Repository Benefits

- **Abstraction**: Hides data source implementation details
- **Testability**: Easy to mock for unit tests
- **Caching Strategy**: Centralized caching logic
- **Consistency**: Uniform data access patterns

## Observer Pattern

Used extensively for responding to data changes and user interface updates.

### NSFetchedResultsController

```swift
class ThreadsTableViewController: UITableViewController {
    private var fetchedResultsController: NSFetchedResultsController<AwfulThread>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFetchedResultsController()
    }
    
    private func setupFetchedResultsController() {
        let request: NSFetchRequest<AwfulThread> = AwfulThread.fetchRequest()
        request.predicate = NSPredicate(format: "forum == %@", forum)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AwfulThread.sticky, ascending: false),
            NSSortDescriptor(keyPath: \AwfulThread.lastPostDate, ascending: false)
        ]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("Failed to fetch threads: \(error)")
        }
    }
}

extension ThreadsTableViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .none)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        @unknown default:
            fatalError("Unknown change type")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
```

### NotificationCenter Observer

```swift
class ThemeObserver {
    private var themeChangeObserver: NSObjectProtocol?
    
    init() {
        setupThemeObserver()
    }
    
    deinit {
        if let observer = themeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupThemeObserver() {
        themeChangeObserver = NotificationCenter.default.addObserver(
            forName: Theme.themeForForumDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleThemeChange(notification)
        }
    }
    
    private func handleThemeChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let forumID = userInfo[Theme.forumIDKey] as? String else { return }
        
        if forumID == currentForumID {
            updateTheme()
        }
    }
}
```

### Property Observers

```swift
class PostsPageViewController: UIViewController {
    var thread: AwfulThread? {
        didSet {
            guard oldValue != thread else { return }
            threadDidChange()
        }
    }
    
    var currentPage: ThreadPage = .specific(1) {
        didSet {
            guard oldValue != currentPage else { return }
            pageDidChange()
        }
    }
    
    private func threadDidChange() {
        title = thread?.title
        loadPosts()
    }
    
    private func pageDidChange() {
        loadPosts()
    }
}
```

## Delegate Pattern

Used for communication between objects, especially view controllers and their components.

### Implementation

```swift
// MARK: - Delegate Protocol
protocol PostsPageViewControllerDelegate: AnyObject {
    func postsViewController(_ controller: PostsPageViewController, didSelectPost post: Post)
    func postsViewController(_ controller: PostsPageViewController, didReplyToThread thread: AwfulThread)
    func postsViewControllerDidRequestRefresh(_ controller: PostsPageViewController)
}

// MARK: - View Controller
class PostsPageViewController: UIViewController {
    weak var delegate: PostsPageViewControllerDelegate?
    
    private func handlePostSelection(_ post: Post) {
        delegate?.postsViewController(self, didSelectPost: post)
    }
    
    private func handleReplyCompletion() {
        delegate?.postsViewController(self, didReplyToThread: thread)
    }
    
    @IBAction private func refreshButtonTapped(_ sender: UIBarButtonItem) {
        delegate?.postsViewControllerDidRequestRefresh(self)
    }
}

// MARK: - Delegate Implementation
class MainViewController: UIViewController {
    private func showPosts(for thread: AwfulThread) {
        let postsVC = PostsPageViewController(thread: thread)
        postsVC.delegate = self
        navigationController?.pushViewController(postsVC, animated: true)
    }
}

extension MainViewController: PostsPageViewControllerDelegate {
    func postsViewController(_ controller: PostsPageViewController, didSelectPost post: Post) {
        // Handle post selection
        showPostActions(for: post)
    }
    
    func postsViewController(_ controller: PostsPageViewController, didReplyToThread thread: AwfulThread) {
        // Handle reply completion
        controller.refresh()
    }
    
    func postsViewControllerDidRequestRefresh(_ controller: PostsPageViewController) {
        // Handle refresh request
        Task {
            try await controller.loadPosts()
        }
    }
}
```

### UITableView Delegate Pattern

```swift
class ThreadsTableViewController: UITableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let thread = fetchedResultsController.object(at: indexPath)
        coordinator?.showPosts(in: thread)
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let thread = fetchedResultsController.object(at: indexPath)
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            self.makeContextMenu(for: thread)
        }
    }
    
    private func makeContextMenu(for thread: AwfulThread) -> UIMenu {
        let bookmarkAction = UIAction(
            title: thread.bookmarked ? "Remove Bookmark" : "Add Bookmark",
            image: UIImage(systemName: thread.bookmarked ? "bookmark.fill" : "bookmark")
        ) { _ in
            self.toggleBookmark(for: thread)
        }
        
        let copyAction = UIAction(
            title: "Copy Link",
            image: UIImage(systemName: "link")
        ) { _ in
            self.copyLink(for: thread)
        }
        
        return UIMenu(title: "", children: [bookmarkAction, copyAction])
    }
}
```

## Factory Pattern

Used for creating objects with complex initialization or multiple variants.

### Theme Factory

```swift
// MARK: - Factory Protocol
protocol ThemeFactory {
    func makeTheme(named name: String) -> Theme?
    func makeDefaultTheme(for mode: Theme.Mode) -> Theme
    func makeForumSpecificTheme(for forumID: String, mode: Theme.Mode) -> Theme
}

// MARK: - Factory Implementation
class DefaultThemeFactory: ThemeFactory {
    private let bundledThemes: [String: Theme]
    
    init() {
        self.bundledThemes = Self.loadBundledThemes()
    }
    
    func makeTheme(named name: String) -> Theme? {
        return bundledThemes[name]
    }
    
    func makeDefaultTheme(for mode: Theme.Mode) -> Theme {
        let themeName = mode == .dark ? "dark" : "default"
        return bundledThemes[themeName] ?? bundledThemes["default"]!
    }
    
    func makeForumSpecificTheme(for forumID: String, mode: Theme.Mode) -> Theme {
        // Check for forum-specific theme
        let key = "theme-\(mode.rawValue)-\(forumID)"
        if let themeName = UserDefaults.standard.string(forKey: key),
           let theme = bundledThemes[themeName] {
            return theme
        }
        
        // Fall back to default theme
        return makeDefaultTheme(for: mode)
    }
    
    private static func loadBundledThemes() -> [String: Theme] {
        guard let url = Bundle.main.url(forResource: "Themes", withExtension: "plist"),
              let plist = NSDictionary(contentsOf: url) as? [String: Any] else {
            fatalError("Could not load Themes.plist")
        }
        
        var themes: [String: Theme] = [:]
        
        // Create theme objects
        for (name, dictionary) in plist {
            themes[name] = Theme(name: name, dictionary: dictionary as! [String: Any])
        }
        
        // Set up parent relationships
        for (name, theme) in themes {
            if name != "default" {
                let parentName = theme.dictionary["parent"] as? String ?? "default"
                theme.parent = themes[parentName]
            }
        }
        
        return themes
    }
}
```

### View Controller Factory

```swift
// MARK: - View Controller Factory
class ViewControllerFactory {
    private let dataStore: DataStore
    private let forumsClient: ForumsClient
    
    init(dataStore: DataStore, forumsClient: ForumsClient) {
        self.dataStore = dataStore
        self.forumsClient = forumsClient
    }
    
    func makeForumsTableViewController() -> ForumsTableViewController {
        let controller = ForumsTableViewController()
        controller.managedObjectContext = dataStore.mainManagedObjectContext
        controller.forumsClient = forumsClient
        return controller
    }
    
    func makeThreadsTableViewController(forum: Forum) -> ThreadsTableViewController {
        let controller = ThreadsTableViewController(forum: forum)
        controller.managedObjectContext = dataStore.mainManagedObjectContext
        controller.forumsClient = forumsClient
        return controller
    }
    
    func makePostsPageViewController(thread: AwfulThread) -> PostsPageViewController {
        let controller = PostsPageViewController(thread: thread)
        controller.forumsClient = forumsClient
        return controller
    }
    
    func makeComposeViewController(thread: AwfulThread?) -> ComposeViewController {
        let controller = ComposeViewController()
        controller.thread = thread
        controller.forumsClient = forumsClient
        return controller
    }
}
```

## Singleton Pattern

Used sparingly for truly global state and shared resources.

### ForumsClient Singleton

```swift
public final class ForumsClient {
    /// Shared instance for convenience
    public static let shared = ForumsClient()
    
    private init() {
        // Private initializer prevents external instantiation
    }
    
    // Rest of the implementation...
}

// Usage
let client = ForumsClient.shared
```

### DataStore Singleton

```swift
public class DataStore {
    public static let shared = DataStore()
    
    private init() {
        setupCoreDataStack()
    }
    
    private func setupCoreDataStack() {
        // Core Data setup
    }
}
```

### Singleton Guidelines

- Use sparingly - prefer dependency injection
- Consider thread safety
- Make initialization idempotent
- Provide clear documentation about shared state

## Strategy Pattern

Used for algorithmic variations and platform-specific behavior.

### Refresh Strategy

```swift
// MARK: - Strategy Protocol
protocol RefreshStrategy {
    func refresh() async throws
    var isRefreshing: Bool { get }
    func cancel()
}

// MARK: - Pull-to-Refresh Strategy
class PullToRefreshStrategy: RefreshStrategy {
    private let tableView: UITableView
    private let dataSource: RefreshableDataSource
    private var refreshControl: UIRefreshControl?
    
    init(tableView: UITableView, dataSource: RefreshableDataSource) {
        self.tableView = tableView
        self.dataSource = dataSource
        setupRefreshControl()
    }
    
    var isRefreshing: Bool {
        return refreshControl?.isRefreshing ?? false
    }
    
    func refresh() async throws {
        await MainActor.run {
            refreshControl?.beginRefreshing()
        }
        
        defer {
            Task { @MainActor in
                refreshControl?.endRefreshing()
            }
        }
        
        try await dataSource.refresh()
    }
    
    func cancel() {
        refreshControl?.endRefreshing()
        dataSource.cancelRefresh()
    }
    
    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    @objc private func handleRefresh() {
        Task {
            try await refresh()
        }
    }
}

// MARK: - Manual Refresh Strategy
class ManualRefreshStrategy: RefreshStrategy {
    private let dataSource: RefreshableDataSource
    private var _isRefreshing = false
    
    init(dataSource: RefreshableDataSource) {
        self.dataSource = dataSource
    }
    
    var isRefreshing: Bool {
        return _isRefreshing
    }
    
    func refresh() async throws {
        _isRefreshing = true
        defer { _isRefreshing = false }
        
        try await dataSource.refresh()
    }
    
    func cancel() {
        dataSource.cancelRefresh()
        _isRefreshing = false
    }
}

// MARK: - Context
class ThreadsTableViewController: UITableViewController {
    private var refreshStrategy: RefreshStrategy?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Choose strategy based on device or user preference
        if UIDevice.current.userInterfaceIdiom == .pad {
            refreshStrategy = ManualRefreshStrategy(dataSource: self)
        } else {
            refreshStrategy = PullToRefreshStrategy(tableView: tableView, dataSource: self)
        }
    }
    
    func refresh() {
        Task {
            try await refreshStrategy?.refresh()
        }
    }
}
```

## Command Pattern

Used for encapsulating operations, especially for undo/redo functionality.

### Post Action Commands

```swift
// MARK: - Command Protocol
protocol Command {
    func execute() async throws
    func undo() async throws
    var canUndo: Bool { get }
}

// MARK: - Bookmark Command
class BookmarkThreadCommand: Command {
    private let thread: AwfulThread
    private let forumsClient: ForumsClient
    private let wasBookmarked: Bool
    
    init(thread: AwfulThread, forumsClient: ForumsClient) {
        self.thread = thread
        self.forumsClient = forumsClient
        self.wasBookmarked = thread.bookmarked
    }
    
    func execute() async throws {
        try await forumsClient.setThread(thread, isBookmarked: !wasBookmarked)
    }
    
    func undo() async throws {
        try await forumsClient.setThread(thread, isBookmarked: wasBookmarked)
    }
    
    var canUndo: Bool { true }
}

// MARK: - Command Manager
class CommandManager {
    private var commandHistory: [Command] = []
    private var currentIndex = -1
    
    func execute(_ command: Command) async throws {
        try await command.execute()
        
        // Remove any commands after current index (for new branch)
        commandHistory.removeSubrange((currentIndex + 1)...)
        
        // Add new command
        commandHistory.append(command)
        currentIndex += 1
        
        // Limit history size
        if commandHistory.count > 50 {
            commandHistory.removeFirst()
            currentIndex -= 1
        }
    }
    
    func undo() async throws {
        guard canUndo else { return }
        
        let command = commandHistory[currentIndex]
        try await command.undo()
        currentIndex -= 1
    }
    
    func redo() async throws {
        guard canRedo else { return }
        
        currentIndex += 1
        let command = commandHistory[currentIndex]
        try await command.execute()
    }
    
    var canUndo: Bool {
        currentIndex >= 0 && currentIndex < commandHistory.count && commandHistory[currentIndex].canUndo
    }
    
    var canRedo: Bool {
        currentIndex + 1 < commandHistory.count
    }
}

// MARK: - Usage
class ThreadsViewController: UIViewController {
    private let commandManager = CommandManager()
    
    private func toggleBookmark(for thread: AwfulThread) {
        let command = BookmarkThreadCommand(thread: thread, forumsClient: ForumsClient.shared)
        
        Task {
            do {
                try await commandManager.execute(command)
                showUndoOption()
            } catch {
                showError(error)
            }
        }
    }
    
    private func showUndoOption() {
        let alert = UIAlertController(title: "Bookmark Updated", message: nil, preferredStyle: .alert)
        
        if commandManager.canUndo {
            alert.addAction(UIAlertAction(title: "Undo", style: .default) { _ in
                Task {
                    try await self.commandManager.undo()
                }
            })
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

## Builder Pattern

Used for constructing complex objects with many optional parameters.

### URL Builder

```swift
// MARK: - URL Builder
class ForumsURLBuilder {
    private var baseURL: URL
    private var path: String = ""
    private var queryItems: [URLQueryItem] = []
    
    init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    func path(_ path: String) -> Self {
        self.path = path
        return self
    }
    
    func queryItem(name: String, value: String) -> Self {
        queryItems.append(URLQueryItem(name: name, value: value))
        return self
    }
    
    func forumID(_ forumID: String) -> Self {
        return queryItem(name: "forumid", value: forumID)
    }
    
    func threadID(_ threadID: String) -> Self {
        return queryItem(name: "threadid", value: threadID)
    }
    
    func page(_ page: Int) -> Self {
        return queryItem(name: "pagenumber", value: "\(page)")
    }
    
    func perPage(_ perPage: Int) -> Self {
        return queryItem(name: "perpage", value: "\(perPage)")
    }
    
    func build() -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        return components?.url
    }
}

// MARK: - Usage
let threadsURL = ForumsURLBuilder(baseURL: baseURL)
    .path("forumdisplay.php")
    .forumID("26")
    .page(1)
    .perPage(40)
    .build()

let postsURL = ForumsURLBuilder(baseURL: baseURL)
    .path("showthread.php")
    .threadID("12345")
    .page(1)
    .queryItem(name: "goto", value: "newpost")
    .build()
```

## Adapter Pattern

Used for integrating incompatible interfaces, especially for legacy code.

### Core Data to Swift Model Adapter

```swift
// MARK: - Swift Model
struct ThreadModel {
    let id: String
    let title: String
    let replyCount: Int
    let isBookmarked: Bool
    let lastPostDate: Date?
    let author: UserModel
}

struct UserModel {
    let id: String
    let username: String
    let avatarURL: URL?
}

// MARK: - Adapter Protocol
protocol ThreadModelAdapter {
    func adaptThread(_ coreDataThread: AwfulThread) -> ThreadModel
    func adaptUser(_ coreDataUser: User) -> UserModel
}

// MARK: - Adapter Implementation
class CoreDataThreadModelAdapter: ThreadModelAdapter {
    func adaptThread(_ coreDataThread: AwfulThread) -> ThreadModel {
        return ThreadModel(
            id: coreDataThread.threadID,
            title: coreDataThread.title ?? "Untitled",
            replyCount: Int(coreDataThread.totalReplies),
            isBookmarked: coreDataThread.bookmarked,
            lastPostDate: coreDataThread.lastPostDate,
            author: adaptUser(coreDataThread.author!)
        )
    }
    
    func adaptUser(_ coreDataUser: User) -> UserModel {
        return UserModel(
            id: coreDataUser.userID,
            username: coreDataUser.username ?? "Unknown",
            avatarURL: coreDataUser.profilePictureURL
        )
    }
}

// MARK: - SwiftUI Integration
struct ThreadRowView: View {
    let thread: ThreadModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(thread.title)
                    .font(.headline)
                Text("by \(thread.author.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                Text("\(thread.replyCount)")
                    .font(.caption)
                if thread.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Usage
class ThreadsSwiftUIViewController: UIHostingController<ThreadsListView> {
    private let adapter = CoreDataThreadModelAdapter()
    
    private func updateSwiftUIView(with coreDataThreads: [AwfulThread]) {
        let threadModels = coreDataThreads.map(adapter.adaptThread)
        let threadsListView = ThreadsListView(threads: threadModels)
        rootView = threadsListView
    }
}
```

These architectural patterns provide structure, maintainability, and testability to the Awful.app codebase while supporting both UIKit and SwiftUI paradigms.