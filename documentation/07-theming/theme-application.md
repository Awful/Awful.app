# Theme Application System

## Overview

The theme application system in Awful.app orchestrates how themes are applied to UI components, manages real-time updates, and ensures consistency across the entire application. This system handles everything from initial theme loading to dynamic switching without requiring app restarts.

## Core Application Architecture

### Themeable Protocol

The foundation of theme application is the `Themeable` protocol:

```swift
public protocol Themeable {
    /// The current theme for this component
    var theme: Theme { get }
    
    /// Called whenever the theme changes
    func themeDidChange()
}
```

All UI components that support theming implement this protocol, creating a unified update mechanism.

### Base View Controller Implementation

The `ViewController` class provides the foundation for theme-aware components:

```swift
open class ViewController: UIViewController, Themeable {
    
    /// The theme to use for the view controller
    open var theme: Theme {
        return Theme.defaultTheme()
    }
    
    // MARK: View lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        themeDidChange()
    }
    
    /// Default theme application implementation
    open func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]
        
        // Find and update scroll view indicators
        let scrollView: UIScrollView? = findScrollViewInHierarchy()
        scrollView?.indicatorStyle = theme.scrollIndicatorStyle
    }
}
```

### Specialized View Controller Classes

#### Table View Controllers

```swift
open class TableViewController: UITableViewController, Themeable {
    
    open func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]
        
        // Update pull-to-refresh styling
        if let pullToRefreshView {
            pullToRefreshView.backgroundColor = view.backgroundColor
            if let niggly = pullToRefreshView as? NigglyRefreshLottieView {
                niggly.theme = theme
            }
        }
        
        // Apply table-specific theming
        tableView.indicatorStyle = theme.scrollIndicatorStyle
        tableView.separatorColor = theme["listSeparatorColor"]
        
        // Update tab bar appearance
        updateTabBarAppearance()
        
        // Reload data to apply theme to cells
        if !viewIsLoading {
            tableView.reloadData()
        }
    }
    
    private func updateTabBarAppearance() {
        if theme[bool: "showRootTabBarLabel"] == false {
            tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 0, bottom: -9, right: 0)
            tabBarItem.title = nil
        } else {
            tabBarItem.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            tabBarItem.title = title
        }
    }
}
```

#### SwiftUI Hosting Controllers

```swift
open class HostingController<Content: View>: UIHostingController<Content>, Themeable {
    
    open var theme: Theme {
        Theme.defaultTheme()
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        themeDidChange()
    }

    open func themeDidChange() {
        updateTabBarAppearance()
    }
}
```

## Theme Selection and Context Awareness

### Forum-Specific Theme Resolution

The theme system automatically selects appropriate themes based on context:

```swift
// PostsPageViewController.swift
override var theme: Theme {
    guard let forum = thread.forum, !forum.forumID.isEmpty else {
        return Theme.defaultTheme()
    }
    return Theme.currentTheme(for: ForumID(forum.forumID))
}
```

### Theme Resolution Algorithm

```swift
public static func currentTheme(for forumID: ForumID, mode: Mode? = nil) -> Theme {
    let mode = mode ?? currentMode
    
    // 1. Check for user's custom forum theme
    if let themeName = themeNameForForum(identifiedBy: forumID.rawValue, mode: mode) {
        return bundledThemes[themeName]!
    }
    
    // 2. Fall back to default theme for mode
    return defaultTheme(mode: mode)
}

private static func themeNameForForum(identifiedBy forumID: String, mode: Mode) -> String? {
    return UserDefaults.standard.string(forKey: defaultsKeyForForum(identifiedBy: forumID, mode: mode))
}
```

### Storage Key Generation

```swift
public static func defaultsKeyForForum(identifiedBy forumID: String, mode: Mode) -> String {
    switch mode {
    case .light:
        return "theme-light-\(forumID)"
    case .dark:
        return "theme-dark-\(forumID)"
    }
}
```

## Real-Time Theme Updates

### Notification System

Theme changes are broadcast through the notification system:

```swift
/// Posted when theme settings change for a forum
public static let themeForForumDidChangeNotification: Notification.Name = .init("Awful theme for forum did change")

/// Update theme and notify observers
public static func setThemeName(_ themeName: String?, forForumIdentifiedBy forumID: String, modes: Set<Mode>) {
    for mode in modes {
        UserDefaults.standard.set(themeName, forKey: defaultsKeyForForum(identifiedBy: forumID, mode: mode))
    }
    
    var userInfo = [Theme.forumIDKey: forumID]
    if let themeName = themeName {
        userInfo[Theme.themeNameKey] = themeName
    }
    NotificationCenter.default.post(name: Theme.themeForForumDidChangeNotification, object: self, userInfo: userInfo)
}
```

### Automatic Update Propagation

