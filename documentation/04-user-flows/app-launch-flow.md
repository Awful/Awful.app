# App Launch Flow

## Overview

Awful.app has a sophisticated launch sequence that handles authentication state, interface restoration, and adaptive UI configuration. This flow is critical to preserve during the SwiftUI migration.

## Launch Sequence

### 1. AppDelegate Launch

**Location**: `App/Main/AppDelegate.swift`

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // 1. Configure logging and settings
    configureLogging()
    SettingsMigration.migrate(.standard)
    
    // 2. Check authentication state
    if ForumsClient.shared.isLoggedIn {
        setupLoggedInInterface()
    } else {
        showLoginScreen()
    }
    
    // 3. Configure appearance and themes
    configureAppearance()
    
    // 4. Setup background refresh
    setupBackgroundRefresh()
    
    return true
}
```

### 2. Authentication-Based Routing

#### Logged In Flow
```
AppDelegate → RootViewControllerStack → AwfulSplitViewController
                                        ├─ Primary: RootTabBarController
                                        └─ Secondary: DetailViewController
```

#### Not Logged In Flow
```
AppDelegate → LoginViewController (Modal)
```

### 3. Root View Controller Stack

**Location**: `App/View Controllers/RootViewControllerStack.swift`

**Purpose**: Container that handles iOS split view controller bugs

```swift
class RootViewControllerStack: UIViewController {
    private let passthroughViewController = PassthroughViewController()
    private let splitViewController = AwfulSplitViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup hierarchy to work around iOS bugs
        addChild(passthroughViewController)
        view.addSubview(passthroughViewController.view)
        passthroughViewController.didMove(toParent: self)
        
        passthroughViewController.childViewController = splitViewController
    }
}
```

**Critical iOS Bug Workarounds**:
- Prevents split view issues with alternate app icon changes
- Handles rotation edge cases
- Manages proper toolbar button placement

## Split View Configuration

### AwfulSplitViewController

**Location**: `App/View Controllers/AwfulSplitViewController.swift`

**Configuration**:
```swift
class AwfulSplitViewController: UISplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set primary and secondary view controllers
        primaryViewController = RootTabBarController()
        secondaryViewController = UINavigationController()
        
        // Configure display modes
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        
        // Hide sidebar setting integration
        if Settings.hideSidebarInLandscape {
            preferredDisplayMode = .secondaryOnly
        }
    }
}
```

### Tab Bar Structure

**Primary Controller**: `RootTabBarController`

**Tabs**:
1. **Forums Tab**: `ForumsTableViewController`
2. **Bookmarks Tab**: `BookmarksTableViewController`  
3. **Private Messages Tab**: `PrivateMessageTableViewController`
4. **Profile Tab**: `ProfileViewController`
5. **Settings Tab**: `SettingsViewController`

## State Restoration

### Restoration Architecture

**Interface Versioning**:
```swift
let currentInterfaceVersion = "3.0"

