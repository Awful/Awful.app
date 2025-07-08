# SwiftUI Theming Migration

## Overview

The migration of Awful.app's sophisticated theming system to SwiftUI presents both opportunities and challenges. This document outlines strategies, architectural patterns, and implementation approaches for preserving the rich theming capabilities while leveraging SwiftUI's reactive design paradigms.

## Current UIKit Theming vs SwiftUI Approach

### UIKit Pattern (Current)

```swift
// Current UIKit approach
class PostsViewController: ViewController, Themeable {
    override var theme: Theme {
        return Theme.currentTheme(for: ForumID(forum.forumID))
    }
    
    func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]
        tableView.separatorColor = theme["listSeparatorColor"]
        navigationController?.navigationBar.tintColor = theme["navbarTintColor"]
    }
}
```

### SwiftUI Pattern (Proposed)

```swift
// Proposed SwiftUI approach
struct PostsView: View {
    @Environment(\.theme) var theme
    let forum: Forum
    
    var body: some View {
        List {
            ForEach(posts) { post in
                PostRow(post: post)
            }
        }
        .background(Color(theme["backgroundColor"]!))
        .listStyle(.plain)
        .environment(\.theme, Theme.currentTheme(for: forum.id))
    }
}
```

## Environment-Based Theme System

### Theme Environment Key

```swift
// ThemeEnvironment.swift
import SwiftUI

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Theme = Theme.defaultTheme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// Convenience accessor
extension View {
    func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
    }
}
```

### Context-Aware Theme Provision

```swift
// ForumAwareThemeProvider.swift
struct ForumAwareThemeProvider<Content: View>: View {
    let forumID: ForumID?
    let content: Content
    
    @State private var currentTheme: Theme
    
    init(forumID: ForumID? = nil, @ViewBuilder content: () -> Content) {
        self.forumID = forumID
        self.content = content()
        self._currentTheme = State(initialValue: Self.resolveTheme(for: forumID))
    }
    
    var body: some View {
        content
            .environment(\.theme, currentTheme)
            .onReceive(NotificationCenter.default.publisher(for: Theme.themeForForumDidChangeNotification)) { notification in
                if let notificationForumID = notification.userInfo?[Theme.forumIDKey] as? String,
                   notificationForumID == forumID?.rawValue {
                    currentTheme = Self.resolveTheme(for: forumID)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .UIKitUserInterfaceStyleDidChange)) { _ in
                currentTheme = Self.resolveTheme(for: forumID)
            }
    }
    
    private static func resolveTheme(for forumID: ForumID?) -> Theme {
        if let forumID = forumID {
            return Theme.currentTheme(for: forumID)
        } else {
            return Theme.defaultTheme()
        }
    }
}
```

## Theme-Aware View Modifiers

### Color Application Modifiers

```swift
// ThemeModifiers.swift
extension View {
    func themedForegroundColor(_ colorKey: String) -> some View {
        modifier(ThemedForegroundColorModifier(colorKey: colorKey))
    }
    
    func themedBackground(_ colorKey: String) -> some View {
        modifier(ThemedBackgroundModifier(colorKey: colorKey))
    }
    
    func themedAccentColor(_ colorKey: String) -> some View {
        modifier(ThemedAccentColorModifier(colorKey: colorKey))
    }
}

struct ThemedForegroundColorModifier: ViewModifier {
    @Environment(\.theme) var theme
    let colorKey: String
    
    func body(content: Content) -> some View {
        content.foregroundColor(Color(theme[colorKey] ?? UIColor.label))
    }
}

struct ThemedBackgroundModifier: ViewModifier {
    @Environment(\.theme) var theme
    let colorKey: String
    
    func body(content: Content) -> some View {
        content.background(Color(theme[colorKey] ?? UIColor.systemBackground))
    }
}

struct ThemedAccentColorModifier: ViewModifier {
    @Environment(\.theme) var theme
    let colorKey: String
    
    func body(content: Content) -> some View {
        content.accentColor(Color(theme[colorKey] ?? UIColor.systemBlue))
    }
}
```

### Typography Modifiers

```swift
// ThemeTypography.swift
extension View {
    func themedFont(_ fontKey: String) -> some View {
        modifier(ThemedFontModifier(fontKey: fontKey))
    }
}

struct ThemedFontModifier: ViewModifier {
    @Environment(\.theme) var theme
    let fontKey: String
    
    func body(content: Content) -> some View {
        content.font(Font(theme.font(for: fontKey)))
    }
}

// Theme extension for font support
extension Theme {
    func font(for key: String) -> UIFont {
        // Extract font properties from theme
        if let fontDict = dictionary[key] as? [String: Any],
           let fontName = fontDict["fontName"] as? String,
           let fontSize = fontDict["fontSize"] as? CGFloat {
            
            if let weight = fontDict["fontWeight"] as? String,
               let fontWeight = FontWeight.weight(for: weight) {
                return UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            } else if let customFont = UIFont(name: fontName, size: fontSize) {
                return customFont
            }
        }
        
        // Fallback to system font
        return UIFont.systemFont(ofSize: 14)
    }
}
```

