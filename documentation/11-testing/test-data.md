# Test Data

## Overview

Test data management in Awful.app ensures consistent, reliable, and comprehensive testing across all components. This document covers test fixtures, mock data generation, and data management strategies for effective testing.

## Test Data Architecture

### Data Categories

#### HTML Fixtures
- **Forum Pages**: Complete forum listing HTML
- **Thread Lists**: Thread directory pages with pagination
- **Post Pages**: Individual thread pages with posts
- **User Profiles**: User information and statistics
- **Forms**: Login, reply, and settings forms

#### JSON Fixtures
- **API Responses**: Mock server responses
- **Configuration Data**: Settings and preferences
- **User Data**: Authentication and session information
- **Metadata**: Thread tags, smilies, and assets

#### Core Data Fixtures
- **Entity Relationships**: Complete object graphs
- **Migration Data**: Before/after migration states
- **Performance Data**: Large datasets for stress testing
- **Edge Cases**: Boundary conditions and unusual states

## HTML Test Fixtures

### Fixture Organization

```
Tests/Fixtures/HTML/
├── Forums/
│   ├── forum-index.html
│   ├── forum-list-empty.html
│   ├── forum-list-large.html
│   └── forum-categories.html
├── Threads/
│   ├── thread-list.html
│   ├── thread-list-empty.html
│   ├── thread-list-pagination.html
│   └── sticky-threads.html
├── Posts/
│   ├── showpost.html
│   ├── posts-page-1.html
│   ├── posts-large-thread.html
│   ├── posts-with-images.html
│   └── posts-with-quotes.html
├── Users/
│   ├── profile.html
│   ├── profile-minimal.html
│   ├── profile-banned.html
│   └── profile-probated.html
└── Forms/
    ├── login.html
    ├── reply-form.html
    ├── edit-post-form.html
    └── settings-form.html
```

### HTML Fixture Loading

```swift
// Core fixture loading functionality
extension XCTestCase {
    func loadHTMLFixture(named name: String) throws -> HTMLDocument {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: "html", subdirectory: "Fixtures/HTML") else {
            throw TestError.fixtureNotFound(name)
        }
        
        let data = try Data(contentsOf: url)
        let string = String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .utf8)!
        return HTMLDocument(string: string)
    }
    
    func scrapeHTMLFixture<T: ScrapeResult>(_ type: T.Type, named fixtureName: String) throws -> T {
        let document = try loadHTMLFixture(named: fixtureName)
        return try T(document, url: URL(string: "https://forums.somethingawful.com/")!)
    }
}

// Specialized fixture loaders
extension XCTestCase {
    func loadForumFixture(_ variant: ForumFixtureVariant = .standard) throws -> HTMLDocument {
        let fixtureName = switch variant {
        case .standard: "forum-list"
        case .empty: "forum-list-empty"
        case .large: "forum-list-large"
        case .categories: "forum-categories"
        }
        return try loadHTMLFixture(named: fixtureName)
    }
    
    func loadThreadFixture(_ variant: ThreadFixtureVariant = .standard) throws -> HTMLDocument {
        let fixtureName = switch variant {
        case .standard: "thread-list"
        case .empty: "thread-list-empty"
        case .pagination: "thread-list-pagination"
        case .sticky: "sticky-threads"
        }
        return try loadHTMLFixture(named: fixtureName)
    }
    
    func loadPostsFixture(_ variant: PostsFixtureVariant = .standard) throws -> HTMLDocument {
        let fixtureName = switch variant {
        case .standard: "posts-page-1"
        case .large: "posts-large-thread"
        case .withImages: "posts-with-images"
        case .withQuotes: "posts-with-quotes"
        case .singlePost: "showpost"
        }
        return try loadHTMLFixture(named: fixtureName)
    }
}
```

### Fixture Variants

```swift
enum ForumFixtureVariant {
    case standard    // Normal forum list
    case empty      // No forums
    case large      // Many forums
    case categories // With categories
}

enum ThreadFixtureVariant {
    case standard   // Normal thread list
    case empty     // No threads
    case pagination // Multiple pages
    case sticky    // Sticky threads
}

enum PostsFixtureVariant {
    case standard   // Normal posts page
    case large     // Many posts
    case withImages // Posts with images
    case withQuotes // Posts with quotes
    case singlePost // Single post view
}

enum UserFixtureVariant {
    case standard // Normal user profile
    case minimal  // Minimal profile data
    case banned   // Banned user
    case probated // User under probation
}
```