// Check if restoration data is compatible
if restoredInterfaceVersion != currentInterfaceVersion {
    // Skip restoration, show default interface
    return false
}
```

**Restoration Flow**:
1. Check interface version compatibility
2. Restore tab bar selection
3. Restore navigation stacks
4. Restore composition drafts
5. Restore scroll positions

**Restoration Identifiers**:
- Root controllers: `"AwfulRootTabBarController"`
- Forums: `"AwfulForumsTableViewController"`
- Threads: `"AwfulThreadsTableViewController-{forumID}"`
- Posts: `"AwfulPostsPageViewController-{threadID}"`

### Safe Restoration Fallbacks

```swift
func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
    // Only restore if user is logged in
    guard ForumsClient.shared.isLoggedIn else { return false }
    
    // Check interface version compatibility
    let restoredVersion = coder.decodeObject(forKey: "interfaceVersion") as? String
    return restoredVersion == currentInterfaceVersion
}
```

## Theme and Appearance Setup

### Launch Theme Configuration

```swift
func configureAppearance() {
    // Apply current theme
    Theme.currentTheme = ThemeManager.currentTheme
    
    // Configure navigation bar appearance
    setupNavigationBarAppearance()
    
    // Configure tab bar appearance
    setupTabBarAppearance()
    
    // Apply forum-specific tweaks
    applyForumTweaks()
}
```

### Dynamic Theme Updates

**System Theme Changes**:
```swift
func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    
    if Settings.autoDarkTheme && 
       traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
        ThemeManager.updateForSystemThemeChange()
    }
}
```

## Background Refresh Setup

### Background App Refresh Configuration

```swift
func setupBackgroundRefresh() {
    // Register for background app refresh
    UIApplication.shared.setMinimumBackgroundFetchInterval(
        UIApplication.backgroundFetchIntervalMinimum
    )
    
    // Setup refresh minder
    RefreshMinder.shared.startMonitoring()
}
```

## Error Handling During Launch

### Launch Failure Scenarios

1. **Authentication Issues**:
   - Expired cookies → Show login
   - Network unavailable → Show cached content
   - Server errors → Show error alert

2. **Data Migration Failures**:
   - Core Data migration errors → Reset store
   - Settings migration failures → Use defaults
   - State restoration failures → Fresh start

3. **Configuration Issues**:
   - Theme loading failures → Use default theme
   - Asset loading failures → Use fallback assets

### Error Recovery

```swift
func handleLaunchError(_ error: Error) {
    switch error {
    case let coreDataError as NSError where coreDataError.domain == NSCocoaErrorDomain:
        // Reset Core Data store
        resetDataStore()
        
    case let networkError as URLError:
        // Show offline mode
        showOfflineInterface()
        
    default:
        // Show generic error and fresh start
        showErrorAlert(error)
        showDefaultInterface()
    }
}
```

## Performance Considerations

### Launch Time Optimization

1. **Lazy Loading**: Defer non-critical setup until after UI appears
2. **Background Processing**: Move heavy operations off main thread
3. **Progressive Loading**: Load content as needed, not all at once
4. **Cache Warming**: Pre-load frequently accessed data

### Memory Management

```swift
func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    // Clear image caches
    ImagePipeline.shared.cache.removeAll()
    
    // Clear URL cache
    URLCache.shared.removeAllCachedResponses()
    
    // Notify view controllers to reduce memory usage
    NotificationCenter.default.post(name: .AwfulDidReceiveMemoryWarning, object: nil)
}
```

## Deep Linking Support

### URL Scheme Handling

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Handle awful:// URLs
    if url.scheme == "awful" {
        return AwfulURLRouter.shared.route(url)
    }
    
    // Handle https://forums.somethingawful.com URLs
    if url.host == "forums.somethingawful.com" {
        return AwfulURLRouter.shared.route(url)
    }
    
    return false
}
```

### URL Routing Patterns

- `awful://forums` → Open forums list
- `awful://threads/{forumID}` → Open thread list for forum
- `awful://posts/{threadID}` → Open thread
- `awful://posts/{threadID}/page/{page}` → Open specific page
- `awful://user/{userID}` → Open user profile

## SwiftUI Migration Considerations

### Preserving Launch Flow

1. **App Struct**: Replace AppDelegate with SwiftUI App struct
2. **Scene Management**: Use WindowGroup and Scene APIs
3. **State Management**: Convert authentication state to ObservableObject
4. **Navigation**: Replace split view with NavigationSplitView

### Migration Strategy

**Phase 1**: Wrap existing controllers in UIViewControllerRepresentable
**Phase 2**: Replace individual tabs with SwiftUI views
**Phase 3**: Convert entire navigation hierarchy to SwiftUI

**Critical Preservation**:
- Authentication-based routing
- State restoration behavior
- Theme application timing
- Background refresh setup
- Deep linking functionality

## Testing Launch Flow

### Test Scenarios

1. **Fresh Install**: First launch with no prior data
2. **Returning User**: Launch with existing authentication
3. **Expired Session**: Launch with expired authentication
4. **Version Upgrade**: Launch after app update
5. **State Restoration**: Launch with saved state
6. **Background Launch**: Launch from background refresh
7. **Deep Link Launch**: Launch from URL scheme

### Automated Testing

```swift
func testFreshInstallLaunch() {
    // Clear all data
    clearUserDefaults()
    clearCoreData()
    clearKeychain()
    
    // Launch app
    let app = XCUIApplication()
    app.launch()
    
    // Verify login screen appears
    XCTAssertTrue(app.otherElements["LoginViewController"].exists)
}
```

## Files to Monitor

**Critical Launch Files**:
- `App/Main/AppDelegate.swift`
- `App/View Controllers/RootViewControllerStack.swift`
- `App/View Controllers/AwfulSplitViewController.swift`
- `App/View Controllers/RootTabBarController.swift`
- `AwfulSettings/Sources/AwfulSettings/Migration.swift`

**Any changes to these files must preserve the exact launch behavior and authentication flow.**