View controllers observe theme change notifications:

```swift
class PostsPageViewController: ViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Listen for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChangeNotification(_:)),
            name: Theme.themeForForumDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func themeDidChangeNotification(_ notification: Notification) {
        guard let forumID = notification.userInfo?[Theme.forumIDKey] as? String,
              forumID == thread.forum?.forumID else { return }
        
        // Apply new theme
        themeDidChange()
        
        // Update web view content
        updateWebViewTheme()
    }
}
```

## Component-Specific Theme Application

### Navigation Bar Theming

```swift
extension UINavigationController {
    func applyTheme(_ theme: Theme) {
        navigationBar.tintColor = theme["navbarTintColor"]
        navigationBar.titleTextAttributes = [
            .foregroundColor: theme["navbarTitleTextColor"] ?? UIColor.label
        ]
        
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.backgroundColor = theme["navbarBackgroundColor"]
            appearance.titleTextAttributes = [
                .foregroundColor: theme["navbarTitleTextColor"] ?? UIColor.label
            ]
            
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
    }
}
```

### Tab Bar Theming

```swift
extension UITabBarController {
    func applyTheme(_ theme: Theme) {
        tabBar.tintColor = theme["tabBarTintColor"]
        tabBar.backgroundColor = theme["tabBarBackgroundColor"]
        
        // Handle tab bar label visibility
        for item in tabBar.items ?? [] {
            if theme[bool: "showRootTabBarLabel"] == false {
                item.imageInsets = UIEdgeInsets(top: 9, left: 0, bottom: -9, right: 0)
                item.title = nil
            } else {
                item.imageInsets = UIEdgeInsets.zero
                // Title restored from original value
            }
        }
    }
}
```

### Table View Cell Theming

```swift
class ThemedTableViewCell: UITableViewCell {
    
    var theme: Theme = Theme.defaultTheme() {
        didSet {
            applyTheme()
        }
    }
    
    private func applyTheme() {
        backgroundColor = theme["listBackgroundColor"]
        textLabel?.textColor = theme["listTextColor"]
        detailTextLabel?.textColor = theme["listSecondaryTextColor"]
        
        // Selected state
        let selectedView = UIView()
        selectedView.backgroundColor = theme["listSelectedBackgroundColor"]
        selectedBackgroundView = selectedView
    }
}
```

### Pull-to-Refresh Theming

```swift
private func createRefreshControl() {
    guard tableView.topPullToRefresh == nil else { return }
    
    let niggly = NigglyRefreshLottieView(theme: theme)
    let targetSize = CGSize(width: tableView.bounds.width, height: 0)
   
    niggly.bounds.size = niggly.systemLayoutSizeFitting(targetSize, 
                                                       withHorizontalFittingPriority: .required, 
                                                       verticalFittingPriority: .fittingSizeLevel)
    niggly.autoresizingMask = .flexibleWidth
    niggly.backgroundColor = view.backgroundColor
    
    pullToRefreshView = niggly
    
    let animator = NigglyRefreshLottieView.RefreshAnimator(view: niggly)
    let pullToRefresh = PullToRefresh(refreshView: niggly, animator: animator, 
                                    height: niggly.bounds.height, position: .top)
    
    tableView.addPullToRefresh(pullToRefresh) { [weak self] in
        self?.pullToRefreshBlock?()
    }
}
```

## Web View Theme Integration

### CSS Injection for Theme Updates

```swift
class PostsPageViewController: ViewController {
    
    override func themeDidChange() {
        super.themeDidChange()
        updateWebViewTheme()
    }
    
    private func updateWebViewTheme() {
        guard let css = theme["postsViewCSS"] else { return }
        
        let script = """
            // Remove existing theme CSS
            var existingStyle = document.getElementById('theme-css');
            if (existingStyle) {
                existingStyle.remove();
            }
            
            // Inject new theme CSS
            var style = document.createElement('style');
            style.id = 'theme-css';
            style.textContent = `\(css)`;
            document.head.appendChild(style);
            
            // Update body class for theme-specific styling
            document.body.className = document.body.className.replace(/theme-\\w+/g, '');
            document.body.classList.add('theme-\(theme.name)');
        """
        
        postsView.renderView.evaluateJavaScript(script)
    }
}
```

### Dynamic Theme Variable Injection

```swift
private func injectThemeVariables() {
    let variables = [
        "--background-color": theme["backgroundColor"]?.hexString ?? "#ffffff",
        "--text-color": theme["listTextColor"]?.hexString ?? "#000000",
        "--link-color": theme["linkColor"]?.hexString ?? "#007aff",
        "--border-color": theme["listSeparatorColor"]?.hexString ?? "#cccccc"
    ]
    
    let cssVariables = variables.map { key, value in
        "\(key): \(value);"
    }.joined(separator: " ")
    
    let script = """
        document.documentElement.style.cssText += '\(cssVariables)';
    """
    
    postsView.renderView.evaluateJavaScript(script)
}
```

