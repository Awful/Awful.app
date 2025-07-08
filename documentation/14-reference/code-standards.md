# Code Standards and Conventions

Comprehensive coding standards and style guidelines for the Awful.app project.

## Table of Contents

- [Swift Style Guide](#swift-style-guide)
- [Objective-C Style Guide](#objective-c-style-guide)
- [File Organization](#file-organization)
- [Documentation Standards](#documentation-standards)
- [Error Handling](#error-handling)
- [Testing Standards](#testing-standards)
- [Performance Guidelines](#performance-guidelines)
- [Security Best Practices](#security-best-practices)

## Swift Style Guide

### General Principles

- **Clarity over brevity**: Code should be self-documenting
- **Consistency**: Follow existing patterns in the codebase
- **Swift-first**: Prefer Swift idioms over Objective-C patterns
- **Type safety**: Leverage Swift's type system for safer code

### Naming Conventions

#### Classes and Structs

Use PascalCase for types:

```swift
// ✅ Good
class ForumsClient
struct ThreadTag
enum StarCategory

// ❌ Bad
class forumsClient
struct threadTag
enum star_category
```

#### Methods and Properties

Use camelCase with descriptive names:

```swift
// ✅ Good
func listThreads(in forum: Forum, tagged threadTag: ThreadTag?, page: Int)
var isLoggedIn: Bool
var managedObjectContext: NSManagedObjectContext?

// ❌ Bad
func listThreads(forum: Forum, tag: ThreadTag?, p: Int)
var loggedIn: Bool
var moc: NSManagedObjectContext?
```

#### Constants

Use camelCase for constants:

```swift
// ✅ Good
private let defaultTimeout: TimeInterval = 30.0
static let maxRetryCount = 3

// ❌ Bad
private let DEFAULT_TIMEOUT: TimeInterval = 30.0
static let MAX_RETRY_COUNT = 3
```

#### Enums

Use PascalCase for enum names and camelCase for cases:

```swift
// ✅ Good
enum ThreadPage {
    case specific(Int)
    case nextUnread
    case last
}

// ❌ Bad
enum ThreadPage {
    case Specific(Int)
    case next_unread
    case LAST
}
```

### Code Formatting

#### Indentation

- Use 4 spaces for indentation (no tabs)
- Continuation lines should be indented by 4 additional spaces

#### Line Length

- Maximum line length: 120 characters
- Break long lines at natural boundaries

```swift
// ✅ Good
func processLongMethodName(
    with parameter: String,
    and anotherParameter: Int,
    completion: @escaping (Result<String, Error>) -> Void
) {
    // Implementation
}

// ❌ Bad
func processLongMethodName(with parameter: String, and anotherParameter: Int, completion: @escaping (Result<String, Error>) -> Void) {
    // Implementation
}
```

#### Braces

Always use braces for control statements, even single-line statements:

```swift
// ✅ Good
if condition {
    doSomething()
}

// ❌ Bad
if condition
    doSomething()
```

#### Spacing

Use spacing consistently:

```swift
// ✅ Good
let result = array.map { $0.uppercased() }
func method(parameter: String) -> Bool

// ❌ Bad
let result = array.map{ $0.uppercased() }
func method(parameter:String)->Bool
```

### Type Declarations

#### Optionals

Use explicit optional syntax:

```swift
// ✅ Good
var username: String?
var profileImage: UIImage?

// ❌ Bad
var username: String!
var profileImage: UIImage!
```

#### Implicit Returns

Use implicit returns for single-expression closures and computed properties:

```swift
// ✅ Good
var isValid: Bool {
    username != nil && password != nil
}

let filtered = items.filter { $0.isActive }

// ❌ Bad
var isValid: Bool {
    return username != nil && password != nil
}

let filtered = items.filter { item in
    return item.isActive
}
```

#### Type Inference

Leverage type inference when the type is obvious:

```swift
// ✅ Good
let themes = Theme.allThemes
let userID = "12345"

// ❌ Bad
let themes: [Theme] = Theme.allThemes
let userID: String = "12345"
```

### Access Control

Use the most restrictive access level possible:

```swift
// ✅ Good
public class ForumsClient {
    private let urlSession: URLSession
    internal var backgroundContext: NSManagedObjectContext?
    
    public func logIn(username: String, password: String) async throws -> User {
        // Implementation
    }
    
    private func setupURLSession() {
        // Implementation
    }
}

// ❌ Bad
public class ForumsClient {
    public let urlSession: URLSession
    public var backgroundContext: NSManagedObjectContext?
    
    public func logIn(username: String, password: String) async throws -> User {
        // Implementation
    }
    
    public func setupURLSession() {
        // Implementation
    }
}
```

### Property Wrappers

Use property wrappers for common patterns:

```swift
// ✅ Good - Settings
@FoilDefaultStorage(Settings.darkMode)
private var darkMode: Bool

@FoilDefaultStorage(Settings.username)
private var username: String?

// ✅ Good - UI Components
@IBOutlet private weak var tableView: UITableView!
@IBAction private func refreshButtonTapped(_ sender: UIBarButtonItem)
```

### Async/Await

Prefer async/await over completion handlers for new code:

```swift
// ✅ Good
func fetchThreads() async throws -> [AwfulThread] {
    let data = try await urlSession.data(from: url)
    return try parseThreads(from: data)
}

// ❌ Bad (for new code)
func fetchThreads(completion: @escaping (Result<[AwfulThread], Error>) -> Void) {
    urlSession.dataTask(with: url) { data, response, error in
        // Handle response
    }.resume()
}
```

### Error Handling

#### Custom Error Types

Define structured error types:

```swift
enum ForumsClientError: LocalizedError {
    case invalidCredentials
    case networkTimeout
    case parsingFailed(String)
    case serverError(code: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .networkTimeout:
            return "Network request timed out"
        case .parsingFailed(let details):
            return "Failed to parse response: \(details)"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        }
    }
}
```

#### Error Propagation

Use appropriate error handling patterns:

```swift
// ✅ Good - Propagate errors
func processRequest() async throws -> Result {
    let data = try await fetchData()
    return try parseResult(from: data)
}

// ✅ Good - Handle specific errors
func handleLogin() async {
    do {
        let user = try await forumsClient.logIn(username: username, password: password)
        await updateUI(for: user)
    } catch ForumsClientError.invalidCredentials {
        showErrorAlert("Please check your username and password")
    } catch {
        showErrorAlert("Login failed: \(error.localizedDescription)")
    }
}
```

### Memory Management

#### Weak References

Use weak references to avoid retain cycles:

```swift
// ✅ Good
class PostsViewController: UIViewController {
    private weak var delegate: PostsViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        forumsClient.didRemotelyLogOut = { [weak self] in
            self?.handleLogout()
        }
    }
}
```

#### Capture Lists

Use capture lists in closures:

```swift
// ✅ Good
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    self?.updateTimer()
}

// ❌ Bad
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    self.updateTimer() // Strong reference cycle
}
```

## Objective-C Style Guide

### Naming Conventions

#### Methods

Use descriptive method names:

```objc
// ✅ Good
- (void)scrollToPostWithID:(NSString *)postID animated:(BOOL)animated;
- (nullable NSString *)threadTagImageNameForThread:(AwfulThread *)thread;

// ❌ Bad
- (void)scroll:(NSString *)id:(BOOL)flag;
- (NSString *)tagName:(AwfulThread *)t;
```

#### Properties

Use descriptive property names:

```objc
// ✅ Good
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, readonly, getter=isLoggedIn) BOOL loggedIn;

// ❌ Bad
@property (nonatomic, copy) NSString *user;
@property (nonatomic, readonly) BOOL login;
```

#### Nullability

Always specify nullability:

```objc
// ✅ Good
@interface ForumsClient : NSObject

- (void)logInWithUsername:(NSString *)username
                 password:(NSString *)password
               completion:(void (^)(User * _Nullable user, NSError * _Nullable error))completion;

@property (nonatomic, strong, nullable) NSManagedObjectContext *managedObjectContext;

@end

// ❌ Bad
@interface ForumsClient : NSObject

- (void)logInWithUsername:(NSString *)username
                 password:(NSString *)password
               completion:(void (^)(User *user, NSError *error))completion;

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end
```

### Memory Management

Use ARC patterns consistently:

```objc
// ✅ Good
@property (nonatomic, weak) id<SomeDelegate> delegate;
@property (nonatomic, strong) NSArray<NSString *> *items;
@property (nonatomic, copy) NSString *title;

// Use weak for delegates and parents
@property (nonatomic, weak) UIViewController *parentViewController;
```

## File Organization

### File Naming

- Swift files: Use PascalCase matching the primary type
- Objective-C headers: Use PascalCase with `.h` extension
- Objective-C implementations: Use PascalCase with `.m` extension

```
// ✅ Good
ForumsClient.swift
ThreadTagButton.swift
MessageViewController.h
MessageViewController.m

// ❌ Bad
forums_client.swift
threadtagbutton.swift
messageVC.h
messageVC.m
```

### File Structure

#### Swift Files

Organize Swift files consistently:

```swift
//  FileName.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import UIKit
import AwfulCore

// MARK: - Main class/struct definition

public class SomeClass {
    // MARK: - Properties
    
    private let property1: String
    public var property2: Int
    
    // MARK: - Initialization
    
    public init(property1: String) {
        self.property1 = property1
    }
    
    // MARK: - Public methods
    
    public func publicMethod() {
        // Implementation
    }
    
    // MARK: - Private methods
    
    private func privateMethod() {
        // Implementation
    }
}

// MARK: - Extensions

extension SomeClass: SomeProtocol {
    func protocolMethod() {
        // Implementation
    }
}

// MARK: - Supporting types

private struct HelperStruct {
    // Implementation
}
```

#### Import Organization

Organize imports by framework:

```swift
// System frameworks first
import Foundation
import UIKit
import CoreData
import WebKit

// Third-party frameworks
import HTMLReader
import Nuke

// Internal frameworks
import AwfulCore
import AwfulSettings
import AwfulTheming
```

### Directory Structure

Follow the established project structure:

```
App/
├── View Controllers/
│   ├── Posts/
│   ├── Threads/
│   ├── Forums/
│   └── Messages/
├── Views/
├── Extensions/
├── Main/
└── Resources/

AwfulCore/
├── Sources/
│   └── AwfulCore/
│       ├── Model/
│       ├── Networking/
│       └── Data/
└── Tests/
```

## Documentation Standards

### Code Documentation

Use Swift documentation comments:

```swift
/// Logs into the Something Awful Forums with the provided credentials.
///
/// This method performs authentication with the SA Forums and establishes
/// a session that can be used for subsequent API calls.
///
/// - Parameters:
///   - username: The user's forum username
///   - password: The user's forum password
/// - Returns: A `User` object representing the logged-in user
/// - Throws: `ForumsClientError.invalidCredentials` if login fails
public func logIn(username: String, password: String) async throws -> User {
    // Implementation
}
```

### README Documentation

Each package should have a README.md:

```markdown
# Package Name

Brief description of what the package does.

## Usage

Basic usage examples:

```swift
let client = ForumsClient.shared
let user = try await client.logIn(username: "user", password: "pass")
```

## Architecture

Explanation of key components and design decisions.
```

### API Documentation

Document public APIs thoroughly:

```swift
/// A client for interacting with the Something Awful Forums.
///
/// `ForumsClient` provides methods for authentication, browsing forums,
/// reading and posting messages, and managing user preferences. It handles
/// HTML scraping, session management, and Core Data integration.
///
/// ## Usage
///
/// ```swift
/// let client = ForumsClient.shared
/// client.baseURL = URL(string: "https://forums.somethingawful.com")
/// client.managedObjectContext = dataStore.mainManagedObjectContext
///
/// // Login
/// let user = try await client.logIn(username: "username", password: "password")
///
/// // Browse forums
/// try await client.taxonomizeForums()
/// let threads = try await client.listThreads(in: forum, page: 1)
/// ```
public final class ForumsClient {
    // Implementation
}
```

## Error Handling

### Error Design

Design errors to be informative and actionable:

```swift
enum NetworkError: LocalizedError {
    case connectionFailed(underlying: Error)
    case invalidResponse(statusCode: Int)
    case timeout
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .invalidResponse(let statusCode):
            return "Server returned status code \(statusCode)"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request was cancelled"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .connectionFailed, .timeout:
            return "Please check your internet connection and try again."
        case .invalidResponse:
            return "The server may be experiencing issues. Please try again later."
        case .cancelled:
            return nil
        }
    }
}
```

### Error Handling Patterns

Use consistent error handling patterns:

```swift
// ✅ Good - Specific error handling
func handleNetworkRequest() async {
    do {
        let result = try await performRequest()
        processResult(result)
    } catch NetworkError.connectionFailed {
        showRetryAlert()
    } catch NetworkError.timeout {
        showTimeoutAlert()
    } catch {
        showGenericErrorAlert(error.localizedDescription)
    }
}

// ✅ Good - Error transformation
func transformError(_ error: Error) -> UserFacingError {
    switch error {
    case NetworkError.connectionFailed:
        return .noInternet
    case NetworkError.timeout:
        return .timeout
    case ForumsClientError.invalidCredentials:
        return .invalidLogin
    default:
        return .unknown(error.localizedDescription)
    }
}
```

## Testing Standards

### Unit Test Structure

Structure unit tests consistently:

```swift
class ForumsClientTests: XCTestCase {
    
    private var client: ForumsClient!
    private var mockSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        client = ForumsClient()
        mockSession = MockURLSession()
        // Setup
    }
    
    override func tearDown() {
        client = nil
        mockSession = nil
        super.tearDown()
    }
    
    // MARK: - Login Tests
    
    func testLoginWithValidCredentials() async throws {
        // Given
        let username = "testuser"
        let password = "testpass"
        mockSession.mockResponse(for: "login", data: validLoginData)
        
        // When
        let user = try await client.logIn(username: username, password: password)
        
        // Then
        XCTAssertEqual(user.username, username)
        XCTAssertTrue(client.isLoggedIn)
    }
    
    func testLoginWithInvalidCredentials() async {
        // Given
        let username = "baduser"
        let password = "badpass"
        mockSession.mockError(for: "login", error: ForumsClientError.invalidCredentials)
        
        // When/Then
        do {
            _ = try await client.logIn(username: username, password: password)
            XCTFail("Expected login to fail")
        } catch ForumsClientError.invalidCredentials {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
```

### Test Naming

Use descriptive test names:

```swift
// ✅ Good
func testLoginWithValidCredentialsReturnsUser()
func testLoginWithInvalidCredentialsThrowsError()
func testFetchThreadsWithValidForumReturnsThreads()
func testFetchThreadsWithInvalidForumThrowsError()

// ❌ Bad
func testLogin()
func testLogin2()
func testFetch()
func testError()
```

### Mock Objects

Create focused mock objects:

```swift
class MockForumsClient: ForumsClient {
    var mockThreads: [AwfulThread] = []
    var shouldThrowError = false
    var thrownError: Error = TestError.generic
    
    override func listThreads(in forum: Forum, tagged threadTag: ThreadTag?, page: Int) async throws -> [AwfulThread] {
        if shouldThrowError {
            throw thrownError
        }
        return mockThreads
    }
}
```

## Performance Guidelines

### Core Data

- Use background contexts for data import
- Batch operations when possible
- Use faulting appropriately

```swift
// ✅ Good - Background import
func importThreads(_ threadData: [ThreadData]) async throws {
    try await backgroundContext.perform {
        for data in threadData {
            _ = AwfulThread.upsert(data, in: self.backgroundContext)
        }
        try self.backgroundContext.save()
    }
}

// ✅ Good - Batch operations
func deleteOldThreads() throws {
    let request = NSBatchDeleteRequest(fetchRequest: AwfulThread.fetchRequest())
    request.predicate = NSPredicate(format: "lastPostDate < %@", cutoffDate as NSDate)
    try managedObjectContext.execute(request)
}
```

### Image Loading

Use Nuke for efficient image loading:

```swift
// ✅ Good
func loadAvatar(for user: User) {
    guard let url = user.profilePictureURL else {
        avatarImageView.image = defaultAvatarImage
        return
    }
    
    Nuke.loadImage(with: url, into: avatarImageView)
}
```

### Collection View Performance

Optimize collection view cells:

```swift
// ✅ Good
override func prepareForReuse() {
    super.prepareForReuse()
    
    // Cancel image loading
    Nuke.cancelRequest(for: imageView)
    
    // Reset to default state
    imageView.image = nil
    titleLabel.text = nil
}
```

## Security Best Practices

### Sensitive Data

Never hardcode sensitive data:

```swift
// ❌ Bad
let apiKey = "abc123secret"
let password = "mypassword"

// ✅ Good - Use configuration or keychain
let apiKey = Bundle.main.object(forInfoDictionaryKey: "APIKey") as? String
let password = Keychain.shared.password(for: account)
```

### URL Validation

Validate URLs from external sources:

```swift
func openURL(_ urlString: String) {
    guard let url = URL(string: urlString),
          url.scheme == "https" || url.scheme == "http",
          url.host == "forums.somethingawful.com" else {
        showErrorAlert("Invalid URL")
        return
    }
    
    UIApplication.shared.open(url)
}
```

### Input Validation

Validate all user input:

```swift
func validateUsername(_ username: String) -> Bool {
    let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmed.isEmpty && trimmed.count <= 255
}

func sanitizeHTML(_ html: String) -> String {
    // Remove dangerous HTML elements and attributes
    return html.replacingOccurrences(of: "<script", with: "&lt;script")
              .replacingOccurrences(of: "</script>", with: "&lt;/script&gt;")
}
```

These standards ensure consistent, maintainable, and secure code throughout the Awful.app project.