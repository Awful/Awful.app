# Refactoring Guidelines

## Overview

This document provides comprehensive guidelines for safely refactoring legacy code in Awful.app, ensuring that modernization efforts maintain stability, preserve functionality, and improve code quality without introducing regressions.

## General Refactoring Principles

### Safety First Approach

#### The Boy Scout Rule
- **Principle**: Leave code better than you found it
- **Application**: Make small improvements during every code interaction
- **Scope**: Limited, focused changes that don't break existing functionality
- **Risk Management**: Incremental improvements with full test coverage

#### Red-Green-Refactor Cycle
1. **Red**: Write failing tests for desired behavior
2. **Green**: Make tests pass with minimal code changes
3. **Refactor**: Improve code structure while keeping tests green

```swift
// Example: Refactoring completion handler to async/await
class ThreadRepository {
    // BEFORE: Legacy completion handler
    func loadThreads(completion: @escaping (Result<[Thread], Error>) -> Void) {
        // Legacy implementation
    }
    
    // STEP 1: Add async version alongside legacy
    func loadThreads() async throws -> [Thread] {
        return try await withCheckedThrowingContinuation { continuation in
            loadThreads { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // STEP 2: Migrate callers gradually
    // STEP 3: Remove legacy method when all callers migrated
}
```

### Change Classification

#### Safe Changes (Low Risk)
- **Code formatting and style improvements**
- **Adding comprehensive documentation**
- **Extracting constants from magic numbers**
- **Adding type annotations**
- **Renaming variables for clarity (within scope)**

```swift
// Safe refactoring example
class PostRenderer {
    // BEFORE: Magic numbers and unclear naming
    func calculateHeight(text: String) -> CGFloat {
        let x = text.count * 1.2 + 50
        return x > 200 ? 200 : x
    }
    
    // AFTER: Clear constants and naming
    private static let characterHeightMultiplier: CGFloat = 1.2
    private static let baseHeight: CGFloat = 50
    private static let maximumHeight: CGFloat = 200
    
    func calculateEstimatedHeight(for text: String) -> CGFloat {
        let estimatedHeight = CGFloat(text.count) * Self.characterHeightMultiplier + Self.baseHeight
        return min(estimatedHeight, Self.maximumHeight)
    }
}
```

#### Medium Risk Changes
- **Method extraction and decomposition**
- **Class responsibility separation**
- **Interface/protocol extraction**
- **Dependency injection implementation**

```swift
// Medium risk refactoring example
class MessageViewController {
    // BEFORE: Large method with multiple responsibilities
    func loadMessage() {
        // Authentication check
        guard let user = currentUser else { return }
        
        // Network request
        let request = URLRequest(url: messageURL)
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Error handling
            if let error = error {
                DispatchQueue.main.async {
                    self.showError(error)
                }
                return
            }
            
            // Data parsing
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messageData = json["message"] as? [String: Any] else {
                return
            }
            
            // UI update
            DispatchQueue.main.async {
                self.updateUI(with: messageData)
            }
        }.resume()
    }
    
    // AFTER: Extracted responsibilities
    func loadMessage() {
        Task {
            do {
                let message = try await messageService.loadMessage(id: messageID)
                await updateUI(with: message)
            } catch {
                await showError(error)
            }
        }
    }
}

// Extracted service
class MessageService {
    func loadMessage(id: String) async throws -> Message {
        let request = URLRequest(url: messageURL(for: id))
        let (data, _) = try await URLSession.shared.data(for: request)
        return try MessageParser.parse(data)
    }
}
```

#### High Risk Changes
- **Changing public APIs**
- **Modifying data structures**
- **Altering network request formats**
- **Core Data model changes**

### Refactoring Strategy

#### Strangler Fig Pattern
- **Concept**: Gradually replace old system with new system
- **Implementation**: New code calls old code initially, then takes over incrementally
- **Benefits**: Zero downtime, gradual migration, easy rollback

