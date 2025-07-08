# Integration Testing

## Overview

Integration testing in Awful.app verifies that different components work together correctly. This document covers strategies for testing multi-component interactions, data flow between layers, and system-level functionality.

## Integration Test Scope

### Component Integration Areas

#### Data Layer Integration
- **Core Data ↔ Scraping**: HTML parsing to Core Data persistence
- **Networking ↔ Persistence**: HTTP responses to database storage
- **Context Management**: Background/main queue coordination
- **Cache Invalidation**: Data freshness and synchronization

#### UI Layer Integration
- **View Controllers ↔ Data Models**: Binding and observation
- **Navigation Flow**: Screen transitions and state management
- **Theme System**: CSS/theme application across components
- **User Interactions**: Gestures, touch handling, keyboard

#### External Integration
- **App Extensions**: Smilie keyboard and share extensions
- **System Services**: Notifications, background tasks, handoff
- **Third-Party Libraries**: Nuke, HTMLReader, Stencil integration
- **Platform APIs**: Core Data, WebKit, UserDefaults

## Current Integration Tests

### Data Flow Integration

#### Thread Loading End-to-End
```swift
final class ThreadLoadingIntegrationTests: XCTestCase {
    var forumsClient: ForumsClient!
    var dataStore: DataStore!
    var viewController: PostsPageViewController!
    
    override func setUp() {
        super.setUp()
        dataStore = DataStore(storeType: .inMemory)
        forumsClient = ForumsClient(dataStore: dataStore)
        viewController = PostsPageViewController(
            thread: createTestThread(),
            forumsClient: forumsClient
        )
    }
    
    func testCompleteThreadLoadingFlow() async throws {
        // Arrange: Mock network response
        let mockHTMLResponse = loadFixture("thread-page")
        MockURLProtocol.stubResponse(data: mockHTMLResponse)
        
        // Act: Load thread through view controller
        viewController.loadViewIfNeeded()
        await viewController.loadPage(1)
        
        // Assert: Verify complete data flow
        let context = dataStore.mainContext
        let posts = try context.fetch(Post.fetchRequest())
        
        XCTAssertGreaterThan(posts.count, 0)
        XCTAssertTrue(viewController.isLoaded)
        XCTAssertFalse(viewController.isLoading)
    }
}
```

#### Authentication Integration
```swift
final class AuthenticationIntegrationTests: XCTestCase {
    var forumsClient: ForumsClient!
    var dataStore: DataStore!
    
    override func setUp() {
        super.setUp()
        dataStore = DataStore(storeType: .inMemory)
        forumsClient = ForumsClient(dataStore: dataStore)
    }
    
    func testLoginFlow() async throws {
        // Mock login response
        let loginHTML = loadFixture("login-success")
        MockURLProtocol.stubResponse(data: loginHTML)
        
        // Perform login
        let result = try await forumsClient.logIn(username: "testuser", password: "testpass")
        
        // Verify authentication state
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(forumsClient.isAuthenticated)
        XCTAssertNotNil(forumsClient.currentUser)
        
        // Verify session persistence
        let newClient = ForumsClient(dataStore: dataStore)
        XCTAssertTrue(newClient.isAuthenticated)
    }
}
```

### UI Integration Tests

#### Navigation Integration
```swift
final class NavigationIntegrationTests: XCTestCase {
    var rootViewController: RootViewController!
    var window: UIWindow!
    
    override func setUp() {
        super.setUp()
        window = UIWindow(frame: UIScreen.main.bounds)
        rootViewController = RootViewController()
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
    }
    
    func testForumNavigationFlow() {
        // Navigate to forums
        rootViewController.showForums()
        
        guard let tabBarController = rootViewController.tabBarController,
              let navController = tabBarController.selectedViewController as? UINavigationController,
              let forumsVC = navController.topViewController as? ForumsTableViewController else {
            XCTFail("Failed to navigate to forums")
            return
        }
        
        // Simulate forum selection
        let indexPath = IndexPath(row: 0, section: 0)
        forumsVC.tableView(forumsVC.tableView, didSelectRowAt: indexPath)
        
        // Verify navigation to threads
        XCTAssertTrue(navController.topViewController is ThreadsTableViewController)
    }
}
```

