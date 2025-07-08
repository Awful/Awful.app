# Module Structure

## Overview

This document describes the modular architecture of the Awful app, covering the organization of code into logical modules and the dependencies between them.

## High-Level Module Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                            Awful App                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   UI Modules    │  │  Feature Modules│  │  Core Modules   │  │
│  │                 │  │                 │  │                 │  │
│  │ • View Controllers │ • Forums       │  │ • AwfulCore     │  │
│  │ • SwiftUI Views │  │ • Threads      │  │ • Networking    │  │
│  │ • Custom Views  │  │ • Posts        │  │ • Persistence   │  │
│  │ • Navigation    │  │ • Messages     │  │ • Theming       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Support Modules │  │ Extension Modules│  │ Vendor Modules  │  │
│  │                 │  │                 │  │                 │  │
│  │ • Settings      │  │ • Smilies       │  │ • HTMLReader    │  │
│  │ • Utilities     │  │ • Share Extension│  │ • Nuke         │  │
│  │ • Resources     │  │ • Keyboard Ext. │  │ • Lottie       │  │
│  │ • Testing       │  │                 │  │                 │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Core Modules

### AwfulCore
**Location**: `AwfulCore/`
**Purpose**: Core business logic and data management

#### Components
- **ForumsClient**: Network client for Something Awful forums
- **Core Data Models**: Thread, Post, Forum, User entities
- **HTML Parsing**: Scraping logic for forum content
- **Data Managers**: High-level data operations

#### Dependencies
```swift
// Internal dependencies
import Foundation
import CoreData
import HTMLReader

// Public interface
public class ForumsClient {
    public static let shared = ForumsClient()
    public func loadForums() async throws -> [Forum]
    public func loadThreads(for forum: Forum) async throws -> [Thread]
    public func loadPosts(for thread: Thread, page: Int) async throws -> [Post]
}
```

#### Key Files
- `ForumsClient.swift`: Main API client
- `CoreDataStack.swift`: Core Data setup
- `HTMLScraper.swift`: HTML parsing logic
- `Models/`: Core Data entity extensions

### AwfulSettings
**Location**: `AwfulSettings/`
**Purpose**: User preferences and configuration

#### Components
- **Settings Manager**: Centralized settings access
- **UserDefaults Wrappers**: Type-safe property wrappers
- **Migration Logic**: Settings migration between versions

#### Example
```swift
// Settings property wrapper
@FoilDefaultStorage(key: "showAvatars", defaultValue: true)
public var showAvatars: Bool

// Usage
if AwfulSettings.showAvatars {
    // Show avatars
}
```

### AwfulTheming
**Location**: `AwfulTheming/`
**Purpose**: Theme management and styling

#### Components
- **Theme Manager**: Theme loading and switching
- **Theme Definitions**: Color, font, and style definitions
- **CSS Generation**: Dynamic CSS for web views

#### Structure
```swift
public class ThemeManager: ObservableObject {
    @Published public var currentTheme: Theme
    
    public func applyTheme(_ theme: Theme)
    public func generateCSS() -> String
}

public struct Theme {
    public let name: String
    public let colors: ThemeColors
    public let fonts: ThemeFonts
    public let styles: ThemeStyles
}
```

### AwfulExtensions
**Location**: `AwfulExtensions/`
**Purpose**: Shared extensions and utilities

#### Components
- **Foundation Extensions**: String, Date, URL utilities
- **UIKit Extensions**: UIColor, UIFont, UIView helpers
- **Core Data Extensions**: NSManagedObject utilities

#### Examples
```swift
// String extensions
extension String {
    var htmlStripped: String { /* implementation */ }
    var attributed: NSAttributedString { /* implementation */ }
}

// UIColor extensions
extension UIColor {
    convenience init(hex: String) { /* implementation */ }
    var hexString: String { /* implementation */ }
}
```

## Feature Modules

### Forums Module
**Location**: `App/View Controllers/Forums/`
**Purpose**: Forum browsing and navigation

#### Components
- **ForumsTableViewController**: Forum list UI
- **ForumViewModel**: SwiftUI view model
- **ForumCell**: Custom table view cell

#### Dependencies
```swift
import AwfulCore
import AwfulTheming
import AwfulSettings
```

### Threads Module
**Location**: `App/View Controllers/Threads/`
**Purpose**: Thread listing and management

#### Components
- **ThreadsTableViewController**: Thread list UI
- **ThreadsViewModel**: SwiftUI view model
- **ThreadCell**: Custom table view cell

#### Key Features
- Thread filtering and sorting
- Unread post indicators
- Pull-to-refresh functionality
- Search integration

### Posts Module
**Location**: `App/View Controllers/Posts/`
**Purpose**: Post viewing and interaction

#### Components
- **PostsPageViewController**: Web-based post display
- **PostsViewModel**: SwiftUI view model
- **PostActionHandler**: User interaction handling

#### Web Integration
```swift
// Web view content generation
func generateHTML(for posts: [Post]) -> String {
    let template = StencilTemplate(named: "posts")
    return template.render(context: [
        "posts": posts,
        "theme": currentTheme,
        "settings": userSettings
    ])
}
```

### Messages Module
**Location**: `App/View Controllers/Messages/`
**Purpose**: Private message management

#### Components
- **MessagesTableViewController**: Message list UI
- **MessageViewController**: Message detail view
- **ComposeViewController**: Message composition

## Extension Modules