```swift
// Strangler Fig pattern example
protocol MessageRenderer {
    func render(_ message: Message) -> String
}

// Legacy implementation (to be replaced)
class LegacyMessageRenderer: MessageRenderer {
    func render(_ message: Message) -> String {
        // Legacy Objective-C implementation
        return LegacyObjCRenderer.render(message)
    }
}

// Modern implementation
class ModernMessageRenderer: MessageRenderer {
    func render(_ message: Message) -> String {
        // Modern Swift implementation with templates
        return TemplateEngine.render(template: "message", context: message)
    }
}

// Router that gradually shifts traffic
class MessageRendererRouter: MessageRenderer {
    private let legacyRenderer = LegacyMessageRenderer()
    private let modernRenderer = ModernMessageRenderer()
    
    func render(_ message: Message) -> String {
        // Feature flag controls which renderer to use
        if FeatureFlags.useModernRenderer {
            do {
                return try modernRenderer.render(message)
            } catch {
                // Fallback to legacy on error
                return legacyRenderer.render(message)
            }
        } else {
            return legacyRenderer.render(message)
        }
    }
}
```

## Code Quality Guidelines

### Swift Modernization

#### Objective-C to Swift Migration
```swift
// BEFORE: Objective-C patterns in Swift
class ThreadListViewController: UIViewController {
    var threads: NSMutableArray = NSMutableArray()
    
    func loadThreads() {
        let client = ForumsClient.shared()
        client.loadThreads { (threads: NSArray?, error: NSError?) in
            if let error = error {
                self.handleError(error)
                return
            }
            
            self.threads = NSMutableArray(array: threads ?? [])
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
}

// AFTER: Modern Swift patterns
class ThreadListViewController: UIViewController {
    private var threads: [Thread] = []
    private let threadRepository: ThreadRepository
    
    init(threadRepository: ThreadRepository) {
        self.threadRepository = threadRepository
        super.init(nibName: nil, bundle: nil)
    }
    
    func loadThreads() async {
        do {
            threads = try await threadRepository.loadThreads()
            tableView.reloadData()
        } catch {
            handleError(error)
        }
    }
}
```

#### Modern Swift Features Adoption
```swift
// Use modern Swift features appropriately

// Property wrappers for common patterns
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

// Result builders for DSL creation
@resultBuilder
struct ThreadFilterBuilder {
    static func buildBlock(_ filters: ThreadFilter...) -> [ThreadFilter] {
        return filters
    }
}

// Async sequences for streaming data
class ThreadUpdateStream: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = ThreadUpdate
    
    func makeAsyncIterator() -> ThreadUpdateStream {
        return self
    }
    
    func next() async -> ThreadUpdate? {
        // Stream implementation
    }
}
```

### Architecture Patterns

#### MVVM Implementation
```swift
// Clean MVVM architecture
protocol ThreadListViewModelProtocol: ObservableObject {
    var threads: [Thread] { get }
    var loadingState: LoadingState { get }
    var errorMessage: String? { get }
    
    func loadThreads() async
    func refreshThreads() async
    func selectThread(_ thread: Thread)
}

class ThreadListViewModel: ThreadListViewModelProtocol {
    @Published var threads: [Thread] = []
    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?
    
    private let threadRepository: ThreadRepository
    private let navigationService: NavigationService
    
    init(threadRepository: ThreadRepository, navigationService: NavigationService) {
        self.threadRepository = threadRepository
        self.navigationService = navigationService
    }
    
    @MainActor
    func loadThreads() async {
        loadingState = .loading
        errorMessage = nil
        
        do {
            threads = try await threadRepository.loadThreads()
            loadingState = .loaded
        } catch {
            errorMessage = error.localizedDescription
            loadingState = .error
        }
    }
    
    func selectThread(_ thread: Thread) {
        navigationService.navigate(to: .thread(thread.id))
    }
}
```