#### Theme Integration
```swift
final class ThemeIntegrationTests: XCTestCase {
    var themeManager: ThemeManager!
    var viewController: PostsPageViewController!
    
    override func setUp() {
        super.setUp()
        themeManager = ThemeManager.shared
        viewController = PostsPageViewController(
            thread: createTestThread(),
            forumsClient: ForumsClient.shared
        )
    }
    
    func testThemeApplication() {
        // Load view controller
        viewController.loadViewIfNeeded()
        
        // Apply dark theme
        themeManager.currentTheme = .dark
        
        // Verify theme propagation
        XCTAssertEqual(viewController.view.backgroundColor, .systemBackground)
        XCTAssertEqual(viewController.webView.backgroundColor, .systemBackground)
        
        // Switch to light theme
        themeManager.currentTheme = .light
        
        // Verify theme change
        XCTAssertEqual(viewController.view.backgroundColor, .systemBackground)
    }
}
```

### Extension Integration

#### Smilie Keyboard Integration
```swift
final class SmilieKeyboardIntegrationTests: XCTestCase {
    var keyboardViewController: SmilieKeyboardViewController!
    var dataStore: SmilieDataStore!
    
    override func setUp() {
        super.setUp()
        dataStore = SmilieDataStore()
        keyboardViewController = SmilieKeyboardViewController()
        keyboardViewController.dataStore = dataStore
    }
    
    func testSmilieSelection() {
        // Load keyboard
        keyboardViewController.loadViewIfNeeded()
        keyboardViewController.viewDidLoad()
        
        // Simulate smilie selection
        let smilie = Smilie(text: ":smile:", imageURL: URL(string: "https://example.com/smile.png")!)
        keyboardViewController.insertSmilie(smilie)
        
        // Verify insertion
        XCTAssertTrue(keyboardViewController.textDocumentProxy.hasText)
    }
}
```

### Background Processing Integration

#### Data Synchronization
```swift
final class BackgroundSyncIntegrationTests: XCTestCase {
    var backgroundSync: BackgroundSyncManager!
    var dataStore: DataStore!
    
    override func setUp() {
        super.setUp()
        dataStore = DataStore(storeType: .inMemory)
        backgroundSync = BackgroundSyncManager(dataStore: dataStore)
    }
    
    func testBackgroundDataRefresh() async throws {
        // Setup initial data
        let thread = createTestThread()
        try dataStore.mainContext.save()
        
        // Trigger background refresh
        let result = try await backgroundSync.refreshBookmarkedThreads()
        
        // Verify data was updated
        XCTAssertTrue(result.isSuccess)
        XCTAssertGreaterThan(result.updatedThreads.count, 0)
        
        // Verify context synchronization
        let mainContext = dataStore.mainContext
        let backgroundContext = dataStore.backgroundContext
        
        XCTAssertEqual(mainContext.registeredObjects.count, 
                      backgroundContext.registeredObjects.count)
    }
}
```

## Integration Test Patterns

### Test Environment Setup

#### Mock Network Integration
```swift
class MockURLProtocol: URLProtocol {
    static var stubbedResponses: [URL: (Data, URLResponse)] = [:]
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let url = request.url,
              let (data, response) = Self.stubbedResponses[url] else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockError", code: 404))
            return
        }
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {}
    
    static func stubResponse(for url: URL, data: Data, statusCode: Int = 200) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        stubbedResponses[url] = (data, response)
    }
}
```

#### Test Data Store
```swift
class TestDataStore: DataStore {
    init() {
        super.init(storeType: .inMemory)
    }
    
    func reset() {
        let context = mainContext
        
        // Delete all objects
        let entities = managedObjectModel.entities
        for entity in entities {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity.name!)
            let objects = try! context.fetch(request)
            for object in objects {
                context.delete(object)
            }
        }
        
        try! context.save()
    }
    
    func populate(with fixtures: [String]) {
        for fixture in fixtures {
            populateFromFixture(fixture)
        }
    }
}
```

### Component Integration Patterns

#### Service Layer Integration
```swift
final class ServiceIntegrationTests: XCTestCase {
    var serviceContainer: ServiceContainer!
    
    override func setUp() {
        super.setUp()
        serviceContainer = ServiceContainer()
        serviceContainer.register(ForumsClient.self) { container in
            ForumsClient(dataStore: container.resolve(DataStore.self)!)
        }
        serviceContainer.register(DataStore.self) { _ in
            DataStore(storeType: .inMemory)
        }
    }
    
    func testServiceDependencyInjection() {
        let forumsClient = serviceContainer.resolve(ForumsClient.self)!
        let dataStore = serviceContainer.resolve(DataStore.self)!
        
        XCTAssertTrue(forumsClient.dataStore === dataStore)
    }
}
```