### Smilies Keyboard
**Location**: `Smilies/`
**Purpose**: Custom keyboard for inserting smilies

#### Components
- **SmilieKeyboardViewController**: Keyboard UI
- **SmilieProvider**: Smilie data management
- **SmilieCollectionView**: Smilie grid display

#### App Group Integration
```swift
// Shared container for smilies data
let sharedContainer = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.awful.app"
)
```

### Share Extension
**Location**: `AwfulShareExtension/`
**Purpose**: Sharing content to Awful

#### Components
- **ShareViewController**: Share sheet UI
- **ShareContentProcessor**: Content handling
- **ForumSelector**: Target forum selection

## Support Modules

### Utilities
**Location**: `App/Utilities/`
**Purpose**: Common utility functions

#### Components
- **Logger**: Centralized logging
- **Network Utilities**: URL building, request helpers
- **Data Utilities**: JSON parsing, data conversion

### Resources
**Location**: `App/Resources/`
**Purpose**: App resources and assets

#### Components
- **Images**: App icons, UI graphics
- **Sounds**: Audio feedback
- **Fonts**: Custom typefaces
- **Localization**: String resources

## Vendor Modules

### Third-Party Dependencies
**Location**: `Vendor/`
**Purpose**: Third-party code not available via SPM

#### Components
- **Custom HTMLReader**: Modified HTML parsing
- **Legacy Libraries**: Older dependencies
- **Patches**: Custom modifications

### Swift Package Dependencies
**Package.swift equivalent dependencies**:
```swift
dependencies: [
    .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
    .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.0.0"),
    .package(url: "https://github.com/Flipboard/FLAnimatedImage.git", from: "1.0.0"),
    .package(url: "https://github.com/stencilproject/Stencil.git", from: "0.15.0")
]
```

## Module Dependencies

### Dependency Graph
```
┌─────────────────┐
│      App        │
└─────────────────┘
         │
         ▼
┌─────────────────┐    ┌─────────────────┐
│  Feature Modules│───▶│  Core Modules   │
└─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│ Support Modules │    │ Vendor Modules  │
└─────────────────┘    └─────────────────┘
```

### Dependency Rules
1. **Core modules** have no dependencies on feature modules
2. **Feature modules** can depend on core and support modules
3. **Support modules** can depend on core modules
4. **Vendor modules** are standalone or have external dependencies only

## Module Communication

### Protocol-Based Communication
```swift
// Core module protocol
protocol ForumsServiceProtocol {
    func loadForums() async throws -> [Forum]
    func loadThreads(for forum: Forum) async throws -> [Thread]
}

// Feature module implementation
class ForumsService: ForumsServiceProtocol {
    private let client: ForumsClient
    
    init(client: ForumsClient = .shared) {
        self.client = client
    }
    
    func loadForums() async throws -> [Forum] {
        return try await client.loadForums()
    }
}
```

### Event-Driven Communication
```swift
// Event system for loose coupling
extension Notification.Name {
    static let forumDataUpdated = Notification.Name("forumDataUpdated")
    static let themeChanged = Notification.Name("themeChanged")
    static let settingsChanged = Notification.Name("settingsChanged")
}

// Publisher
class ForumsService {
    func updateForums() {
        // Update data
        NotificationCenter.default.post(name: .forumDataUpdated, object: nil)
    }
}

// Subscriber
class ForumsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(forumsUpdated),
            name: .forumDataUpdated,
            object: nil
        )
    }
}
```

## Testing Strategy

### Module Testing
```swift
// Core module tests
class AwfulCoreTests: XCTestCase {
    func testForumsClient() {
        // Test core functionality
    }
}

// Feature module tests
class ForumsModuleTests: XCTestCase {
    func testForumViewModel() {
        // Test feature-specific logic
    }
}
```

### Integration Testing
```swift
class ModuleIntegrationTests: XCTestCase {
    func testForumsToThreadsFlow() {
        // Test cross-module communication
    }
}
```

## SwiftUI Migration Strategy

### Gradual Module Migration
1. **Start with leaf modules** (no dependencies)
2. **Convert support modules** to SwiftUI
3. **Migrate feature modules** one by one
4. **Update core modules** for SwiftUI compatibility

### SwiftUI Module Structure
```swift
// SwiftUI-specific module organization
struct ForumsModule {
    // Views
    struct ForumsListView: View { /* implementation */ }
    struct ForumRowView: View { /* implementation */ }
    
    // View Models
    class ForumsViewModel: ObservableObject { /* implementation */ }
    
    // Services
    class ForumsService { /* implementation */ }
}
```

## Best Practices

### 1. Clear Module Boundaries
- Each module has a single responsibility
- Dependencies flow in one direction
- Public interfaces are well-defined

### 2. Dependency Injection
```swift
// Inject dependencies for testability
class ForumsViewController {
    private let forumsService: ForumsServiceProtocol
    
    init(forumsService: ForumsServiceProtocol = ForumsService()) {
        self.forumsService = forumsService
    }
}
```

### 3. Protocol-Based Design
```swift
// Use protocols for abstraction
protocol ThemeProviderProtocol {
    var currentTheme: Theme { get }
    func applyTheme(_ theme: Theme)
}

class ThemeProvider: ThemeProviderProtocol {
    // Implementation
}
```

### 4. Module Documentation
- Each module has clear documentation
- Public APIs are well-documented
- Dependencies are explicitly listed

### 5. Testing Strategy
- Unit tests for each module
- Integration tests for module interactions
- Mock implementations for testing