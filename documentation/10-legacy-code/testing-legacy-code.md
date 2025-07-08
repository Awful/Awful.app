# Testing Legacy Code

## Overview

This document provides comprehensive strategies for testing legacy code in Awful.app, focusing on maintaining quality while modernizing the codebase. Legacy code often lacks tests, making it challenging to refactor safely. This guide addresses these challenges with practical testing approaches.

## Testing Strategy Overview

### The Legacy Code Dilemma

#### Common Legacy Code Issues
- **No existing tests**: Legacy code often lacks comprehensive test coverage
- **Tight coupling**: Dependencies are hard to mock or isolate
- **Side effects**: Code modifies global state or external systems
- **Complex dependencies**: Multiple intertwined components
- **Unclear requirements**: Business logic is implicit in implementation

#### Testing Approach
1. **Characterization Tests**: Document current behavior
2. **Safety Net Tests**: Prevent regressions during refactoring
3. **Integration Tests**: Test component interactions
4. **Unit Tests**: Test individual components after extraction
5. **End-to-End Tests**: Verify complete user workflows

## Characterization Testing

### Understanding Current Behavior

#### Purpose of Characterization Tests
- Document existing behavior without judging if it's correct
- Create safety net for refactoring
- Identify unexpected behaviors and edge cases
- Establish baseline for comparison after changes

#### Characterization Test Example
```swift
// Characterization test for MessageViewController
class MessageViewControllerCharacterizationTests: XCTestCase {
    var messageViewController: MessageViewController!
    var mockMessage: PrivateMessage!
    
    override func setUp() {
        super.setUp()
        mockMessage = createMockMessage()
        messageViewController = MessageViewController(privateMessage: mockMessage)
    }
    
    func testInitialState() {
        // Document current initialization behavior
        XCTAssertEqual(messageViewController.title, mockMessage.subject)
        XCTAssertNotNil(messageViewController.navigationItem.rightBarButtonItem)
        XCTAssertTrue(messageViewController.hidesBottomBarWhenPushed)
    }
    
    func testViewLifecycle() {
        // Document view loading behavior
        messageViewController.loadViewIfNeeded()
        
        XCTAssertNotNil(messageViewController.view)
        XCTAssertTrue(messageViewController.view.subviews.contains { $0 is UIWebView })
        
        messageViewController.viewDidLoad()
        messageViewController.viewWillAppear(false)
        messageViewController.viewDidAppear(false)
        
        // Document any side effects or state changes
        // This might reveal unexpected behaviors
    }
    
    func testWebViewConfiguration() {
        messageViewController.loadViewIfNeeded()
        
        guard let webView = messageViewController.view.subviews.first(where: { $0 is UIWebView }) as? UIWebView else {
            XCTFail("UIWebView not found")
            return
        }
        
        // Document current web view configuration
        XCTAssertNotNil(webView.delegate)
        XCTAssertEqual(webView.scalesPageToFit, true) // or false, document what's actually happening
        
        // Test HTML loading behavior
        let expectation = expectation(description: "HTML loaded")
        
        // Inject expectation fulfillment into web view delegate
        // This documents the current loading flow
        webView.loadHTMLString("<html><body>Test</body></html>", baseURL: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2)
    }
    
    func testNotificationObservers() {
        // Document notification handling
        let notificationCenter = NotificationCenter.default
        
        // Check what notifications the controller observes
        notificationCenter.post(name: NSNotification.Name("AwfulSettingsDidChangeNotification"), object: nil)
        
        // Verify how the controller responds
        // This documents current notification handling
    }
}
```

### Approval Testing

#### Snapshot Testing for UI Components
```swift
// Approval testing for UI layout
class MessageViewControllerApprovalTests: XCTestCase {
    func testMessageViewLayout() {
        let message = createMockMessage()
        let viewController = MessageViewController(privateMessage: message)
        
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        viewController.view.layoutIfNeeded()
        
        // Capture current layout as baseline
        assertSnapshot(matching: viewController, as: .image)
    }
    
    func testMessageViewWithLongContent() {
        let message = createMockMessageWithLongContent()
        let viewController = MessageViewController(privateMessage: message)
        
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        viewController.view.layoutIfNeeded()
        
        // Document behavior with long content
        assertSnapshot(matching: viewController, as: .image)
    }
}
```

