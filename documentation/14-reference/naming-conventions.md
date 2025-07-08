# Naming Conventions Reference

Comprehensive naming conventions for consistent code and resource naming throughout the Awful.app project.

## Table of Contents

- [Swift Naming Conventions](#swift-naming-conventions)
- [Objective-C Naming Conventions](#objective-c-naming-conventions)
- [File and Directory Naming](#file-and-directory-naming)
- [Resource Naming](#resource-naming)
- [API and Protocol Naming](#api-and-protocol-naming)
- [Database and Core Data Naming](#database-and-core-data-naming)
- [Configuration and Build Settings](#configuration-and-build-settings)
- [Documentation Naming](#documentation-naming)

## Swift Naming Conventions

### General Principles

1. **Clarity over brevity**: Names should be self-documenting
2. **Use terminology precisely**: Choose words that clearly convey meaning
3. **Avoid abbreviations**: Use full words unless the abbreviation is widely understood
4. **Follow grammatical conventions**: Use parts of speech appropriately

### Classes and Structs

Use **PascalCase** with descriptive nouns:

```swift
// ✅ Good
class ForumsClient
class ThreadsTableViewController
struct ThreadTag
struct UserProfile
class PostsPageViewController

// ❌ Bad
class forumsClient           // Wrong case
class ThreadsTVC            // Abbreviated
class client                // Too generic
class MyClass               // Non-descriptive prefix
```

#### Class Naming Patterns

**View Controllers:**
```swift
// Format: [Feature][Type]ViewController
PostsPageViewController      // Posts page view controller
ThreadsTableViewController   // Threads table view controller
ForumsTableViewController    // Forums table view controller
MessageComposeViewController // Message composition view controller
```

**Data Models:**
```swift
// Use descriptive nouns
User                        // Forum user
Forum                       // Forum section
AwfulThread                 // Thread (prefixed to avoid naming conflicts)
Post                        // Forum post
PrivateMessage              // Private message
Announcement                // Forum announcement
```

**Service Classes:**
```swift
// Format: [Domain][Purpose]
ForumsClient               // Main API client
ThemeManager               // Theme management
DataStore                  // Data persistence
ImageCache                 // Image caching
SettingsManager            // Settings management
```

### Methods and Functions

Use **camelCase** with verb phrases that describe the action:

```swift
// ✅ Good
func logIn(username: String, password: String) async throws -> User
func listThreads(in forum: Forum, tagged threadTag: ThreadTag?, page: Int) async throws -> [AwfulThread]
func setThread(_ thread: AwfulThread, isBookmarked: Bool) async throws
func markThreadAsSeenUpTo(_ post: Post) async throws

// ❌ Bad
func login(user: String, pass: String)     // Abbreviated parameters
func getThreads(forumID: String)           // Get prefix unnecessary in Swift
func bookmark(thread: AwfulThread, flag: Bool)  // Unclear boolean parameter
func mark(post: Post)                      // Unclear action
```

#### Method Naming Patterns

**Async methods:**
```swift
func fetchThreads() async throws -> [AwfulThread]
func uploadImage(_ image: UIImage) async throws -> URL
func sendPrivateMessage(to username: String) async throws
```

**Action methods:**
```swift
func refresh()
func loadMoreThreads()
func dismissModal()
func presentAlert(title: String, message: String)
```

**State query methods:**
```swift
func isLoggedIn() -> Bool
func canSendPrivateMessages() -> Bool
func hasUnreadPosts() -> Bool
```

**Configuration methods:**
```swift
func setupNavigationBar()
func configureCell(_ cell: UITableViewCell, with thread: AwfulThread)
func applyTheme(_ theme: Theme)
```

### Properties

Use **camelCase** with descriptive nouns:

```swift
// ✅ Good
var isLoggedIn: Bool
var managedObjectContext: NSManagedObjectContext?
var backgroundManagedObjectContext: NSManagedObjectContext?
var loginCookieExpiryDate: Date?
var didRemotelyLogOut: (() -> Void)?

// ❌ Bad
var loggedIn: Bool              // Missing "is" prefix for boolean
var moc: NSManagedObjectContext?  // Abbreviated
var context: NSManagedObjectContext?  // Too generic
var callback: (() -> Void)?    // Generic name
```

#### Property Naming Patterns

**Boolean Properties:**
```swift
// Use "is", "has", "can", "should", "will"
var isRefreshing: Bool
var hasUnreadPosts: Bool
var canPost: Bool
var shouldAutorefresh: Bool
var willAppearAnimated: Bool
```

**Collection Properties:**
```swift
// Use plural nouns
var threads: [AwfulThread]
var forums: [Forum]
var messages: [PrivateMessage]
var cachedImages: [URL: UIImage]
```

**Optional Properties:**
```swift
// Clear indication of optionality
var selectedThread: AwfulThread?
var currentUser: User?
var profileImage: UIImage?
```

### Constants

Use **camelCase** for constants:

```swift
// ✅ Good
private let defaultTimeout: TimeInterval = 30.0
static let maxRetryCount = 3
private let dateFormatter = DateFormatter()
let errorDomain = "AwfulErrorDomain"

// ❌ Bad
private let DEFAULT_TIMEOUT: TimeInterval = 30.0  // Wrong case
static let MAX_RETRY_COUNT = 3                    // Wrong case
private let DF = DateFormatter()                  // Abbreviated
```

#### Constant Naming Patterns

**Time intervals:**
```swift
private let refreshInterval: TimeInterval = 300.0
private let animationDuration: TimeInterval = 0.3
private let networkTimeout: TimeInterval = 30.0
```

**Keys and identifiers:**
```swift
private let cellReuseIdentifier = "ThreadCell"
private let segueIdentifier = "ShowPostsSegue"
private let notificationName = Notification.Name("ThemeDidChange")
```

### Enums

Use **PascalCase** for enum names and **camelCase** for cases:

```swift
// ✅ Good
enum ThreadPage {
    case specific(Int)
    case nextUnread
    case last
}

enum StarCategory: Int32 {
    case orange = 0
    case red = 1
    case yellow = 2
    case green = 3
    case blue = 4
    case purple = 5
}

enum NetworkError: Error {
    case connectionFailed
    case invalidResponse
    case timeout
    case cancelled
}

// ❌ Bad
enum ThreadPage {
    case Specific(Int)        // Wrong case
    case next_unread          // Wrong case
    case LAST                 // Wrong case
}
```

#### Enum Naming Patterns

**State enums:**
```swift
enum LoadingState {
    case idle
    case loading
    case loaded(data: [AwfulThread])
    case failed(error: Error)
}
```

**Configuration enums:**
```swift
enum DefaultBrowser: String, CaseIterable {
    case awful = "Awful"
    case defaultiOSBrowser = "Default iOS Browser"
    case chrome = "Chrome"
    case firefox = "Firefox"
}
```

### Protocols

Use **PascalCase** with descriptive names, often ending in "-ing" or "-able":

```swift
// ✅ Good
protocol Refreshable {
    func refresh() async throws
    var isRefreshing: Bool { get }
}

protocol ThemeProviding {
    func theme(for forumID: String) -> Theme
}

protocol PostsPageViewControllerDelegate: AnyObject {
    func postsViewController(_ controller: PostsPageViewController, didSelectPost post: Post)
}

// ❌ Bad
protocol RefreshProtocol { }        // Redundant "Protocol" suffix
protocol Refresh { }                // Too generic
protocol PostsDelegate { }          // Not specific enough
```

### Extensions

Name extension files descriptively:

```swift
// ✅ Good - File names
UIColor+Theme.swift
String+HTML.swift
ForumsClient+Search.swift
NSManagedObject+Utilities.swift

// Extension organization
extension UIColor {
    // MARK: - Theme Colors
    static func awfulOrange() -> UIColor { }
    static func threadTagColor(for tag: ThreadTag) -> UIColor { }
}

extension String {
    // MARK: - HTML Processing
    var strippingHTML: String { }
    var html_stringByUnescapingHTML: String { }
}
```

## Objective-C Naming Conventions

### Classes and Categories

Use **PascalCase** with clear prefixes when necessary:

```objc
// ✅ Good
@interface SmilieDataStore : NSObject
@interface SmilieKeyboard : UIInputView
@interface MessageViewController : UIViewController

// Categories
@interface NSString (HTMLProcessing)
@interface UIImage (Theming)

// ❌ Bad
@interface SmilieDS : NSObject           // Abbreviated
@interface smilieKeyboard : UIInputView  // Wrong case
@interface MsgVC : UIViewController      // Abbreviated
```

### Methods

Use descriptive method names following Cocoa conventions:

```objc
// ✅ Good
- (void)scrollToPostWithID:(NSString *)postID animated:(BOOL)animated;
- (nullable NSString *)threadTagImageNameForThread:(AwfulThread *)thread;
- (void)configureCell:(UITableViewCell *)cell withThread:(AwfulThread *)thread;

// ❌ Bad
- (void)scroll:(NSString *)id:(BOOL)flag;
- (NSString *)tagName:(AwfulThread *)t;
- (void)setup:(UITableViewCell *)c:(AwfulThread *)t;
```

### Properties

Use descriptive property names with appropriate attributes:

```objc
// ✅ Good
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, strong, nullable) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly, getter=isLoggedIn) BOOL loggedIn;
@property (nonatomic, weak, nullable) id<SmilieKeyboardDelegate> delegate;

// ❌ Bad
@property NSString *user;                // Missing attributes and too generic
@property NSManagedObjectContext *moc;   // Abbreviated
@property BOOL login;                    // Not descriptive
```

### Constants

Use descriptive constant names:

```objc
// ✅ Good
static NSString * const SmilieDataStoreDidUpdateNotification = @"SmilieDataStoreDidUpdate";
static const NSTimeInterval SmilieDownloadTimeout = 30.0;
static NSString * const SmilieCellReuseIdentifier = @"SmilieCell";

// ❌ Bad
static NSString * const kNotification = @"Update";  // Too generic
static const NSTimeInterval kTimeout = 30.0;       // Abbreviated
```

## File and Directory Naming

### Swift Files

Name files after the primary type they contain:

```
// ✅ Good
ForumsClient.swift
ThreadsTableViewController.swift
PostsPageViewController.swift
Theme.swift
Settings.swift

// ❌ Bad
client.swift              // Too generic
ThreadsTVC.swift          // Abbreviated
posts.swift               // Too generic
utils.swift               // Too generic
```

### Objective-C Files

Use matching header and implementation file names:

```
// ✅ Good
SmilieDataStore.h / SmilieDataStore.m
MessageViewController.h / MessageViewController.m
RenderView.h / RenderView.m

// ❌ Bad
SmilieDS.h / SmilieDS.m              // Abbreviated
MsgViewController.h / MsgViewController.m  // Mixed naming
```

### Extension Files

Use descriptive names that indicate the extended type and purpose:

```
// ✅ Good
UIColor+Theme.swift
String+HTML.swift
NSManagedObject+Utilities.swift
ForumsClient+Search.swift

// ❌ Bad
Extensions.swift          // Too generic
UIColorExt.swift         // Non-standard abbreviation
StringUtils.swift        // Different naming pattern
```

### Directory Names

Use **PascalCase** for code directories and **lowercase-with-hyphens** for configuration:

```
// ✅ Good - Code directories
View Controllers/
Data Sources/
Extensions/
Resources/

// ✅ Good - Configuration directories
build-scripts/
documentation/
config/

// ❌ Bad
view_controllers/        // Wrong case for code
ViewControllers/         // Missing space
RESOURCES/               // All caps
```

## Resource Naming

### Asset Catalogs

Use descriptive names for asset catalogs:

```
// ✅ Good
Assets.xcassets
AppIcons.xcassets
ThreadTags.xcassets

// ❌ Bad
images.xcassets          // Too generic
assets1.xcassets         // Numbered
```

### Image Assets

Use descriptive names with appropriate suffixes:

```
// ✅ Good
thread-tag-announcement
thread-tag-gaming
avatar-placeholder
refresh-arrow
loading-spinner

// ❌ Bad
img1                     // Non-descriptive
threadTag               // Inconsistent case
avatar_placeholder      // Mixed separators
```

### Storyboards and XIBs

Name based on their purpose:

```
// ✅ Good
Main.storyboard
Login.storyboard
PostsPageSettings.xib
InAppActionSheet.xib

// ❌ Bad
Interface.storyboard     // Too generic
UI.storyboard           // Abbreviated
Settings.xib            // Too generic
```

### Localization Files

Use standard localization naming:

```
// ✅ Good
Localizable.xcstrings
InfoPlist.xcstrings
PackageName.xcstrings

// ❌ Bad
strings.xcstrings        // Too generic
text.xcstrings          // Not descriptive
```

## API and Protocol Naming

### Protocol Names

Use descriptive names that clearly indicate the protocol's purpose:

```swift
// ✅ Good
protocol ThreadsTableViewControllerDelegate: AnyObject {
    func threadsViewController(_ controller: ThreadsTableViewController, didSelectThread thread: AwfulThread)
}

protocol Refreshable {
    func refresh() async throws
    var isRefreshing: Bool { get }
}

protocol ThemeProviding {
    func currentTheme(for forumID: String) -> Theme
}

// ❌ Bad
protocol ThreadsDelegate { }         // Too generic
protocol RefreshProtocol { }         // Redundant suffix
protocol Themeable { }               // Not clear what it provides
```

### Delegate Method Names

Follow Cocoa conventions for delegate methods:

```swift
// ✅ Good
func postsViewController(_ controller: PostsPageViewController, didSelectPost post: Post)
func postsViewController(_ controller: PostsPageViewController, willLoadPage page: ThreadPage)
func postsViewControllerDidFinishLoading(_ controller: PostsPageViewController)

// ❌ Bad
func postSelected(_ post: Post)                    // Missing controller parameter
func postsViewController(_ controller: PostsPageViewController, post: Post)  // Unclear action
func didSelectPost(_ post: Post, in controller: PostsPageViewController)     // Wrong parameter order
```

### Completion Handler Parameters

Use descriptive parameter names:

```swift
// ✅ Good
func fetchThreads(completion: @escaping (Result<[AwfulThread], Error>) -> Void)
func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void)
func authenticateUser(completion: @escaping (User?, Error?) -> Void)

// ❌ Bad
func fetchThreads(completion: @escaping (Result<[AwfulThread], Error>) -> Void)  // Same as good
func loadImage(from url: URL, callback: @escaping (UIImage?) -> Void)           // Less standard naming
func authenticateUser(done: @escaping (User?, Error?) -> Void)                  // Non-standard naming
```

## Database and Core Data Naming

### Entity Names

Use singular, descriptive nouns:

```
// ✅ Good
User
Forum
AwfulThread    // Prefixed to avoid conflicts
Post
PrivateMessage
ThreadTag
Announcement

// ❌ Bad
Users          // Plural
thread         // Wrong case
PM             // Abbreviated
msg            // Abbreviated
```

### Attribute Names

Use camelCase with descriptive names:

```
// ✅ Good
// User entity
userID
username
customTitleHTML
regdate
profilePictureURL

// Thread entity
threadID
title
totalReplies
lastPostDate
bookmarked

// ❌ Bad
id             // Too generic
user_id        // Wrong case
replies        // Not specific enough
date           // Too generic
```

### Relationship Names

Use descriptive names that indicate the relationship:

```
// ✅ Good
// User relationships
posts          // One user to many posts
threads        // One user to many threads

// Forum relationships
threads        // One forum to many threads
parentForum    // Many forums to one parent
childForums    // One forum to many children

// Thread relationships
posts          // One thread to many posts
author         // Many threads to one author
forum          // Many threads to one forum

// ❌ Bad
items          // Too generic
parent         // Not specific enough
children       // Not specific enough
```

### Core Data Model Versions

Use descriptive version names:

```
// ✅ Good
AwfulModel.xcdatamodeld
├── AwfulModel 2.xcdatamodel     // Version 2
├── AwfulModel 3.xcdatamodel     // Version 3 (current)
└── AwfulModel.xcdatamodel       // Version 1

// ❌ Bad
Model.xcdatamodeld               // Too generic
AwfulDB.xcdatamodeld            // Different naming pattern
```

## Configuration and Build Settings

### Build Configuration Files

Use descriptive names with clear hierarchy:

```
// ✅ Good
Common.xcconfig
Common-Debug.xcconfig
Common-Release.xcconfig
Awful-Debug.xcconfig
Awful-Release.xcconfig

// ❌ Bad
config.xcconfig          // Too generic
debug.xcconfig          // Missing scope
app.xcconfig            // Too generic
```

### Build Setting Names

Use descriptive names following Xcode conventions:

```
// ✅ Good
MARKETING_VERSION = 7.9
CURRENT_PROJECT_VERSION = 70900
SWIFT_VERSION = 5.0
IPHONEOS_DEPLOYMENT_TARGET = 15.0

// Custom settings
AWFUL_BASE_URL = https://forums.somethingawful.com
AWFUL_API_VERSION = 1.0
```

### Scheme Names

Use clear, descriptive scheme names:

```
// ✅ Good
Awful                    // Main app scheme
Smilie Keyboard         // Keyboard extension
SmilieExtractor         // Utility app
Awful Tests             // Test scheme

// ❌ Bad
App                     // Too generic
Test                    // Too generic
Debug                   // Not descriptive
```

### Target Names

Use descriptive target names:

```
// ✅ Good
Awful                   // Main iOS app
SmilieKeyboard         // Keyboard extension
SmiliesStickers        // Sticker pack
AwfulTests             // Unit tests
AwfulUITests           // UI tests

// ❌ Bad
App                    // Too generic
Extension              // Too generic
Tests                  // Too generic
```

## Documentation Naming

### Documentation Files

Use clear, descriptive names:

```
// ✅ Good
README.md
CONTRIBUTING.md
CLAUDE.md
api-reference.md
architecture-patterns.md
migration-guide.md

// ❌ Bad
docs.md                // Too generic
guide.md               // Not specific
info.md                // Too generic
```

### Documentation Sections

Use descriptive headers and filenames:

```
// ✅ Good
01-getting-started/
02-architecture/
03-core-systems/
04-user-flows/
14-reference/

// Within files
# Authentication System
## Login Flow
### Password Validation

// ❌ Bad
docs/                  // Too generic
misc/                  // Not descriptive
stuff/                 // Too generic

# System
## Flow
### Validation         // Not specific enough
```

### Code Comments

Use clear, descriptive comments:

```swift
// ✅ Good
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

// MARK: - Authentication Methods

// TODO: Add support for two-factor authentication
// FIXME: Handle edge case where session expires during request

// ❌ Bad
/// Login method
/// - Parameter user: user
/// - Parameter pass: pass

// TODO: Fix this
// HACK: Temporary workaround
```

### Commit Messages

Use clear, descriptive commit messages:

```
// ✅ Good
Add support for forum search functionality
Fix crash when loading posts without internet connection
Update theme system to support dark mode
Refactor Core Data stack for better performance

// ❌ Bad
Fix bug                // Not descriptive
Update code            // Too generic
WIP                    // Not meaningful for history
asdf                   // Nonsensical
```

These naming conventions ensure consistency, clarity, and maintainability throughout the Awful.app codebase, making it easier for developers to understand and work with the code.