#### Event System Integration
```swift
final class EventSystemIntegrationTests: XCTestCase {
    var eventBus: EventBus!
    var subscribers: [EventSubscriber] = []
    
    override func setUp() {
        super.setUp()
        eventBus = EventBus()
    }
    
    func testEventPropagation() {
        let expectation = XCTestExpectation(description: "Event received")
        
        let subscriber = MockEventSubscriber { event in
            if case .threadUpdated(let threadID) = event {
                XCTAssertEqual(threadID, "12345")
                expectation.fulfill()
            }
        }
        
        eventBus.subscribe(subscriber)
        eventBus.publish(.threadUpdated(threadID: "12345"))
        
        wait(for: [expectation], timeout: 1.0)
    }
}
```

### Database Integration

#### Multi-Context Operations
```swift
final class CoreDataIntegrationTests: XCTestCase {
    var dataStore: DataStore!
    var mainContext: NSManagedObjectContext!
    var backgroundContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        dataStore = DataStore(storeType: .inMemory)
        mainContext = dataStore.mainContext
        backgroundContext = dataStore.backgroundContext
    }
    
    func testContextSynchronization() throws {
        // Create object in background context
        let thread = Thread(context: backgroundContext)
        thread.threadID = "12345"
        thread.title = "Test Thread"
        
        try backgroundContext.save()
        
        // Verify synchronization to main context
        mainContext.performAndWait {
            let request: NSFetchRequest<Thread> = Thread.fetchRequest()
            request.predicate = NSPredicate(format: "threadID == %@", "12345")
            
            let threads = try! mainContext.fetch(request)
            XCTAssertEqual(threads.count, 1)
            XCTAssertEqual(threads.first?.title, "Test Thread")
        }
    }
}
```

#### Migration Testing
```swift
final class MigrationIntegrationTests: XCTestCase {
    func testDataModelMigration() throws {
        // Create store with old model
        let oldStoreURL = createTempStoreURL()
        let oldStore = try createStore(at: oldStoreURL, model: oldModel)
        
        // Add test data
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = oldStore.coordinator
        
        let thread = Thread(context: context)
        thread.threadID = "12345"
        thread.title = "Test Thread"
        try context.save()
        
        // Perform migration
        let migrator = DataModelMigrator(storeURL: oldStoreURL, 
                                        sourceModel: oldModel, 
                                        targetModel: newModel)
        try migrator.migrate()
        
        // Verify migrated data
        let newStore = try createStore(at: oldStoreURL, model: newModel)
        let newContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        newContext.persistentStoreCoordinator = newStore.coordinator
        
        let threads = try newContext.fetch(Thread.fetchRequest())
        XCTAssertEqual(threads.count, 1)
        XCTAssertEqual(threads.first?.threadID, "12345")
    }
}
```

## System Integration Tests

### End-to-End User Flows

#### Complete Thread Reading Flow
```swift
final class ThreadReadingIntegrationTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    func testCompleteThreadReadingFlow() {
        // Navigate to forums
        app.tabBars.buttons["Forums"].tap()
        
        // Select a forum
        app.tables.cells.element(boundBy: 0).tap()
        
        // Select a thread
        app.tables.cells.element(boundBy: 0).tap()
        
        // Verify thread loaded
        XCTAssertTrue(app.webViews.element.exists)
        XCTAssertTrue(app.webViews.element.staticTexts.count > 0)
        
        // Test scrolling
        app.webViews.element.swipeUp()
        app.webViews.element.swipeDown()
        
        // Test navigation
        app.navigationBars.buttons["Back"].tap()
        XCTAssertTrue(app.tables.cells.count > 0)
    }
}
```

#### Authentication Flow
```swift
final class AuthenticationIntegrationTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--logout"]
        app.launch()
    }
    
    func testLoginFlow() {
        // Navigate to settings
        app.tabBars.buttons["Settings"].tap()
        
        // Tap login
        app.tables.cells["Login"].tap()
        
        // Enter credentials
        app.textFields["Username"].tap()
        app.textFields["Username"].typeText("testuser")
        
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("testpass")
        
        // Submit login
        app.buttons["Log In"].tap()
        
        // Verify success
        XCTAssertTrue(app.tables.cells["Logged in as testuser"].exists)
    }
}
```

### Performance Integration

#### Memory Management Integration
```swift
final class MemoryIntegrationTests: XCTestCase {
    func testMemoryManagementDuringNavigation() {
        let initialMemory = getMemoryUsage()
        
        // Perform navigation cycle
        for _ in 0..<10 {
            let viewController = PostsPageViewController(
                thread: createTestThread(),
                forumsClient: ForumsClient.shared
            )
            
            viewController.loadViewIfNeeded()
            viewController.viewDidLoad()
            viewController.viewWillAppear(true)
            viewController.viewDidAppear(true)
            viewController.viewWillDisappear(true)
            viewController.viewDidDisappear(true)
        }
        
        // Force garbage collection
        autoreleasepool {}
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        XCTAssertLessThan(memoryIncrease, 50_000_000) // 50MB threshold
    }
}
```