#### HTML Output Approval Testing
```swift
// Test HTML generation consistency
class HTMLRenderingApprovalTests: XCTestCase {
    func testMessageHTMLGeneration() throws {
        let message = createMockMessage()
        let renderer = MessageRenderer()
        
        let html = try renderer.renderHTML(for: message)
        
        // Verify HTML structure remains consistent
        assertSnapshot(matching: html, as: .lines)
    }
    
    func testPostHTMLGeneration() throws {
        let post = createMockPost()
        let renderer = PostRenderer()
        
        let html = try renderer.renderHTML(for: post)
        
        // Document current HTML structure
        assertSnapshot(matching: html, as: .lines)
    }
}
```

## Testing Tightly Coupled Code

### Dependency Breaking Techniques

#### Extract and Override Call
```swift
// Original tightly coupled code
class ForumViewController: UIViewController {
    func loadForum() {
        let client = ForumsClient.shared()
        client.loadForum(forumID) { forum, error in
            // Handle response
        }
    }
}

// Extract method for testing
class ForumViewController: UIViewController {
    func loadForum() {
        let client = createForumsClient()
        client.loadForum(forumID) { forum, error in
            // Handle response
        }
    }
    
    // Extracted method that can be overridden in tests
    func createForumsClient() -> ForumsClient {
        return ForumsClient.shared()
    }
}

// Test subclass that overrides dependency creation
class TestableForumViewController: ForumViewController {
    var mockClient: MockForumsClient!
    
    override func createForumsClient() -> ForumsClient {
        return mockClient
    }
}

// Test using the testable subclass
class ForumViewControllerTests: XCTestCase {
    func testForumLoading() {
        let testableController = TestableForumViewController()
        testableController.mockClient = MockForumsClient()
        
        testableController.loadForum()
        
        XCTAssertTrue(testableController.mockClient.loadForumCalled)
    }
}
```

#### Parameterize Constructor
```swift
// Original constructor with hidden dependency
class ThreadListViewController: UIViewController {
    private let client = ForumsClient.shared()
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
}

// Parameterized constructor for testing
class ThreadListViewController: UIViewController {
    private let client: ForumsClient
    
    init(client: ForumsClient = ForumsClient.shared()) {
        self.client = client
        super.init(nibName: nil, bundle: nil)
    }
    
    // Keep convenience initializer for production code
    convenience init() {
        self.init(client: ForumsClient.shared())
    }
}

// Test with injected dependency
class ThreadListViewControllerTests: XCTestCase {
    func testThreadLoading() {
        let mockClient = MockForumsClient()
        let controller = ThreadListViewController(client: mockClient)
        
        controller.loadThreads()
        
        XCTAssertTrue(mockClient.loadThreadsCalled)
    }
}
```

### Mock Objects for Legacy Dependencies

#### Creating Test Doubles
```swift
// Protocol extraction for legacy class
protocol ForumsClientProtocol {
    func loadThreads(forumID: String, completion: @escaping ([Thread]?, Error?) -> Void)
    func loadUser(userID: String, completion: @escaping (User?, Error?) -> Void)
}

// Make legacy class conform to protocol
extension ForumsClient: ForumsClientProtocol {
    // Already implements required methods
}

// Mock implementation for testing
class MockForumsClient: ForumsClientProtocol {
    var loadThreadsCalled = false
    var loadUserCalled = false
    var threadsToReturn: [Thread] = []
    var userToReturn: User?
    var errorToReturn: Error?
    
    func loadThreads(forumID: String, completion: @escaping ([Thread]?, Error?) -> Void) {
        loadThreadsCalled = true
        
        if let error = errorToReturn {
            completion(nil, error)
        } else {
            completion(threadsToReturn, nil)
        }
    }
    
    func loadUser(userID: String, completion: @escaping (User?, Error?) -> Void) {
        loadUserCalled = true
        
        if let error = errorToReturn {
            completion(nil, error)
        } else {
            completion(userToReturn, nil)
        }
    }
}
```

#### Spy Objects for Behavior Verification
```swift
// Spy object that records interactions
class SpyNavigationController: UINavigationController {
    var pushedViewControllers: [UIViewController] = []
    var poppedViewControllerCount = 0
    var presentedViewControllers: [UIViewController] = []
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        pushedViewControllers.append(viewController)
        super.pushViewController(viewController, animated: animated)
    }
    
    override func popViewController(animated: Bool) -> UIViewController? {
        poppedViewControllerCount += 1
        return super.popViewController(animated: animated)
    }
    
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        presentedViewControllers.append(viewControllerToPresent)
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
}

// Test navigation behavior
class NavigationTests: XCTestCase {
    func testThreadSelection() {
        let spyNavigationController = SpyNavigationController()
        let threadListController = ThreadListViewController()
        spyNavigationController.pushViewController(threadListController, animated: false)
        
        // Simulate thread selection
        threadListController.didSelectThread(mockThread)
        
        // Verify navigation occurred
        XCTAssertEqual(spyNavigationController.pushedViewControllers.count, 2)
        XCTAssertTrue(spyNavigationController.pushedViewControllers.last is PostsViewController)
    }
}
```