#### Dependency Injection
```swift
// Protocol-based dependency injection
protocol DIContainer {
    func resolve<T>(_ type: T.Type) -> T
}

class AppDIContainer: DIContainer {
    private var services: [String: Any] = [:]
    
    init() {
        registerServices()
    }
    
    private func registerServices() {
        register(NetworkService.self) { URLSession.shared }
        register(ThreadRepository.self) { 
            CoreDataThreadRepository(
                networkService: self.resolve(NetworkService.self),
                context: self.resolve(NSManagedObjectContext.self)
            )
        }
    }
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        services[key] = factory
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        guard let factory = services[key] as? () -> T else {
            fatalError("Service \(type) not registered")
        }
        return factory()
    }
}
```

### Error Handling Modernization

#### Swift Error Handling
```swift
// BEFORE: NSError and completion handlers
func loadUser(id: String, completion: @escaping (User?, NSError?) -> Void) {
    // Legacy error handling
}

// AFTER: Swift Error and async/await
enum UserServiceError: LocalizedError {
    case userNotFound(String)
    case networkError(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .userNotFound(let id):
            return "User with ID \(id) not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

func loadUser(id: String) async throws -> User {
    do {
        let request = URLRequest(url: userURL(for: id))
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UserServiceError.invalidResponse
        }
        
        return try JSONDecoder().decode(User.self, from: data)
    } catch let decodingError as DecodingError {
        throw UserServiceError.invalidResponse
    } catch {
        throw UserServiceError.networkError(error)
    }
}
```

## Testing Guidelines

### Test-Driven Refactoring

#### Characterization Tests
```swift
// Create tests that document current behavior before refactoring
class LegacyBehaviorTests: XCTestCase {
    func testCurrentThreadListBehavior() {
        // Document exact current behavior
        let controller = ThreadListViewController()
        controller.loadViewIfNeeded()
        
        // Test current implementation details
        XCTAssertEqual(controller.threads.count, 0)
        XCTAssertTrue(controller.view.subviews.contains { $0 is UITableView })
        
        // Document current loading behavior
        controller.loadThreads()
        
        // Wait for async operation
        let expectation = expectation(description: "Threads loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)
        
        // Verify current behavior
        XCTAssertTrue(controller.threads.count >= 0)
    }
}
```

#### Refactoring Tests
```swift
// Tests that verify refactored code maintains same behavior
class RefactoredBehaviorTests: XCTestCase {
    func testRefactoredThreadListBehavior() async {
        let mockRepository = MockThreadRepository()
        let controller = ModernThreadListViewController(repository: mockRepository)
        
        await controller.loadThreads()
        
        // Verify same behavior as legacy implementation
        XCTAssertEqual(controller.threads.count, mockRepository.threads.count)
        XCTAssertEqual(controller.loadingState, .loaded)
    }
}

// Mock for testing
class MockThreadRepository: ThreadRepository {
    let threads = [
        Thread(id: "1", title: "Test Thread 1"),
        Thread(id: "2", title: "Test Thread 2")
    ]
    
    func loadThreads() async throws -> [Thread] {
        return threads
    }
}
```

### Integration Testing

#### API Compatibility Tests
```swift
// Ensure refactored code maintains API compatibility
class APICompatibilityTests: XCTestCase {
    func testThreadRepositoryAPICompatibility() async throws {
        let repository = CoreDataThreadRepository()
        
        // Test that new API provides same results as old API
        let threads = try await repository.loadThreads()
        
        // Verify thread structure matches expectations
        for thread in threads {
            XCTAssertFalse(thread.id.isEmpty)
            XCTAssertFalse(thread.title.isEmpty)
            XCTAssertNotNil(thread.lastPostDate)
        }
    }
}
```

## Performance Guidelines

### Memory Management

#### ARC Best Practices
```swift
// Proper memory management in refactored code
class PostViewController: UIViewController {
    private weak var delegate: PostViewControllerDelegate?
    private var cancellables = Set<AnyCancellable>()
    
    // Use weak references for delegates
    func setDelegate(_ delegate: PostViewControllerDelegate) {
        self.delegate = delegate
    }
    
    // Clean up properly
    deinit {
        cancellables.removeAll()
    }
    
    // Avoid retain cycles in closures
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .postDidUpdate)
            .sink { [weak self] notification in
                self?.handlePostUpdate(notification)
            }
            .store(in: &cancellables)
    }
}
```