## JSON Test Fixtures

### JSON Fixture Structure

```
Tests/Fixtures/JSON/
├── API/
│   ├── announcements.json
│   ├── private-messages.json
│   ├── user-session.json
│   └── error-responses.json
├── Settings/
│   ├── default-settings.json
│   ├── custom-settings.json
│   └── migration-settings.json
├── Metadata/
│   ├── thread-tags.json
│   ├── smilies-list.json
│   └── forum-metadata.json
└── Performance/
    ├── large-dataset.json
    ├── stress-test-data.json
    └── benchmark-data.json
```

### JSON Fixture Loading

```swift
extension XCTestCase {
    func loadJSONFixture<T: Decodable>(_ type: T.Type, named name: String) throws -> T {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/JSON") else {
            throw TestError.fixtureNotFound(name)
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(type, from: data)
    }
    
    func loadSettingsFixture(_ variant: SettingsVariant = .default) throws -> SettingsData {
        let fixtureName = switch variant {
        case .default: "default-settings"
        case .custom: "custom-settings"
        case .migration: "migration-settings"
        }
        return try loadJSONFixture(SettingsData.self, named: fixtureName)
    }
    
    func loadAnnouncementsFixture() throws -> [Announcement] {
        return try loadJSONFixture([Announcement].self, named: "announcements")
    }
    
    func loadPrivateMessagesFixture() throws -> [PrivateMessage] {
        return try loadJSONFixture([PrivateMessage].self, named: "private-messages")
    }
}
```

## Mock Data Generation

### Test Data Builders

```swift
struct TestDataBuilder {
    // MARK: - Core Data Objects
    
    static func makeThread(
        id: String = UUID().uuidString,
        title: String = "Test Thread",
        postCount: Int = 10,
        isBookmarked: Bool = false,
        forum: Forum? = nil,
        context: NSManagedObjectContext = testContext
    ) -> Thread {
        let thread = Thread(context: context)
        thread.threadID = id
        thread.title = title
        thread.totalPostCount = Int32(postCount)
        thread.isBookmarked = isBookmarked
        thread.forum = forum ?? makeForum(context: context)
        thread.lastPostDate = Date()
        thread.isArchived = false
        thread.isClosed = false
        thread.isSticky = false
        return thread
    }
    
    static func makeForum(
        id: String = UUID().uuidString,
        name: String = "Test Forum",
        category: ForumCategory? = nil,
        context: NSManagedObjectContext = testContext
    ) -> Forum {
        let forum = Forum(context: context)
        forum.forumID = id
        forum.name = name
        forum.category = category ?? makeForumCategory(context: context)
        forum.lastPostDate = Date()
        forum.canPost = true
        return forum
    }
    
    static func makePost(
        id: String = UUID().uuidString,
        content: String = "Test post content",
        author: User? = nil,
        thread: Thread? = nil,
        context: NSManagedObjectContext = testContext
    ) -> Post {
        let post = Post(context: context)
        post.postID = id
        post.innerHTML = content
        post.postDate = Date()
        post.author = author ?? makeUser(context: context)
        post.thread = thread ?? makeThread(context: context)
        return post
    }
    
    static func makeUser(
        id: String = UUID().uuidString,
        username: String = "TestUser",
        postCount: Int = 100,
        context: NSManagedObjectContext = testContext
    ) -> User {
        let user = User(context: context)
        user.userID = id
        user.username = username
        user.postCount = Int32(postCount)
        user.regdate = Date().addingTimeInterval(-86400 * 365) // 1 year ago
        user.canReceivePrivateMessages = true
        return user
    }
    
    // MARK: - Complex Object Graphs
    
    static func makeCompleteThreadHierarchy(
        threadCount: Int = 5,
        postsPerThread: Int = 20,
        context: NSManagedObjectContext = testContext
    ) -> [Thread] {
        let category = makeForumCategory(name: "Test Category", context: context)
        let forum = makeForum(name: "Test Forum", category: category, context: context)
        
        var threads: [Thread] = []
        
        for i in 0..<threadCount {
            let thread = makeThread(
                id: "\(i + 1)",
                title: "Thread \(i + 1)",
                postCount: postsPerThread,
                forum: forum,
                context: context
            )
            
            // Create posts for thread
            for j in 0..<postsPerThread {
                let user = makeUser(
                    id: "user-\(j % 3)", // Reuse some users
                    username: "User\(j % 3)",
                    context: context
                )
                
                let post = makePost(
                    id: "post-\(i)-\(j)",
                    content: "Post \(j + 1) content in thread \(i + 1)",
                    author: user,
                    thread: thread,
                    context: context
                )
                
                thread.addToPosts(post)
            }
            
            threads.append(thread)
        }
        
        return threads
    }
    
    // MARK: - Performance Test Data
    
    static func makeLargeDataSet(
        forumCount: Int = 50,
        threadsPerForum: Int = 100,
        postsPerThread: Int = 50,
        context: NSManagedObjectContext = testContext
    ) {
        for i in 0..<forumCount {
            let category = makeForumCategory(name: "Category \(i)", context: context)
            let forum = makeForum(name: "Forum \(i)", category: category, context: context)
            
            for j in 0..<threadsPerForum {
                let thread = makeThread(
                    id: "thread-\(i)-\(j)",
                    title: "Thread \(j) in Forum \(i)",
                    forum: forum,
                    context: context
                )
                
                for k in 0..<postsPerThread {
                    let user = makeUser(
                        id: "user-\(k % 10)", // Reuse users
                        username: "User\(k % 10)",
                        context: context
                    )
                    
                    let post = makePost(
                        id: "post-\(i)-\(j)-\(k)",
                        content: generateRandomPostContent(),
                        author: user,
                        thread: thread,
                        context: context
                    )
                    
                    thread.addToPosts(post)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private static func generateRandomPostContent() -> String {
        let sentences = [
            "This is a test post.",
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            "Ut enim ad minim veniam, quis nostrud exercitation.",
            "Duis aute irure dolor in reprehenderit in voluptate.",
            "Excepteur sint occaecat cupidatat non proident."
        ]
        
        let sentenceCount = Int.random(in: 1...4)
        return (0..<sentenceCount)
            .map { _ in sentences.randomElement()! }
            .joined(separator: " ")
    }
}
```