## Integration Testing Strategies

### Testing Component Interactions

#### Database Integration Tests
```swift
// Core Data integration testing
class CoreDataIntegrationTests: XCTestCase {
    var testContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory test container
        testContainer = NSPersistentContainer(name: "AwfulModel")
        testContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        
        testContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        testContext = testContainer.viewContext
    }
    
    func testSmilieDataStoreIntegration() {
        let dataStore = SmilieDataStore(context: testContext)
        
        // Test smilie creation
        let smilie = dataStore.createSmilie(text: ":test:", imageURL: "http://example.com/test.gif")
        
        try! testContext.save()
        
        // Test smilie retrieval
        let fetchedSmilies = dataStore.allSmilies()
        XCTAssertEqual(fetchedSmilies.count, 1)
        XCTAssertEqual(fetchedSmilies.first?.text, ":test:")
    }
    
    func testThreadPostRelationship() {
        // Test Core Data relationships
        let thread = Thread.create(in: testContext)
        thread.threadID = "12345"
        thread.title = "Test Thread"
        
        let post = Post.create(in: testContext)
        post.postID = "67890"
        post.content = "Test post content"
        post.thread = thread
        
        try! testContext.save()
        
        // Verify relationship integrity
        XCTAssertEqual(thread.posts?.count, 1)
        XCTAssertEqual(post.thread, thread)
    }
}
```

#### Network Integration Tests
```swift
// Network layer integration testing
class NetworkIntegrationTests: XCTestCase {
    func testRealNetworkRequest() async throws {
        // Test against real server (use staging environment)
        let client = ForumsClient()
        
        do {
            let forums = try await client.loadForums()
            XCTAssertTrue(forums.count > 0)
            
            // Verify forum structure
            let firstForum = forums.first!
            XCTAssertFalse(firstForum.forumID.isEmpty)
            XCTAssertFalse(firstForum.name.isEmpty)
        } catch {
            XCTFail("Network request failed: \(error)")
        }
    }
    
    func testHTMLParsing() throws {
        // Test HTML parsing with real forum data
        let sampleHTML = loadSampleHTML("forum_list")
        let parser = ForumListParser()
        
        let forums = try parser.parseForums(from: sampleHTML)
        
        XCTAssertTrue(forums.count > 0)
        
        // Verify parsed data structure
        for forum in forums {
            XCTAssertFalse(forum.forumID.isEmpty)
            XCTAssertFalse(forum.name.isEmpty)
        }
    }
}
```

### End-to-End Testing

#### User Flow Testing
```swift
// Test complete user workflows
class UserFlowTests: XCTestCase {
    func testCompletePostingFlow() {
        let app = XCUIApplication()
        app.launch()
        
        // Test authentication flow
        app.buttons["Login"].tap()
        
        let usernameField = app.textFields["Username"]
        usernameField.tap()
        usernameField.typeText("testuser")
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("testpass")
        
        app.buttons["Sign In"].tap()
        
        // Wait for login to complete
        let forumsList = app.tables["Forums List"]
        XCTAssertTrue(forumsList.waitForExistence(timeout: 10))
        
        // Navigate to forum
        forumsList.cells.element(boundBy: 0).tap()
        
        // Navigate to thread
        let threadsList = app.tables["Threads List"]
        XCTAssertTrue(threadsList.waitForExistence(timeout: 5))
        threadsList.cells.element(boundBy: 0).tap()
        
        // Open compose view
        app.buttons["Reply"].tap()
        
        // Type post content
        let textView = app.textViews["Post Content"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5))
        textView.tap()
        textView.typeText("This is a test post")
        
        // Submit post
        app.buttons["Submit"].tap()
        
        // Verify post was submitted
        let successAlert = app.alerts["Post Submitted"]
        XCTAssertTrue(successAlert.waitForExistence(timeout: 10))
    }
}
```

## Testing Objective-C Legacy Code

### Bridging Headers and Test Setup