#### Core Data Performance
```swift
// Efficient Core Data usage patterns
class CoreDataThreadRepository: ThreadRepository {
    private let context: NSManagedObjectContext
    
    func loadThreads() async throws -> [Thread] {
        return try await context.perform {
            let request = NSFetchRequest<ThreadManagedObject>(entityName: "Thread")
            
            // Use batch limits for large datasets
            request.fetchBatchSize = 20
            
            // Fetch only needed properties
            request.propertiesToFetch = ["threadID", "title", "lastPostDate"]
            
            // Use efficient sorting
            request.sortDescriptors = [NSSortDescriptor(key: "lastPostDate", ascending: false)]
            
            let results = try self.context.fetch(request)
            return results.map { Thread(managedObject: $0) }
        }
    }
}
```

### Concurrency Guidelines

#### Modern Concurrency Patterns
```swift
// Use structured concurrency properly
class DataSyncManager {
    func syncAllData() async throws {
        // Use task groups for parallel operations
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.syncThreads()
            }
            
            group.addTask {
                try await self.syncUsers()
            }
            
            group.addTask {
                try await self.syncPosts()
            }
            
            // Wait for all tasks to complete
            try await group.waitForAll()
        }
    }
    
    @MainActor
    func updateUI() {
        // UI updates on main actor
        tableView.reloadData()
    }
}
```

## Code Review Guidelines

### Refactoring Review Checklist

#### Functionality Preservation
- [ ] All existing functionality is preserved
- [ ] No breaking changes to public APIs
- [ ] Error handling behavior is maintained
- [ ] Performance is maintained or improved
- [ ] Memory usage is maintained or improved

#### Code Quality Improvements
- [ ] Code is more readable and maintainable
- [ ] Responsibilities are properly separated
- [ ] Dependencies are clearly defined
- [ ] Error handling is comprehensive
- [ ] Tests cover all important scenarios

#### Safety Checks
- [ ] No force unwraps or unsafe operations
- [ ] Proper memory management (weak references)
- [ ] Thread safety is maintained
- [ ] All edge cases are handled
- [ ] Rollback plan exists if needed

### Review Process

#### Pre-Review Preparation
```swift
// Document refactoring rationale
/**
 * Refactoring: ThreadListViewController
 * 
 * GOAL: Extract business logic into view model for better testability
 * 
 * CHANGES:
 * - Extracted ThreadListViewModel
 * - Converted to async/await
 * - Added proper error handling
 * - Improved memory management
 * 
 * RISKS:
 * - Behavior changes in error scenarios
 * - Timing differences in async operations
 * 
 * MITIGATION:
 * - Comprehensive test coverage
 * - Feature flag for gradual rollout
 * - Characterization tests for current behavior
 */
```

#### Review Focus Areas
1. **Behavioral Equivalence**: Does new code behave exactly like old code?
2. **Error Handling**: Are all error scenarios properly handled?
3. **Performance Impact**: Is performance maintained or improved?
4. **Test Coverage**: Are all scenarios properly tested?
5. **Documentation**: Is the change properly documented?

## Risk Management

### Rollback Strategies

#### Feature Flags
```swift
// Use feature flags for safe rollouts
class FeatureFlags {
    static var useModernThreadList: Bool {
        return RemoteConfig.shared.boolValue(for: "modern_thread_list", defaultValue: false)
    }
    
    static var useAsyncNetworking: Bool {
        return RemoteConfig.shared.boolValue(for: "async_networking", defaultValue: false)
    }
}

// Conditional implementation
class ThreadListFactory {
    static func createViewController() -> UIViewController {
        if FeatureFlags.useModernThreadList {
            return ModernThreadListViewController()
        } else {
            return LegacyThreadListViewController()
        }
    }
}
```