## Performance Optimizations

### Batch Theme Updates

```swift
class ThemeUpdateCoordinator {
    private var pendingUpdates: Set<Themeable> = []
    private var updateTimer: Timer?
    
    func scheduleUpdate(for themeable: Themeable) {
        pendingUpdates.insert(themeable)
        
        // Debounce rapid theme changes
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.performBatchUpdate()
        }
    }
    
    private func performBatchUpdate() {
        DispatchQueue.main.async {
            for themeable in self.pendingUpdates {
                themeable.themeDidChange()
            }
            self.pendingUpdates.removeAll()
        }
    }
}
```

### Efficient Property Access

```swift
// Cache frequently accessed properties
class OptimizedThemeableView: UIView, Themeable {
    private var cachedBackgroundColor: UIColor?
    private var cachedTextColor: UIColor?
    
    var theme: Theme = Theme.defaultTheme() {
        didSet {
            invalidateCache()
            themeDidChange()
        }
    }
    
    private func invalidateCache() {
        cachedBackgroundColor = nil
        cachedTextColor = nil
    }
    
    func themeDidChange() {
        backgroundColor = cachedBackgroundColor ?? {
            let color = theme["backgroundColor"]!
            cachedBackgroundColor = color
            return color
        }()
        
        // Apply other cached properties...
    }
}
```

### Memory Management

```swift
class ThemeableViewController: ViewController {
    deinit {
        // Clean up theme observers
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Release expensive theme resources when not visible
        if isMovingFromParent {
            clearThemeCache()
        }
    }
}
```

## Testing Theme Application

### Unit Tests

```swift
func testThemeApplication() {
    let mockViewController = MockViewController()
    let darkTheme = Theme.theme(named: "dark")!
    
    mockViewController.theme = darkTheme
    mockViewController.themeDidChange()
    
    XCTAssertEqual(mockViewController.view.backgroundColor, darkTheme["backgroundColor"])
}

func testThemeUpdateNotification() {
    let expectation = XCTestExpectation(description: "Theme update received")
    
    let observer = NotificationCenter.default.addObserver(
        forName: Theme.themeForForumDidChangeNotification,
        object: nil,
        queue: nil
    ) { _ in
        expectation.fulfill()
    }
    
    Theme.setThemeName("dark", forForumIdentifiedBy: "123", modes: [.dark])
    
    wait(for: [expectation], timeout: 1.0)
    NotificationCenter.default.removeObserver(observer)
}
```

### UI Tests

```swift
func testRealTimeThemeSwitch() {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to settings
    app.buttons["Settings"].tap()
    app.buttons["Theme"].tap()
    
    // Switch theme
    app.buttons["Dark"].tap()
    
    // Verify theme applied
    XCTAssertTrue(app.otherElements["DarkThemeIndicator"].exists)
    
    // Return to content and verify theme persisted
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.otherElements["DarkBackgroundElement"].exists)
}
```

### Performance Tests

```swift
func testThemeSwitchingPerformance() {
    measure {
        for _ in 0..<100 {
            let viewController = PostsPageViewController(thread: testThread)
            viewController.theme = Theme.theme(named: "yospos")!
            viewController.themeDidChange()
        }
    }
}
```

## Error Handling and Fallbacks

### Graceful Degradation

```swift
extension Theme {
    subscript(safeColorAccess key: String) -> UIColor {
        return self[key] ?? {
            logger.warning("Missing theme property: \(key), using system default")
            return UIColor.label // System default
        }()
    }
}
```

### Theme Validation

```swift
func validateTheme(_ theme: Theme) -> Bool {
    let requiredProperties = [
        "backgroundColor", "listTextColor", "navbarTintColor"
    ]
    
    for property in requiredProperties {
        guard theme[property] != nil else {
            logger.error("Theme \(theme.name) missing required property: \(property)")
            return false
        }
    }
    
    return true
}
```

## Future SwiftUI Migration

### Proposed SwiftUI Theme Application

```swift
// Environment-based theme access
struct ContentView: View {
    @Environment(\.theme) var theme
    
    var body: some View {
        VStack {
            Text("Hello World")
                .foregroundColor(Color(theme["listTextColor"]!))
        }
        .background(Color(theme["backgroundColor"]!))
        .onReceive(NotificationCenter.default.publisher(for: Theme.themeForForumDidChangeNotification)) { _ in
            // SwiftUI automatically updates when environment changes
        }
    }
}

// Theme environment key
struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Theme = Theme.defaultTheme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
```

The theme application system demonstrates how careful architecture enables smooth, performant theming across a complex iOS application while maintaining consistency and providing excellent user experience.