#### Test Setup for Objective-C Components
```objective-c
// MessageViewControllerTests.m
#import <XCTest/XCTest.h>
#import "MessageViewController.h"
#import "PrivateMessage.h"

@interface MessageViewControllerTests : XCTestCase
@property (nonatomic, strong) MessageViewController *messageViewController;
@property (nonatomic, strong) PrivateMessage *mockMessage;
@end

@implementation MessageViewControllerTests

- (void)setUp {
    [super setUp];
    
    self.mockMessage = [[PrivateMessage alloc] init];
    self.mockMessage.subject = @"Test Subject";
    self.mockMessage.content = @"Test Content";
    
    self.messageViewController = [[MessageViewController alloc] initWithPrivateMessage:self.mockMessage];
}

- (void)testInitialization {
    XCTAssertNotNil(self.messageViewController);
    XCTAssertEqualObjects(self.messageViewController.title, @"Test Subject");
    XCTAssertEqualObjects(self.messageViewController.privateMessage, self.mockMessage);
}

- (void)testViewLoading {
    [self.messageViewController loadViewIfNeeded];
    
    XCTAssertNotNil(self.messageViewController.view);
    
    // Test web view creation
    UIWebView *webView = nil;
    for (UIView *subview in self.messageViewController.view.subviews) {
        if ([subview isKindOfClass:[UIWebView class]]) {
            webView = (UIWebView *)subview;
            break;
        }
    }
    
    XCTAssertNotNil(webView);
    XCTAssertEqual(webView.delegate, self.messageViewController);
}

@end
```

#### Testing Objective-C Categories
```objective-c
// Test categories and extensions
@interface NSString (TestHelper)
- (NSString *)testMethod;
@end

@implementation NSString (TestHelper)
- (NSString *)testMethod {
    return @"test";
}
@end

@interface CategoryTests : XCTestCase
@end

@implementation CategoryTests

- (void)testStringCategory {
    NSString *testString = @"hello";
    NSString *result = [testString testMethod];
    XCTAssertEqualObjects(result, @"test");
}

@end
```

### Memory Management Testing

#### Testing for Memory Leaks
```swift
// Memory leak testing
class MemoryLeakTests: XCTestCase {
    func testMessageViewControllerMemoryLeak() {
        weak var weakController: MessageViewController?
        
        autoreleasepool {
            let message = createMockMessage()
            let controller = MessageViewController(privateMessage: message)
            weakController = controller
            
            // Use the controller
            controller.loadViewIfNeeded()
            controller.viewDidLoad()
            controller.viewWillAppear(false)
            controller.viewDidAppear(false)
            controller.viewWillDisappear(false)
            controller.viewDidDisappear(false)
        }
        
        // Force garbage collection
        let expectation = expectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
        
        // Verify controller was deallocated
        XCTAssertNil(weakController, "MessageViewController was not deallocated")
    }
}
```

## Performance Testing

### Performance Regression Testing

#### Measuring Performance
```swift
// Performance testing for legacy code
class PerformanceTests: XCTestCase {
    func testSmilieLoadingPerformance() {
        let dataStore = SmilieDataStore()
        
        measure {
            _ = dataStore.allSmilies()
        }
    }
    
    func testHTMLRenderingPerformance() {
        let renderer = MessageRenderer()
        let message = createLargeMessage()
        
        measure {
            do {
                _ = try renderer.renderHTML(for: message)
            } catch {
                XCTFail("Rendering failed: \(error)")
            }
        }
    }
    
    func testCoreDataBatchOperationPerformance() {
        let context = createTestContext()
        let posts = createMockPosts(count: 1000)
        
        measure {
            for post in posts {
                _ = Post.create(from: post, in: context)
            }
            
            do {
                try context.save()
            } catch {
                XCTFail("Save failed: \(error)")
            }
        }
    }
}
```

#### Memory Usage Testing
```swift
// Memory usage testing
class MemoryUsageTests: XCTestCase {
    func testImageCacheMemoryUsage() {
        let imageCache = SmilieImageCache.shared
        let initialMemory = getCurrentMemoryUsage()
        
        // Load many images
        for i in 0..<100 {
            let image = createTestImage(size: CGSize(width: 100, height: 100))
            imageCache.setImage(image, forKey: "test_\(i)")
        }
        
        let peakMemory = getCurrentMemoryUsage()
        
        // Clear cache
        imageCache.clearCache()
        
        let finalMemory = getCurrentMemoryUsage()
        
        // Verify memory was released
        XCTAssertLessThan(finalMemory, peakMemory)
        
        // Memory usage should return close to initial
        let memoryDifference = finalMemory - initialMemory
        XCTAssertLessThan(memoryDifference, 10_000_000) // 10MB tolerance
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
```

## Test Organization and Maintenance

### Test Structure

