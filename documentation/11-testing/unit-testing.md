# Unit Testing

## Overview

Unit testing in Awful.app focuses on testing individual components in isolation. This document covers strategies, patterns, and best practices for writing effective unit tests across the application's modular architecture.

## Current Unit Test Coverage

### AwfulCore Unit Tests

#### Scraping Tests
- **Purpose**: Verify HTML parsing and data extraction
- **Location**: `AwfulCore/Tests/AwfulCoreTests/Scraping/`
- **Coverage**: Posts, threads, profiles, announcements, private messages

```swift
final class PostScrapingTests: XCTestCase {
    func testIgnoredPost() throws {
        let result = try scrapeHTMLFixture(ShowPostScrapeResult.self, named: "showpost")
        XCTAssertEqual(result.author.username, "The Dave")
        XCTAssert(result.post.body.contains("Which command?"))
        XCTAssertEqual(result.threadID?.rawValue, "3510131")
        XCTAssertEqual(result.threadTitle, "Awful iPhone/iPad app - error code -1002")
    }
}
```

#### Persistence Tests
- **Purpose**: Verify Core Data operations and data integrity
- **Location**: `AwfulCore/Tests/AwfulCoreTests/Persistence/`
- **Coverage**: CRUD operations, relationships, migrations

```swift
final class ThreadListPersistenceTests: XCTestCase {
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = makeInMemoryStoreContext()
    }
    
    func testThreadPersistence() throws {
        // Test Core Data operations with in-memory store
        let thread = Thread(context: context)
        thread.title = "Test Thread"
        thread.threadID = "12345"
        
        try context.save()
        
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        let threads = try context.fetch(request)
        
        XCTAssertEqual(threads.count, 1)
        XCTAssertEqual(threads.first?.title, "Test Thread")
    }
}
```

#### Client Tests
- **Purpose**: Verify HTTP client behavior and form handling
- **Location**: `AwfulCore/Tests/AwfulCoreTests/Client/`
- **Coverage**: Form parsing, parameter encoding, request building

```swift
final class IgnoreListFormTests: XCTestCase {
    func testFormScraping() throws {
        let form = try scrapeForm(matchingSelector: "form[name='ignorelist']", 
                                 inFixtureNamed: "ignorelist")
        XCTAssertEqual(form.textboxes.count, 2)
        XCTAssertEqual(form.textboxes[0].name, "username")
        XCTAssertEqual(form.textboxes[1].name, "reason")
    }
}
```

### AwfulExtensions Unit Tests

#### Collection Extensions
- **Purpose**: Verify utility functions and extensions
- **Location**: `AwfulExtensions/Tests/Swift/`
- **Coverage**: Array operations, string manipulation, type extensions

```swift
final class CollectionTests: XCTestCase {
    func testSafeSubscript() {
        let array = [1, 2, 3]
        XCTAssertEqual(array[safe: 0], 1)
        XCTAssertEqual(array[safe: 2], 3)
        XCTAssertNil(array[safe: 3])
        XCTAssertNil(array[safe: -1])
    }
}
```

### SmiliesTests Unit Tests

#### Smilie Management
- **Purpose**: Verify smilie parsing and keyboard functionality
- **Location**: `Smilies/Tests/SmiliesTests/`
- **Coverage**: Smilie extraction, bundled resources, data cleanup

```objective-c
@interface SmiliesTests : XCTestCase
@end

@implementation SmiliesTests

- (void)testBundledSmilies {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSArray *smilies = [bundle pathsForResourcesOfType:@"png" inDirectory:@"Smilies"];
    XCTAssertGreaterThan(smilies.count, 0);
}

- (void)testSmilieExtraction {
    // Test smilie parsing from web archive
    NSString *fixturePath = [[NSBundle bundleForClass:[self class]] 
                            pathForResource:@"showsmilies" ofType:@"webarchive"];
    NSWebArchive *archive = [[NSWebArchive alloc] initWithData:[NSData dataWithContentsOfFile:fixturePath]];
    // Additional test logic
}

@end
```

### AwfulScrapingTests Unit Tests

#### Decoding Strategies
- **Purpose**: Verify custom decoding and parsing strategies
- **Location**: `AwfulScraping/Tests/AwfulScrapingTests/`
- **Coverage**: Date parsing, sequence operations, JSON decoding

```swift
final class AwfulDateDecodingStrategyTests: XCTestCase {
    func testDateParsing() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "America/Chicago")
        
        // Test SA Forums date parsing with old DST rules
        let date = PostDateFormatter.date(from: "Mar 14, 2010 2:15 AM")
        XCTAssertNotNil(date)
        
        // Test edge cases during DST transitions
        let dstDate = PostDateFormatter.date(from: "Apr 4, 2010 2:15 AM")
        XCTAssertNotNil(dstDate)
    }
}
```

## Unit Testing Patterns

### Test Structure Pattern