#### Network Performance Integration
```swift
final class NetworkPerformanceIntegrationTests: XCTestCase {
    func testConcurrentRequestHandling() async {
        let urls = (1...10).map { URL(string: "https://example.com/thread/\($0)")! }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await withTaskGroup(of: Data?.self) { group in
            for url in urls {
                group.addTask {
                    return try? await URLSession.shared.data(from: url).0
                }
            }
            
            var results: [Data?] = []
            for await result in group {
                results.append(result)
            }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
            XCTAssertEqual(results.count, urls.count)
        }
    }
}
```

## Test Infrastructure

### Test Doubles

#### Repository Pattern
```swift
protocol ThreadRepository {
    func fetchThread(id: String) async throws -> Thread
    func updateThread(_ thread: Thread) async throws
}

class MockThreadRepository: ThreadRepository {
    var threads: [String: Thread] = [:]
    
    func fetchThread(id: String) async throws -> Thread {
        guard let thread = threads[id] else {
            throw RepositoryError.notFound
        }
        return thread
    }
    
    func updateThread(_ thread: Thread) async throws {
        threads[thread.threadID] = thread
    }
}
```

#### Service Mocks
```swift
class MockForumsClient: ForumsClient {
    var shouldSucceed = true
    var responseDelay: TimeInterval = 0
    var mockResponses: [String: Data] = [:]
    
    override func loadPage(_ page: Int, for thread: Thread) async throws -> PostsPageScrapeResult {
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        
        guard shouldSucceed else {
            throw ForumsClientError.networkError
        }
        
        let mockData = mockResponses[thread.threadID] ?? Data()
        return try PostsPageScrapeResult(HTMLDocument(data: mockData), url: nil)
    }
}
```

### Test Configuration

#### Environment Setup
```swift
class IntegrationTestEnvironment {
    static let shared = IntegrationTestEnvironment()
    
    private init() {
        setupMockNetworking()
        setupTestDataStore()
        setupTestSettings()
    }
    
    private func setupMockNetworking() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        URLSession.shared = URLSession(configuration: config)
    }
    
    private func setupTestDataStore() {
        DataStore.shared = DataStore(storeType: .inMemory)
    }
    
    private func setupTestSettings() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }
}
```

## Migration Integration Testing

### UIKit to SwiftUI Integration
```swift
final class UIKitSwiftUIIntegrationTests: XCTestCase {
    func testUIKitSwiftUIInteroperability() {
        let uikitViewController = UIKitPostsViewController()
        let swiftuiView = SwiftUIPostsView()
        
        // Test data binding
        let thread = createTestThread()
        uikitViewController.thread = thread
        swiftuiView.thread = thread
        
        // Verify both display same data
        uikitViewController.loadViewIfNeeded()
        let uikitTitle = uikitViewController.navigationItem.title
        let swiftuiTitle = swiftuiView.navigationTitle
        
        XCTAssertEqual(uikitTitle, swiftuiTitle)
    }
}
```

### Data Model Integration
```swift
final class DataModelIntegrationTests: XCTestCase {
    func testCoreDataObservableObjectIntegration() {
        let thread = createTestThread()
        let observer = ThreadObserver(thread: thread)
        
        let expectation = XCTestExpectation(description: "Observer notified")
        
        observer.onUpdate = { updatedThread in
            XCTAssertEqual(updatedThread.title, "Updated Title")
            expectation.fulfill()
        }
        
        thread.title = "Updated Title"
        try! thread.managedObjectContext?.save()
        
        wait(for: [expectation], timeout: 1.0)
    }
}
```

## Best Practices

### Test Organization
- Group tests by integration boundary
- Use descriptive test names indicating components involved
- Setup and teardown test environment properly
- Use dependency injection for testability

### Data Management
- Use in-memory stores for fast execution
- Reset state between tests
- Use realistic test data
- Mock external dependencies

### Execution Strategy
- Run integration tests in CI/CD pipeline
- Use parallel execution where possible
- Monitor test execution time
- Fail fast on critical path failures

### Error Handling
- Test error scenarios between components
- Verify graceful degradation
- Test network failure scenarios
- Validate error propagation

## Future Enhancements

### Planned Improvements
- Contract testing between modules
- Chaos engineering for resilience testing
- Performance regression testing
- Visual regression testing for UI integration

### Tool Integration
- Fastlane for automated testing
- Charles Proxy for network testing
- Instruments for performance profiling
- Firebase Test Lab for device testing