## Component-Level Theme Integration

### Themed List Components

```swift
// ThemedList.swift
struct ThemedList<Content: View>: View {
    @Environment(\.theme) var theme
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        List {
            content
        }
        .listStyle(.plain)
        .themedBackground("listBackgroundColor")
        .scrollIndicators(theme.scrollIndicatorStyle == .black ? .dark : .light)
    }
}

struct ThemedListRow<Content: View>: View {
    @Environment(\.theme) var theme
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .listRowBackground(Color(theme["listBackgroundColor"] ?? UIColor.systemBackground))
            .listRowSeparatorTint(Color(theme["listSeparatorColor"] ?? UIColor.separator))
    }
}
```

### Post Content Views

```swift
// PostView.swift
struct PostView: View {
    @Environment(\.theme) var theme
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostHeader(post: post)
            PostContent(post: post)
            PostFooter(post: post)
        }
        .padding()
        .themedBackground(post.seen ? "listBackgroundColorSeen" : "listBackgroundColor")
        .overlay(
            Rectangle()
                .fill(Color(theme["listSeparatorColor"] ?? UIColor.separator))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

struct PostHeader: View {
    @Environment(\.theme) var theme
    let post: Post
    
    var body: some View {
        HStack {
            AsyncImage(url: post.author.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading) {
                Text(post.author.username)
                    .font(.headline)
                    .themedForegroundColor("listTextColor")
                
                Text(post.date, style: .relative)
                    .font(.caption)
                    .themedForegroundColor("listSecondaryTextColor")
            }
            
            Spacer()
        }
    }
}
```

### Navigation Integration

```swift
// ThemedNavigationView.swift
struct ThemedNavigationView<Content: View>: View {
    @Environment(\.theme) var theme
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        NavigationView {
            content
        }
        .accentColor(Color(theme["navbarTintColor"] ?? UIColor.systemBlue))
        .onAppear {
            configureNavigationBarAppearance()
        }
        .onChange(of: theme.name) { _ in
            configureNavigationBarAppearance()
        }
    }
    
    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.backgroundColor = theme["navbarBackgroundColor"]
        appearance.titleTextAttributes = [
            .foregroundColor: theme["navbarTitleTextColor"] ?? UIColor.label
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
```

## Web Content Integration

### SwiftUI WebView with Theme Support

```swift
// ThemedWebView.swift
import SwiftUI
import WebKit

struct ThemedWebView: UIViewRepresentable {
    @Environment(\.theme) var theme
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = generateStyledHTML()
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    private func generateStyledHTML() -> String {
        let css = theme["postsViewCSS"] ?? ""
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                \(css)
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
    }
}

// Usage in SwiftUI
struct PostContentView: View {
    @Environment(\.theme) var theme
    let post: Post
    
    var body: some View {
        ThemedWebView(htmlContent: post.content)
            .frame(minHeight: 200)
    }
}
```

## Dynamic Theme Switching

### Observable Theme Manager

```swift
// ThemeManager.swift
import SwiftUI
import Combine

@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme
    @Published var currentMode: Theme.Mode
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.currentTheme = Theme.defaultTheme()
        self.currentMode = Theme.Mode.allCases.first { /* detect system mode */ } ?? .light
        
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen for theme change notifications
        NotificationCenter.default.publisher(for: Theme.themeForForumDidChangeNotification)
            .sink { [weak self] notification in
                self?.handleThemeChange(notification)
            }
            .store(in: &cancellables)
        
        // Listen for system appearance changes
        NotificationCenter.default.publisher(for: .UIKitUserInterfaceStyleDidChange)
            .sink { [weak self] _ in
                self?.updateForSystemAppearanceChange()
            }
            .store(in: &cancellables)
    }
    
    func setTheme(_ theme: Theme, for forumID: ForumID? = nil) {
        if let forumID = forumID {
            Theme.setThemeName(theme.name, forForumIdentifiedBy: forumID.rawValue, modes: [currentMode])
        } else {
            // Set as default theme
            UserDefaults.standard.set(theme.name, forKey: currentMode == .dark ? "defaultDarkTheme" : "defaultLightTheme")
        }
        
        currentTheme = theme
    }
    
    private func handleThemeChange(_ notification: Notification) {
        // Update current theme based on notification
        currentTheme = Theme.defaultTheme(mode: currentMode)
    }
    
    private func updateForSystemAppearanceChange() {
        // Detect new system appearance and update accordingly
        currentMode = /* detect new mode */
        currentTheme = Theme.defaultTheme(mode: currentMode)
    }
}
```

### App-Level Theme Integration