### Factory Pattern for Test Objects

```swift
protocol TestObjectFactory {
    associatedtype Product
    func create() -> Product
}

struct ThreadFactory: TestObjectFactory {
    let title: String
    let postCount: Int
    let isBookmarked: Bool
    let forum: Forum?
    
    init(title: String = "Test Thread", postCount: Int = 10, isBookmarked: Bool = false, forum: Forum? = nil) {
        self.title = title
        self.postCount = postCount
        self.isBookmarked = isBookmarked
        self.forum = forum
    }
    
    func create() -> Thread {
        return TestDataBuilder.makeThread(
            title: title,
            postCount: postCount,
            isBookmarked: isBookmarked,
            forum: forum
        )
    }
}

struct UserFactory: TestObjectFactory {
    let username: String
    let postCount: Int
    let registrationDate: Date
    
    init(username: String = "TestUser", postCount: Int = 100, registrationDate: Date = Date()) {
        self.username = username
        self.postCount = postCount
        self.registrationDate = registrationDate
    }
    
    func create() -> User {
        return TestDataBuilder.makeUser(
            username: username,
            postCount: postCount
        )
    }
}
```

## Test Database Management

### In-Memory Core Data Stack

```swift
class TestDataStore {
    static let shared = TestDataStore()
    
    private let persistentContainer: NSPersistentContainer
    
    init() {
        persistentContainer = NSPersistentContainer(name: "DataModel")
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
    }
    
    var mainContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    func reset() {
        let coordinator = persistentContainer.persistentStoreCoordinator
        
        for store in coordinator.persistentStores {
            try! coordinator.remove(store)
        }
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        try! coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil,
            options: nil
        )
    }
    
    func populate(with builder: (NSManagedObjectContext) -> Void) {
        let context = backgroundContext
        context.performAndWait {
            builder(context)
            try! context.save()
        }
    }
}

// Global test context for convenience
var testContext: NSManagedObjectContext {
    return TestDataStore.shared.mainContext
}
```

### Test Data Population

