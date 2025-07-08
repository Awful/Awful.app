# API Reference

Comprehensive documentation for Awful.app's APIs, classes, methods, and protocols.

## Table of Contents

- [Core APIs](#core-apis)
  - [ForumsClient](#forumsclient)
  - [DataStore](#datastore)
  - [Model Objects](#model-objects)
- [Theming System](#theming-system)
  - [Theme Class](#theme-class)
  - [Theme Protocol](#theme-protocol)
- [Settings System](#settings-system)
  - [Settings Enum](#settings-enum)
  - [FoilDefaultStorage](#foildefaultstorage)
- [UI Components](#ui-components)
  - [View Controllers](#view-controllers)
  - [Custom Views](#custom-views)
- [Extensions](#extensions)
  - [UIKit Extensions](#uikit-extensions)
  - [Foundation Extensions](#foundation-extensions)

## Core APIs

### ForumsClient

The main networking and scraping client for Something Awful Forums.

#### Class Definition

```swift
public final class ForumsClient {
    /// Convenient singleton
    public static let shared = ForumsClient()
    
    /// The Forums endpoint for the client
    public var baseURL: URL?
    
    /// A managed object context into which data is imported
    public var managedObjectContext: NSManagedObjectContext?
    
    /// Whether or not a valid, logged-in session exists
    public var isLoggedIn: Bool
    
    /// When the valid, logged-in session expires
    public var loginCookieExpiryDate: Date?
    
    /// Block to call when the login session is destroyed remotely
    public var didRemotelyLogOut: (() -> Void)?
}
```

#### Authentication Methods

##### `logIn(username:password:)`

Logs into the Something Awful Forums.

```swift
public func logIn(
    username: String,
    password: String
) async throws -> User
```

**Parameters:**
- `username`: The user's forum username
- `password`: The user's forum password

**Returns:** `User` object representing the logged-in user

**Throws:** 
- `ForumsClient.Error.missingManagedObjectContext` if no Core Data context is set
- Network-related errors
- Parsing errors if the response format is unexpected

#### Forum Navigation Methods

##### `taxonomizeForums()`

Fetches and updates the forum hierarchy.

```swift
public func taxonomizeForums() async throws
```

**Throws:**
- `ForumsClient.Error.missingManagedObjectContext` if no Core Data context is set
- Network-related errors

##### `listThreads(in:tagged:page:)`

Lists threads in a specific forum.

```swift
public func listThreads(
    in forum: Forum,
    tagged threadTag: ThreadTag? = nil,
    page: Int
) async throws -> [AwfulThread]
```

**Parameters:**
- `forum`: The forum to list threads from
- `threadTag`: Optional thread tag to filter by
- `page`: Page number to fetch

**Returns:** Array of `AwfulThread` objects

#### Search Methods

##### `fetchSearchPage()`

Fetches the initial search page form.

```swift
public func fetchSearchPage() async throws -> HTMLDocument
```

**Returns:** HTMLDocument containing the search form

##### `searchForums(query:forumIDs:)`

Performs a forum search with the given query.

```swift
public func searchForums(
    query: String,
    forumIDs: [String]
) async throws -> HTMLDocument
```

**Parameters:**
- `query`: The search query string
- `forumIDs`: Array of forum ID strings to search within

**Returns:** HTMLDocument containing search results

#### Thread Methods

##### `listBookmarkedThreads(page:)`

Lists the user's bookmarked threads.

```swift
public func listBookmarkedThreads(
    page: Int
) async throws -> [AwfulThread]
```

**Parameters:**
- `page`: Page number to fetch

**Returns:** Array of bookmarked `AwfulThread` objects

##### `setThread(_:isBookmarked:)`

Adds or removes a thread from bookmarks.

```swift
public func setThread(
    _ thread: AwfulThread,
    isBookmarked: Bool
) async throws
```

**Parameters:**
- `thread`: The thread to bookmark/unbookmark
- `isBookmarked`: Whether to bookmark or remove bookmark

##### `rate(_:as:)`

Rates a thread (1-5 stars).

```swift
public func rate(
    _ thread: AwfulThread,
    as rating: Int
) async throws
```

**Parameters:**
- `thread`: The thread to rate
- `rating`: Rating value (1-5, will be clamped)

#### Post Methods

##### `listPosts(in:writtenBy:page:updateLastReadPost:)`

Lists posts in a thread.

```swift
public func listPosts(
    in thread: AwfulThread,
    writtenBy author: User?,
    page: ThreadPage,
    updateLastReadPost: Bool
) async throws -> (posts: [Post], firstUnreadPost: Int?, advertisementHTML: String)
```

**Parameters:**
- `thread`: The thread to load posts from
- `author`: Optional user to filter posts by
- `page`: Which page to load (.nextUnread, .last, .specific(Int))
- `updateLastReadPost`: Whether to mark posts as read

**Returns:** Tuple containing:
- `posts`: Array of `Post` objects
- `firstUnreadPost`: Index of first unread post (1-based)
- `advertisementHTML`: Raw HTML for ads

##### `reply(to:bbcode:)`

Posts a reply to a thread.

```swift
public func reply(
    to thread: AwfulThread,
    bbcode: String
) async throws -> ReplyLocation
```

**Parameters:**
- `thread`: The thread to reply to
- `bbcode`: The post content in BBCode format

**Returns:** `ReplyLocation` indicating where the reply was posted

##### `previewReply(to:bbcode:)`

Previews a reply without posting it.

```swift
public func previewReply(
    to thread: AwfulThread,
    bbcode: String
) async throws -> String
```

**Parameters:**
- `thread`: The thread being replied to
- `bbcode`: The post content in BBCode format

**Returns:** HTML string of the previewed post

#### Private Message Methods

##### `listPrivateMessagesInInbox()`

Lists private messages in the user's inbox.

```swift
public func listPrivateMessagesInInbox() async throws -> [PrivateMessage]
```

**Returns:** Array of `PrivateMessage` objects

##### `sendPrivateMessage(to:subject:threadTag:bbcode:about:)`

Sends a private message.

```swift
public func sendPrivateMessage(
    to username: String,
    subject: String,
    threadTag: ThreadTag?,
    bbcode: String,
    about relevantMessage: RelevantMessage
) async throws
```

**Parameters:**
- `username`: Recipient's username
- `subject`: Message subject
- `threadTag`: Optional thread tag/icon
- `bbcode`: Message content in BBCode format
- `relevantMessage`: Context for replies/forwards

#### User Profile Methods

##### `profileLoggedInUser()`

Fetches the current user's profile.

```swift
public func profileLoggedInUser() async throws -> User
```

**Returns:** `User` object for the logged-in user

##### `profileUser(_:)`

Fetches another user's profile.

```swift
public func profileUser(
    _ request: UserProfileSearchRequest
) async throws -> Profile
```

**Parameters:**
- `request`: Either `.userID(String)` or `.username(String)`

**Returns:** `Profile` object for the requested user

#### Error Types

```swift
enum Error: Swift.Error {
    case failedTransferToMainContext
    case missingURLSession
    case invalidBaseURL
    case missingDataAndError
    case missingManagedObjectContext
    case requestSerializationError(String)
    case unexpectedContentType(String, expected: String)
}
```

### DataStore

Core Data stack management for persistent storage.

#### Class Definition

```swift
public class DataStore {
    /// Shared instance
    public static let shared = DataStore()
    
    /// Main managed object context (UI thread)
    public var mainManagedObjectContext: NSManagedObjectContext
    
    /// Background managed object context (background thread)
    public var backgroundManagedObjectContext: NSManagedObjectContext
    
    /// Persistent store coordinator
    public var persistentStoreCoordinator: NSPersistentStoreCoordinator
}
```

#### Methods

##### `save()`

Saves changes to the persistent store.

```swift
public func save() throws
```

##### `performBackgroundTask(_:)`

Performs a task on the background context.

```swift
public func performBackgroundTask<T>(
    _ block: @escaping (NSManagedObjectContext) throws -> T
) async throws -> T
```

### Model Objects

Core Data model objects representing forum entities.

#### User

Represents a forum user.

```swift
@objc(User)
public class User: AwfulManagedObject {
    @NSManaged public var userID: String
    @NSManaged public var username: String?
    @NSManaged public var customTitleHTML: String?
    @NSManaged public var regdate: Date?
    @NSManaged public var canReceivePrivateMessages: Bool
    @NSManaged public var profilePictureURL: URL?
}
```

#### Forum

Represents a forum section.

```swift
@objc(Forum)
public class Forum: AwfulManagedObject {
    @NSManaged public var forumID: String
    @NSManaged public var name: String?
    @NSManaged public var index: Int32
    @NSManaged public var canPost: Bool
    @NSManaged public var lastRefresh: Date?
    @NSManaged public var parentForum: Forum?
    @NSManaged public var childForums: Set<Forum>
    @NSManaged public var threads: Set<AwfulThread>
}
```

#### AwfulThread

Represents a forum thread.

```swift
@objc(AwfulThread)
public class AwfulThread: AwfulManagedObject {
    @NSManaged public var threadID: String
    @NSManaged public var title: String?
    @NSManaged public var numberOfPages: Int32
    @NSManaged public var totalReplies: Int32
    @NSManaged public var bookmarked: Bool
    @NSManaged public var closed: Bool
    @NSManaged public var sticky: Bool
    @NSManaged public var lastPostDate: Date?
    @NSManaged public var seenPosts: Int32
    @NSManaged public var starCategory: StarCategory
    @NSManaged public var threadTag: ThreadTag?
    @NSManaged public var secondaryThreadTag: ThreadTag?
    @NSManaged public var author: User?
    @NSManaged public var forum: Forum?
    @NSManaged public var posts: Set<Post>
}
```

#### Post

Represents a forum post.

```swift
@objc(Post)
public class Post: AwfulManagedObject {
    @NSManaged public var postID: String
    @NSManaged public var innerHTML: String?
    @NSManaged public var postDate: Date?
    @NSManaged public var threadIndex: Int32
    @NSManaged public var beenSeen: Bool
    @NSManaged public var ignored: Bool
    @NSManaged public var author: User?
    @NSManaged public var thread: AwfulThread?
}
```

## Theming System

### Theme Class

Main theming class that provides colors, fonts, and styling.

#### Class Definition

```swift
public class Theme {
    public let name: String
    
    /// The descriptive name of the theme
    public var descriptiveName: String
    
    /// Whether the theme uses rounded fonts
    public var roundedFonts: Bool
    
    /// Keyboard appearance for the theme
    public var keyboardAppearance: UIKeyboardAppearance
    
    /// Scroll indicator style for the theme
    public var scrollIndicatorStyle: UIScrollView.IndicatorStyle
}
```

#### Color Access

Themes provide colors through subscript access:

```swift
// Access colors (Color suffix is optional)
let backgroundColor = theme["background"]
let textColor = theme[uicolor: "text"]
let swiftUIColor = theme[color: "accent"]
```

#### Static Methods

##### `theme(named:)`

Gets a theme by name.

```swift
public static func theme(named themeName: String) -> Theme?
```

##### `defaultTheme(mode:)`

Gets the default theme for a mode.

```swift
public static func defaultTheme(mode: Mode? = nil) -> Theme
```

##### `currentTheme(for:mode:)`

Gets the current theme for a forum.

```swift
public static func currentTheme(for forumID: ForumID, mode: Mode? = nil) -> Theme
```

##### `setThemeName(_:forForumIdentifiedBy:modes:)`

Sets a theme for specific forums and modes.

```swift
public static func setThemeName(
    _ themeName: String?,
    forForumIdentifiedBy forumID: String,
    modes: Set<Mode>
)
```

#### Mode Enumeration

```swift
public enum Mode: CaseIterable, Hashable {
    case light, dark
    
    public var localizedDescription: String
}
```

### CSS Integration

Themes can reference CSS files:

```swift
let cssContent = theme["postsViewCSS"] // Returns CSS file contents
```

## Settings System

### Settings Enum

Centralized settings management using strongly-typed keys.

#### Class Definition

```swift
public enum Settings {
    // App appearance
    public static let autoDarkTheme = Setting(key: "auto_dark_theme", default: true)
    public static let darkMode = Setting(key: "dark_theme", default: false)
    public static let defaultBrowser = Setting(key: "default_browser", default: DefaultBrowser.default)
    
    // Post display
    public static let loadImages = Setting(key: "show_images", default: true)
    public static let showAvatars = Setting(key: "show_avatars", default: true)
    public static let fontScale = Setting(key: "font_scale", default: 100.0)
    public static let autoplayGIFs = Setting(key: "autoplay_gifs", default: false)
    
    // Thread behavior
    public static let pullForNext = Setting(key: "pull_for_next", default: true)
    public static let jumpToPostEndOnDoubleTap = Setting(key: "jump_to_post_end_on_double_tap", default: false)
    public static let confirmBeforeReplying = Setting(key: "confirm_before_replying", default: true)
    
    // Privacy
    public static let clipboardURLEnabled = Setting(key: "clipboard_url_enabled", default: false)
    public static let handoffEnabled = Setting(key: "handoff_enabled", default: false)
}
```

#### Setting Definition

```swift
public struct Setting<Value> {
    public let key: String
    public let defaultValue: Value?
    
    public init(key: String, default defaultValue: Value)
    public init(key: String) // For optional values
}
```

### FoilDefaultStorage

Property wrapper for accessing UserDefaults with type safety.

#### Usage

```swift
@FoilDefaultStorage(Settings.darkMode)
private var darkMode: Bool

@FoilDefaultStorage(Settings.username)
private var username: String?
```

#### Definition

```swift
@propertyWrapper
public struct FoilDefaultStorage<Value> {
    private let setting: Setting<Value>
    
    public init(_ setting: Setting<Value>)
    
    public var wrappedValue: Value {
        get { /* UserDefaults access */ }
        set { /* UserDefaults storage */ }
    }
}
```

## UI Components

### View Controllers

#### PostsPageViewController

Main view controller for displaying thread posts.

```swift
class PostsPageViewController: UIViewController {
    /// The thread being displayed
    var thread: AwfulThread?
    
    /// Current page being displayed
    var page: ThreadPage = .specific(1)
    
    /// Web view for rendering posts
    @IBOutlet var renderView: RenderView!
    
    /// Navigation to specific page
    func goToPage(_ page: ThreadPage)
    
    /// Jump to specific post
    func jumpToPost(identifiedBy postID: String)
    
    /// Refresh current page
    func refresh()
}
```

#### ThreadsTableViewController

Table view controller for displaying thread lists.

```swift
class ThreadsTableViewController: UITableViewController {
    /// The forum whose threads are displayed
    var forum: Forum?
    
    /// Optional thread tag filter
    var threadTag: ThreadTag?
    
    /// Fetched results controller for threads
    var fetchedResultsController: NSFetchedResultsController<AwfulThread>!
    
    /// Load next page of threads
    func loadNextPage()
    
    /// Refresh thread list
    func refresh()
}
```

#### ForumsTableViewController

Table view controller for displaying forum hierarchy.

```swift
class ForumsTableViewController: UITableViewController {
    /// Fetched results controller for forums
    var fetchedResultsController: NSFetchedResultsController<Forum>!
    
    /// Currently selected forum
    var selectedForum: Forum?
    
    /// Refresh forum list
    func refresh()
}
```

### Custom Views

#### RenderView

Web view for rendering forum posts with custom styling.

```swift
class RenderView: WKWebView {
    /// Current theme being used
    var theme: Theme?
    
    /// Current font scale
    var fontScale: Double = 1.0
    
    /// Load posts HTML with theme
    func render(posts: [Post], theme: Theme)
    
    /// Jump to specific post
    func jumpToElementWithID(_ elementID: String)
    
    /// Get current scroll position
    var fractionalContentOffset: Double
}
```

#### ThreadTagButton

Button for displaying and selecting thread tags.

```swift
class ThreadTagButton: UIButton {
    /// The thread tag being displayed
    var threadTag: ThreadTag? {
        didSet { updateAppearance() }
    }
    
    /// Empty state display
    var emptyView: UIView?
    
    /// Update button appearance based on tag
    private func updateAppearance()
}
```

## Extensions

### UIKit Extensions

#### UIColor Extensions

```swift
extension UIColor {
    /// Initialize from hex string
    convenience init?(hex: String)
    
    /// Convert to hex string
    var hexString: String
    
    /// Get contrasting text color
    var contrastingTextColor: UIColor
}
```

#### UIViewController Extensions

```swift
extension UIViewController {
    /// Present alert with title and message
    func presentAlert(title: String, message: String)
    
    /// Present action sheet with options
    func presentActionSheet(
        title: String?,
        message: String?,
        actions: [UIAlertAction],
        sourceView: UIView?
    )
    
    /// Show loading indicator
    func showLoadingIndicator()
    
    /// Hide loading indicator
    func hideLoadingIndicator()
}
```

#### UITableView Extensions

```swift
extension UITableView {
    /// Dequeue reusable cell with type safety
    func dequeueReusableCell<T: UITableViewCell>(
        ofType type: T.Type,
        for indexPath: IndexPath
    ) -> T
    
    /// Register cell class
    func register<T: UITableViewCell>(_ type: T.Type)
    
    /// Scroll to bottom
    func scrollToBottom(animated: Bool = true)
}
```

### Foundation Extensions

#### String Extensions

```swift
extension String {
    /// Remove HTML tags
    var strippingHTML: String
    
    /// Convert HTML entities to characters
    var html_stringByUnescapingHTML: String
    
    /// Validate as email address
    var isValidEmail: Bool
    
    /// Truncate to length with ellipsis
    func truncated(to length: Int, trailing: String = "...") -> String
}
```

#### URL Extensions

```swift
extension URL {
    /// Check if URL opens in supported browser
    var opensInBrowser: Bool
    
    /// Extract query parameters
    var queryParameters: [String: String]
    
    /// Add query parameters
    func appendingQueryParameters(_ parameters: [String: String]) -> URL
}
```

#### UserDefaults Extensions

```swift
extension UserDefaults {
    /// Type-safe setting access
    subscript<T>(setting: Setting<T>) -> T? {
        get { /* Get value for setting */ }
        set { /* Set value for setting */ }
    }
    
    /// Register default values for all settings
    static func registerAwfulDefaults()
}
```

## Protocols

### Theming Protocol

```swift
protocol Theming {
    /// Apply theme to the object
    func apply(theme: Theme)
    
    /// Update for theme changes
    func themeDidChange()
}
```

### Refreshable Protocol

```swift
protocol Refreshable {
    /// Whether refresh is currently in progress
    var isRefreshing: Bool { get }
    
    /// Perform refresh operation
    func refresh() async throws
    
    /// Cancel ongoing refresh
    func cancelRefresh()
}
```

### NavigationItem Protocol

```swift
protocol NavigationItem {
    /// Title for navigation
    var navigationTitle: String { get }
    
    /// Subtitle for navigation
    var navigationSubtitle: String? { get }
    
    /// Navigation bar buttons
    var navigationBarButtons: [UIBarButtonItem] { get }
}
```

## Constants

### Notification Names

```swift
extension Notification.Name {
    /// Posted when theme changes for a forum
    static let themeForForumDidChange = Notification.Name("Awful theme for forum did change")
    
    /// Posted when settings change
    static let settingsDidChange = Notification.Name("Awful settings did change")
    
    /// Posted when login state changes
    static let loginStateDidChange = Notification.Name("Awful login state did change")
}
```

### User Defaults Keys

```swift
struct UserDefaultsKeys {
    static let themeLightPrefix = "theme-light-"
    static let themeDarkPrefix = "theme-dark-"
    static let lastRefreshDate = "last_refresh_date"
    static let fontSize = "font_size"
}
```

### Error Domains

```swift
struct AwfulErrorDomain {
    static let core = "AwfulCoreErrorDomain"
    static let scraping = "AwfulScrapingErrorDomain"
    static let networking = "AwfulNetworkingErrorDomain"
}
```

This API reference provides comprehensive documentation for all major components of the Awful.app codebase, including classes, methods, protocols, and extensions that developers need to understand when working with the application.