```swift
// AwfulApp.swift
@main
struct AwfulApp: App {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environment(\.theme, themeManager.currentTheme)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        TabView {
            ForumsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Forums")
                }
            
            BookmarksView()
                .tabItem {
                    Image(systemName: "bookmark")
                    Text("Bookmarks")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .themedAccentColor("tabBarTintColor")
    }
}
```

## Performance Considerations

### Theme Caching

```swift
// ThemeCache.swift
class ThemeCache {
    private var colorCache: [String: Color] = [:]
    private var fontCache: [String: Font] = [:]
    
    func color(for key: String, in theme: Theme) -> Color {
        let cacheKey = "\(theme.name)-\(key)"
        
        if let cached = colorCache[cacheKey] {
            return cached
        }
        
        let color = Color(theme[key] ?? UIColor.label)
        colorCache[cacheKey] = color
        return color
    }
    
    func clearCache() {
        colorCache.removeAll()
        fontCache.removeAll()
    }
}
```

### Lazy Theme Resolution

```swift
// LazyThemedView.swift
struct LazyThemedView<Content: View>: View {
    let forumID: ForumID?
    let content: Content
    
    @State private var resolvedTheme: Theme?
    
    init(forumID: ForumID? = nil, @ViewBuilder content: () -> Content) {
        self.forumID = forumID
        self.content = content()
    }
    
    var body: some View {
        Group {
            if let theme = resolvedTheme {
                content
                    .environment(\.theme, theme)
            } else {
                ProgressView()
                    .onAppear {
                        resolveTheme()
                    }
            }
        }
    }
    
    private func resolveTheme() {
        Task {
            let theme = await ThemeResolver.resolve(for: forumID)
            await MainActor.run {
                resolvedTheme = theme
            }
        }
    }
}
```

## Migration Strategy

### Phase 1: Environment Setup

1. **Establish Theme Environment**: Implement `ThemeEnvironmentKey` and basic environment support
2. **Create View Modifiers**: Build foundational theme-aware view modifiers
3. **Theme Manager**: Implement `@ObservableObject` theme manager for global state

### Phase 2: Component Migration

1. **Simple Views First**: Start with basic views like settings screens
2. **List Components**: Migrate table view controllers to SwiftUI Lists
3. **Navigation**: Update navigation components with theme support

### Phase 3: Complex Integration

1. **Web View Integration**: Implement `ThemedWebView` for post content
2. **Forum-Specific Themes**: Ensure context-aware theme switching works
3. **Performance Optimization**: Implement caching and lazy loading

### Phase 4: Testing and Refinement

1. **Visual Regression Testing**: Ensure themes render identically
2. **Performance Testing**: Verify no performance regressions
3. **User Testing**: Validate theme switching behavior

## Compatibility Considerations

### UIKit Interoperability

```swift
// UIKitThemeBridge.swift
struct UIKitThemeBridge: UIViewControllerRepresentable {
    @Environment(\.theme) var theme
    let viewController: UIViewController & Themeable
    
    func makeUIViewController(context: Context) -> UIViewController {
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if var themeable = uiViewController as? Themeable {
            // Update UIKit component with SwiftUI theme
            themeable.theme = theme
            themeable.themeDidChange()
        }
    }
}
```

### Backward Compatibility

During migration, both systems need to coexist:

```swift
// HybridThemeView.swift
struct HybridThemeView<Content: View>: View {
    let content: Content
    
    @State private var theme: Theme = Theme.defaultTheme()
    
    var body: some View {
        content
            .environment(\.theme, theme)
            .onReceive(NotificationCenter.default.publisher(for: Theme.themeForForumDidChangeNotification)) { _ in
                // Sync with UIKit theme changes
                theme = Theme.defaultTheme()
            }
    }
}
```

## Testing SwiftUI Themes

### Unit Tests

```swift
// ThemeEnvironmentTests.swift
class ThemeEnvironmentTests: XCTestCase {
    func testThemeEnvironmentPropagation() {
        let theme = Theme.theme(named: "yospos")!
        
        let view = TestView()
            .environment(\.theme, theme)
        
        let hosting = UIHostingController(rootView: view)
        
        // Verify theme is accessible in view hierarchy
        XCTAssertEqual(hosting.rootView.theme.name, "yospos")
    }
}

struct TestView: View {
    @Environment(\.theme) var theme
    
    var body: some View {
        Text("Test")
            .themedForegroundColor("listTextColor")
    }
}
```

### Visual Testing

```swift
// SwiftUIThemeSnapshotTests.swift
class SwiftUIThemeSnapshotTests: XCTestCase {
    func testYOSPOSThemeSnapshot() {
        let theme = Theme.theme(named: "yospos")!
        let view = PostView(post: samplePost)
            .environment(\.theme, theme)
            .frame(width: 320, height: 200)
        
        assertSnapshot(matching: view, as: .image)
    }
}
```

The SwiftUI migration preserves the sophisticated theming capabilities of Awful.app while embracing SwiftUI's declarative and reactive paradigms, ensuring a smooth transition that maintains the unique visual identity that defines the app's character.