```swift
extension TestDataStore {
    func populateWithSampleData() {
        populate { context in
            // Create sample forum hierarchy
            let categories = [
                "Main Forums",
                "Discussion",
                "Community"
            ]
            
            for categoryName in categories {
                let category = TestDataBuilder.makeForumCategory(
                    name: categoryName,
                    context: context
                )
                
                // Create forums in category
                for i in 1...5 {
                    let forum = TestDataBuilder.makeForum(
                        name: "\(categoryName) Forum \(i)",
                        category: category,
                        context: context
                    )
                    
                    // Create threads in forum
                    for j in 1...20 {
                        let thread = TestDataBuilder.makeThread(
                            title: "Thread \(j) in \(forum.name!)",
                            forum: forum,
                            context: context
                        )
                        
                        // Create posts in thread
                        for k in 1...10 {
                            let user = TestDataBuilder.makeUser(
                                username: "User\(k % 5)",
                                context: context
                            )
                            
                            TestDataBuilder.makePost(
                                content: "Post \(k) content",
                                author: user,
                                thread: thread,
                                context: context
                            )
                        }
                    }
                }
            }
        }
    }
    
    func populateWithPerformanceData() {
        populate { context in
            TestDataBuilder.makeLargeDataSet(
                forumCount: 100,
                threadsPerForum: 200,
                postsPerThread: 100,
                context: context
            )
        }
    }
    
    func populateWithEdgeCaseData() {
        populate { context in
            // Empty forum
            TestDataBuilder.makeForum(name: "Empty Forum", context: context)
            
            // Thread with no posts
            TestDataBuilder.makeThread(title: "Empty Thread", postCount: 0, context: context)
            
            // Thread with many posts
            let largeThread = TestDataBuilder.makeThread(
                title: "Large Thread",
                postCount: 1000,
                context: context
            )
            
            // User with no posts
            TestDataBuilder.makeUser(username: "Lurker", postCount: 0, context: context)
            
            // Very long thread title
            TestDataBuilder.makeThread(
                title: String(repeating: "Very Long Thread Title ", count: 10),
                context: context
            )
        }
    }
}
```

## Mock Network Data

### URL Protocol Mocking

```swift
class MockURLProtocol: URLProtocol {
    static var responses: [URLRequest: (Data, URLResponse, Error?)] = [:]
    static var delay: TimeInterval = 0
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        if Self.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.delay) {
                self.handleRequest()
            }
        } else {
            handleRequest()
        }
    }
    
    override func stopLoading() {}
    
    private func handleRequest() {
        guard let (data, response, error) = Self.responses[request] else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockError", code: 404))
            return
        }
        
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    
    // Convenience methods for setting up responses
    static func mockResponse(for url: URL, data: Data, statusCode: Int = 200) {
        let request = URLRequest(url: url)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        responses[request] = (data, response, nil)
    }
    
    static func mockError(for url: URL, error: Error) {
        let request = URLRequest(url: url)
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
        responses[request] = (Data(), response, error)
    }
    
    static func reset() {
        responses.removeAll()
        delay = 0
    }
}
```

### Network Response Builders

```swift
struct NetworkResponseBuilder {
    static func buildForumListResponse() -> Data {
        return loadHTMLFixture("forum-list").data(using: .windowsCP1252) ?? Data()
    }
    
    static func buildThreadListResponse(forumID: String, page: Int = 1) -> Data {
        // Generate dynamic thread list based on parameters
        var html = loadHTMLFixture("thread-list")
        html = html.replacingOccurrences(of: "{{FORUM_ID}}", with: forumID)
        html = html.replacingOccurrences(of: "{{PAGE}}", with: "\(page)")
        return html.data(using: .windowsCP1252) ?? Data()
    }
    
    static func buildPostsPageResponse(threadID: String, page: Int = 1) -> Data {
        var html = loadHTMLFixture("posts-page")
        html = html.replacingOccurrences(of: "{{THREAD_ID}}", with: threadID)
        html = html.replacingOccurrences(of: "{{PAGE}}", with: "\(page)")
        return html.data(using: .windowsCP1252) ?? Data()
    }
    
    static func buildErrorResponse(type: ErrorType) -> Data {
        let fixtureName = switch type {
        case .loginRequired: "error-login-required"
        case .bannedUser: "error-banned"
        case .databaseUnavailable: "error-database"
        case .genericError: "error-generic"
        }
        return loadHTMLFixture(fixtureName).data(using: .windowsCP1252) ?? Data()
    }
}

enum ErrorType {
    case loginRequired
    case bannedUser
    case databaseUnavailable
    case genericError
}
```