#### A/B Testing
```swift
// A/B test refactored components
class ABTestManager {
    static func shouldUseModernImplementation(feature: String) -> Bool {
        let userID = UserManager.currentUser?.id ?? "anonymous"
        let hash = userID.hash
        let percentage = abs(hash) % 100
        
        switch feature {
        case "modern_thread_list":
            return percentage < 50 // 50% rollout
        case "new_post_renderer":
            return percentage < 25 // 25% rollout
        default:
            return false
        }
    }
}
```

### Monitoring and Metrics

#### Performance Monitoring
```swift
// Monitor performance during refactoring
class PerformanceMonitor {
    static func measureExecutionTime<T>(
        operation: String,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            Analytics.track("performance_metric", properties: [
                "operation": operation,
                "duration_ms": timeElapsed * 1000
            ])
        }
        
        return try block()
    }
}

// Usage in refactored code
func loadThreads() async throws -> [Thread] {
    return try await PerformanceMonitor.measureExecutionTime(operation: "load_threads") {
        return try await threadRepository.loadThreads()
    }
}
```

#### Error Monitoring
```swift
// Track errors in refactored code
class ErrorMonitor {
    static func trackRefactoringError(
        component: String,
        error: Error,
        context: [String: Any] = [:]
    ) {
        var errorContext = context
        errorContext["component"] = component
        errorContext["is_refactored"] = true
        
        CrashReporter.recordError(error, userInfo: errorContext)
    }
}
```

## Success Metrics

### Code Quality Metrics

#### Quantitative Metrics
- **Cyclomatic Complexity**: Reduce by 30%
- **Lines of Code**: Reduce by 20% while maintaining functionality
- **Test Coverage**: Increase to >80%
- **Documentation Coverage**: Increase to >90%

#### Qualitative Metrics
- **Code Readability**: Subjective improvement in code reviews
- **Maintainability**: Faster bug fixes and feature additions
- **Team Productivity**: Reduced time to understand and modify code
- **Bug Rate**: No increase in bugs after refactoring

### Performance Metrics

#### Runtime Performance
- **Memory Usage**: Maintain or improve
- **CPU Usage**: Maintain or improve
- **App Launch Time**: Maintain or improve
- **UI Responsiveness**: Maintain 60fps

#### Development Performance
- **Build Time**: Maintain or improve
- **Test Execution Time**: Maintain or improve
- **Code Review Time**: Reduce by focusing on smaller changes
- **Bug Resolution Time**: Improve through better code structure

## Best Practices Summary

### Do's
- ✅ Make small, incremental changes
- ✅ Write tests before refactoring
- ✅ Preserve existing behavior exactly
- ✅ Use feature flags for gradual rollouts
- ✅ Document rationale and risks
- ✅ Monitor performance and errors
- ✅ Have rollback plans ready

### Don'ts
- ❌ Make large, sweeping changes at once
- ❌ Refactor without adequate test coverage
- ❌ Change behavior during refactoring
- ❌ Ignore performance implications
- ❌ Skip code reviews for "simple" refactoring
- ❌ Refactor critical code without backup plans
- ❌ Mix feature additions with refactoring

### Common Pitfalls
- **Scope Creep**: Refactoring expands beyond original intent
- **Behavior Changes**: Subtle behavior changes break existing functionality
- **Performance Regression**: New code is slower than original
- **Over-Engineering**: Making code more complex than necessary
- **Insufficient Testing**: Missing edge cases or error scenarios

## Conclusion

Successful refactoring in Awful.app requires careful planning, comprehensive testing, and gradual implementation. By following these guidelines, the team can safely modernize the codebase while maintaining the stability and reliability that users expect.

The key is to balance the desire for modern, clean code with the practical need to maintain a working application. With proper discipline and attention to detail, the refactoring effort will result in a more maintainable, performant, and enjoyable codebase to work with.