#### Test Categories
```swift
// Organize tests by functionality and risk level
class CriticalPathTests: XCTestCase {
    // Tests for authentication, posting, core functionality
}

class UITests: XCTestCase {
    // Tests for user interface components
}

class PerformanceTests: XCTestCase {
    // Performance and memory tests
}

class IntegrationTests: XCTestCase {
    // Component integration tests
}

class LegacyCodeTests: XCTestCase {
    // Characterization tests for legacy components
}
```

#### Test Helpers and Utilities
```swift
// Shared test utilities
class TestHelpers {
    static func createMockMessage() -> PrivateMessage {
        let message = PrivateMessage()
        message.subject = "Test Subject"
        message.content = "Test message content"
        message.sender = createMockUser()
        message.sentDate = Date()
        return message
    }
    
    static func createMockUser() -> User {
        let user = User()
        user.username = "testuser"
        user.userID = "12345"
        return user
    }
    
    static func createTestContext() -> NSManagedObjectContext {
        let model = NSManagedObjectModel.mergedModel(from: [Bundle.main])!
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        try! coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil,
            options: nil
        )
        
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        
        return context
    }
}
```

### Test Maintenance

#### Keeping Tests Updated
```swift
// Test maintenance guidelines
class TestMaintenanceTests: XCTestCase {
    func testAllMockObjectsAreUpToDate() {
        // Verify mock objects match current API
        let mockClient = MockForumsClient()
        let realClient = ForumsClient()
        
        // Use reflection to verify method signatures match
        let mockMethods = Mirror(reflecting: mockClient).children
        let realMethods = Mirror(reflecting: realClient).children
        
        // This test will fail if mock gets out of sync
        XCTAssertEqual(mockMethods.count, realMethods.count)
    }
    
    func testAllTestDataIsValid() {
        // Verify test data still matches expected formats
        let testMessage = TestHelpers.createMockMessage()
        
        XCTAssertFalse(testMessage.subject.isEmpty)
        XCTAssertFalse(testMessage.content.isEmpty)
        XCTAssertNotNil(testMessage.sender)
    }
}
```

## Continuous Integration

### Automated Test Execution

#### Test Pipeline Configuration
```yaml
# Test pipeline for legacy code
name: Legacy Code Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_14.0.app
    
    - name: Run Unit Tests
      run: |
        xcodebuild test \
          -scheme Awful \
          -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.0' \
          -only-testing:AwfulTests/LegacyCodeTests
    
    - name: Run Integration Tests
      run: |
        xcodebuild test \
          -scheme Awful \
          -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.0' \
          -only-testing:AwfulTests/IntegrationTests
    
    - name: Generate Coverage Report
      run: |
        xcrun xccov view --report --json \
          DerivedData/Awful/Logs/Test/*.xcresult > coverage.json
```

### Test Quality Metrics

#### Coverage Tracking
```swift
// Track test coverage for legacy components
class CoverageTests: XCTestCase {
    func testLegacyCodeCoverage() {
        // This test documents coverage expectations
        // Coverage tools will measure actual coverage
        
        // Document minimum coverage requirements
        let minimumCoverage = [
            "MessageViewController": 0.7,
            "SmilieDataStore": 0.8,
            "ForumsClient": 0.6
        ]
        
        // Coverage tool integration would verify these requirements
        XCTAssertTrue(minimumCoverage.count > 0)
    }
}
```

## Success Metrics

### Test Quality Indicators

#### Quantitative Metrics
- **Test Coverage**: >70% for legacy components
- **Test Execution Time**: <5 minutes for full test suite
- **Test Reliability**: <1% flaky test rate
- **Test Maintenance**: <10% of development time

#### Qualitative Metrics
- **Test Clarity**: Tests are easy to understand and modify
- **Test Value**: Tests catch real bugs and prevent regressions
- **Test Confidence**: Developers trust tests to catch issues
- **Test Documentation**: Tests serve as living documentation

### Refactoring Safety

#### Regression Prevention
- **Zero Regressions**: No functionality lost during refactoring
- **Behavior Preservation**: All existing behaviors maintained
- **Performance Maintenance**: No performance degradation
- **User Experience**: No negative impact on user experience

## Conclusion

Testing legacy code requires a pragmatic approach that balances thorough coverage with practical constraints. The key strategies are:

1. **Start with characterization tests** to document current behavior
2. **Break dependencies gradually** to enable better testing
3. **Use integration tests** to verify component interactions
4. **Implement performance tests** to prevent regressions
5. **Maintain test quality** through continuous improvement

By following these testing strategies, Awful.app can safely modernize its legacy codebase while maintaining the reliability and stability that users expect. The investment in comprehensive testing will pay dividends in faster development, fewer bugs, and greater confidence in making changes.