## Test Data Validation

### Data Integrity Checks

```swift
class TestDataValidator {
    static func validateTestData(in context: NSManagedObjectContext) throws {
        // Check for required relationships
        let threads = try context.fetch(Thread.fetchRequest())
        for thread in threads {
            guard thread.forum != nil else {
                throw ValidationError.missingRelationship("Thread \(thread.threadID ?? "unknown") missing forum")
            }
        }
        
        let posts = try context.fetch(Post.fetchRequest())
        for post in posts {
            guard post.author != nil else {
                throw ValidationError.missingRelationship("Post \(post.postID ?? "unknown") missing author")
            }
            guard post.thread != nil else {
                throw ValidationError.missingRelationship("Post \(post.postID ?? "unknown") missing thread")
            }
        }
        
        // Check for data consistency
        for thread in threads {
            let postCount = thread.posts?.count ?? 0
            guard postCount == Int(thread.totalPostCount) else {
                throw ValidationError.inconsistentData("Thread \(thread.threadID ?? "unknown") post count mismatch")
            }
        }
    }
    
    static func validateFixtureIntegrity() throws {
        let requiredFixtures = [
            "forum-list",
            "thread-list",
            "posts-page-1",
            "showpost",
            "profile",
            "login"
        ]
        
        for fixture in requiredFixtures {
            do {
                _ = try loadHTMLFixture(fixture)
            } catch {
                throw ValidationError.missingFixture(fixture)
            }
        }
    }
}

enum ValidationError: Error {
    case missingRelationship(String)
    case inconsistentData(String)
    case missingFixture(String)
}
```

## Test Data Cleanup

### Automatic Cleanup

```swift
protocol TestDataCleanup {
    func cleanupTestData()
}

extension XCTestCase: TestDataCleanup {
    func cleanupTestData() {
        // Reset Core Data
        TestDataStore.shared.reset()
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Clear image cache
        ImageCache.shared.removeAll()
        
        // Reset mock network responses
        MockURLProtocol.reset()
        
        // Clear temporary files
        clearTemporaryFiles()
    }
    
    private func clearTemporaryFiles() {
        let tempURL = FileManager.default.temporaryDirectory
        let testFilesURL = tempURL.appendingPathComponent("AwfulTests")
        
        if FileManager.default.fileExists(atPath: testFilesURL.path) {
            try? FileManager.default.removeItem(at: testFilesURL)
        }
    }
}
```

### Test Environment Reset

```swift
class TestEnvironmentManager {
    static let shared = TestEnvironmentManager()
    
    private init() {}
    
    func resetEnvironment() {
        resetDataStore()
        resetUserDefaults()
        resetNetworkMocks()
        resetImageCache()
        resetNotifications()
    }
    
    private func resetDataStore() {
        TestDataStore.shared.reset()
    }
    
    private func resetUserDefaults() {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        
        for key in keys {
            if key.hasPrefix("Awful") {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    private func resetNetworkMocks() {
        MockURLProtocol.reset()
    }
    
    private func resetImageCache() {
        ImageCache.shared.removeAll()
    }
    
    private func resetNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
```

## Best Practices

### Test Data Management
- Use realistic but anonymized data
- Maintain fixture freshness and relevance
- Version control all test fixtures
- Document fixture purposes and usage

### Performance Considerations
- Use in-memory stores for fast execution
- Generate large datasets programmatically
- Cache frequently used test objects
- Clean up resources after tests

### Maintainability
- Create reusable test data builders
- Use factories for complex object creation
- Validate test data integrity
- Automate fixture updates when possible

### Reliability
- Reset test environment between tests
- Use deterministic test data
- Handle missing fixtures gracefully
- Validate test data before use

## Future Enhancements

### Planned Improvements
- Dynamic fixture generation from live data
- Test data version management
- Automated fixture validation
- Performance-optimized test data loading

### Tool Integration
- Fixture management tools
- Data anonymization utilities
- Test data generation scripts
- Continuous fixture validation