```swift
final class ComponentTests: XCTestCase {
    // MARK: - Test Lifecycle
    
    override func setUp() {
        super.setUp()
        // Setup test environment
    }
    
    override func tearDown() {
        // Cleanup test environment
        super.tearDown()
    }
    
    // MARK: - Happy Path Tests
    
    func testNormalOperation() throws {
        // Arrange
        let input = createTestInput()
        
        // Act
        let result = systemUnderTest.process(input)
        
        // Assert
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.data, expectedData)
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyInput() throws {
        let result = systemUnderTest.process(nil)
        XCTAssertEqual(result.status, .error)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidInput() throws {
        XCTAssertThrowsError(try systemUnderTest.process(invalidInput)) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
}
```

### Mock Objects Pattern

```swift
class MockForumsClient: ForumsClient {
    var capturedRequests: [URLRequest] = []
    var stubbedResponse: Result<Data, Error>?
    
    override func perform(_ request: URLRequest) async throws -> Data {
        capturedRequests.append(request)
        
        switch stubbedResponse {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        case .none:
            return Data()
        }
    }
}
```

### Test Data Builders

```swift
class TestDataBuilder {
    static func makeThread(
        id: String = "12345",
        title: String = "Test Thread",
        forum: Forum? = nil
    ) -> Thread {
        let thread = Thread(context: testContext)
        thread.threadID = id
        thread.title = title
        thread.forum = forum
        return thread
    }
    
    static func makePost(
        id: String = "67890",
        content: String = "Test content",
        author: User? = nil
    ) -> Post {
        let post = Post(context: testContext)
        post.postID = id
        post.innerHTML = content
        post.author = author
        return post
    }
}
```

## Testing Strategies by Component

### View Controllers

```swift
final class PostsPageViewControllerTests: XCTestCase {
    var viewController: PostsPageViewController!
    var mockForumsClient: MockForumsClient!
    
    override func setUp() {
        super.setUp()
        mockForumsClient = MockForumsClient()
        viewController = PostsPageViewController(
            thread: TestDataBuilder.makeThread(),
            forumsClient: mockForumsClient
        )
    }
    
    func testLoadPosts() {
        // Test view controller loading behavior
        mockForumsClient.stubbedResponse = .success(loadFixture("posts"))
        
        viewController.loadViewIfNeeded()
        viewController.viewDidLoad()
        
        XCTAssertTrue(viewController.isLoading)
        // Additional assertions
    }
}
```

### Data Models

```swift
final class ThreadTests: XCTestCase {
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = makeInMemoryStoreContext()
    }
    
    func testThreadCreation() {
        let thread = Thread(context: context)
        thread.threadID = "12345"
        thread.title = "Test Thread"
        
        XCTAssertEqual(thread.threadID, "12345")
        XCTAssertEqual(thread.title, "Test Thread")
        XCTAssertFalse(thread.isBookmarked)
    }
    
    func testThreadBookmarking() {
        let thread = TestDataBuilder.makeThread()
        
        thread.toggleBookmark()
        XCTAssertTrue(thread.isBookmarked)
        
        thread.toggleBookmark()
        XCTAssertFalse(thread.isBookmarked)
    }
}
```

### HTML Scraping

```swift
final class ProfileScrapingTests: XCTestCase {
    func testProfileScraping() throws {
        let result = try scrapeHTMLFixture(ProfileScrapeResult.self, named: "profile")
        
        XCTAssertEqual(result.user.username, "TestUser")
        XCTAssertEqual(result.user.userID, "123456")
        XCTAssertNotNil(result.user.avatarURL)
        XCTAssertEqual(result.user.postCount, 1234)
    }
    
    func testProfileScrapingWithMissingData() throws {
        let result = try scrapeHTMLFixture(ProfileScrapeResult.self, named: "profile-minimal")
        
        XCTAssertEqual(result.user.username, "MinimalUser")
        XCTAssertNil(result.user.avatarURL)
        XCTAssertEqual(result.user.postCount, 0)
    }
}
```

### Networking

```swift
final class HTTPClientTests: XCTestCase {
    var client: HTTPClient!
    var mockSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        client = HTTPClient(session: mockSession)
    }
    
    func testGetRequest() async throws {
        let expectedData = Data("response".utf8)
        mockSession.stubbedData = expectedData
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let data = try await client.perform(request)
        
        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(mockSession.capturedRequests.count, 1)
    }
}
```

## Test Helpers and Utilities

### Fixture Loading

```swift
extension XCTestCase {
    func loadFixture(named name: String, extension ext: String = "html") -> Data {
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")!
        return try! Data(contentsOf: url)
    }
    
    func loadHTMLFixture(named name: String) -> HTMLDocument {
        let data = loadFixture(named: name)
        let string = String(data: data, encoding: .windowsCP1252)!
        return HTMLDocument(string: string)
    }
}
```

### Assertion Helpers

```swift
extension XCTestCase {
    func XCTAssertEventually(
        _ expression: @autoclosure () throws -> Bool,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = XCTestExpectation(description: "Eventually true")
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            do {
                if try expression() {
                    expectation.fulfill()
                    timer.invalidate()
                }
            } catch {
                XCTFail("Expression threw error: \(error)", file: file, line: line)
                timer.invalidate()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }
}
```

## Testing Best Practices

### Test Organization

#### File Structure
```
Tests/
├── Unit/
│   ├── Models/
│   │   ├── ThreadTests.swift
│   │   └── PostTests.swift
│   ├── ViewControllers/
│   │   ├── PostsPageViewControllerTests.swift
│   │   └── ThreadsTableViewControllerTests.swift
│   └── Utilities/
│       ├── HTMLScrapingTests.swift
│       └── DateParsingTests.swift
├── TestHelpers/
│   ├── TestDataBuilder.swift
│   ├── MockObjects.swift
│   └── XCTestCase+Extensions.swift
└── Fixtures/
    ├── HTML/
    └── JSON/
```

#### Naming Conventions
- Test classes: `{ComponentName}Tests`
- Test methods: `test{WhatIsBeingTested}` or `test{WhatIsBeingTested}_{ExpectedOutcome}`
- Mock objects: `Mock{ComponentName}`
- Test data: `make{ObjectName}` or `create{ObjectName}`

### Test Data Management

#### Fixture Guidelines
- Use realistic but anonymized data
- Keep fixtures minimal and focused
- Version control all test data
- Document fixture purposes

#### Test Data Builders
```swift
struct TestDataBuilder {
    static func makeThread(
        id: String = UUID().uuidString,
        title: String = "Test Thread",
        configure: (Thread) -> Void = { _ in }
    ) -> Thread {
        let thread = Thread(context: testContext)
        thread.threadID = id
        thread.title = title
        configure(thread)
        return thread
    }
}
```

### Testing Asynchronous Code

```swift
func testAsyncOperation() async throws {
    let result = try await asyncOperation()
    XCTAssertEqual(result.status, .success)
}

func testAsyncOperationWithTimeout() throws {
    let expectation = XCTestExpectation(description: "Async operation completes")
    
    asyncOperation { result in
        XCTAssertEqual(result.status, .success)
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
}
```

### Memory Management Testing

```swift
func testMemoryLeaks() {
    weak var weakReference: ViewControllerType?
    
    autoreleasepool {
        let viewController = ViewControllerType()
        weakReference = viewController
        
        // Exercise the view controller
        viewController.loadViewIfNeeded()
        viewController.viewDidLoad()
    }
    
    XCTAssertNil(weakReference, "View controller should be deallocated")
}
```

## Migration Testing Strategy

### UIKit to SwiftUI

```swift
final class MigrationTests: XCTestCase {
    func testUIKitSwiftUIBehaviorParity() {
        // Test both implementations produce same results
        let uikitResult = UIKitImplementation().process(testInput)
        let swiftuiResult = SwiftUIImplementation().process(testInput)
        
        XCTAssertEqual(uikitResult, swiftuiResult)
    }
}
```

### Data Model Changes

```swift
final class MigrationTests: XCTestCase {
    func testDataModelMigration() throws {
        // Test Core Data migration
        let oldModelURL = Bundle.main.url(forResource: "Model_v1", withExtension: "momd")!
        let newModelURL = Bundle.main.url(forResource: "Model_v2", withExtension: "momd")!
        
        // Test migration logic
        let migrator = DataModelMigrator(from: oldModelURL, to: newModelURL)
        let success = try migrator.performMigration()
        
        XCTAssertTrue(success)
    }
}
```

## Performance Testing

### Benchmarking

```swift
func testPerformance() {
    measure {
        // Code to benchmark
        let result = expensiveOperation()
        XCTAssertNotNil(result)
    }
}

func testMemoryUsage() {
    let initialMemory = getMemoryUsage()
    
    // Perform operation
    let result = memoryIntensiveOperation()
    
    let finalMemory = getMemoryUsage()
    let memoryIncrease = finalMemory - initialMemory
    
    XCTAssertLessThan(memoryIncrease, 10_000_000) // 10MB threshold
}
```

## Code Coverage

### Measuring Coverage
- Use Xcode's built-in code coverage
- Focus on critical paths and business logic
- Aim for 80%+ coverage on core components
- Don't chase 100% coverage at the expense of quality

### Coverage Reports
```bash
# Generate coverage report
xcodebuild test -scheme Awful -destination 'platform=iOS Simulator,name=iPhone 14' -enableCodeCoverage YES

# Extract coverage data
xcrun xccov view --report --only-targets DerivedData/Build/Logs/Test/*.xccovreport
```

## Future Improvements

### Planned Enhancements
- Property-based testing for edge cases
- Snapshot testing for UI components
- Contract testing for API interactions
- Mutation testing for test quality

### Tool Integration
- SwiftLint for test code quality
- Danger for automated PR checks
- Fastlane for test automation
- Quick/Nimble for more expressive assertions