# Theming Migration Guide

## Overview

This guide covers migrating Awful.app's complex theming system from UIKit to SwiftUI while preserving all existing themes, custom styling, and forum-specific visual behaviors.

## Current Theming Architecture

### UIKit Implementation
```swift
// Current theme system
class Theme: NSObject {
    let name: String
    let displayName: String
    let plist: [String: Any]
    
    // Color properties
    var tintColor: UIColor { color(for: "tintColor") }
    var backgroundColor: UIColor { color(for: "backgroundColor") }
    var cellBackgroundColor: UIColor { color(for: "cellBackgroundColor") }
    var separatorColor: UIColor { color(for: "separatorColor") }
    
    // Font properties
    var bodyFont: UIFont { font(for: "bodyFont") }
    var titleFont: UIFont { font(for: "titleFont") }
    
    // CSS for web view
    var postCSS: String { css(for: "post") }
    var threadCSS: String { css(for: "thread") }
    
    private func color(for key: String) -> UIColor {
        // Parse color from plist
    }
    
    private func font(for key: String) -> UIFont {
        // Parse font from plist
    }
    
    private func css(for component: String) -> String {
        // Load CSS from bundle
    }
}

// Current theme manager
class ThemeManager: NSObject {
    static let shared = ThemeManager()
    
    @objc dynamic var currentTheme: Theme
    private var themes: [Theme] = []
    
    func loadThemes() {
        // Load themes from bundle
    }
    
    func setTheme(_ theme: Theme) {
        currentTheme = theme
        applyTheme()
    }
    
    private func applyTheme() {
        // Apply theme to UIAppearance
        UINavigationBar.appearance().barTintColor = currentTheme.tintColor
        UITableView.appearance().backgroundColor = currentTheme.backgroundColor
        // ... more appearance configuration
    }
}
```

### Key Theming Components
1. **Theme Definition**: Plist-based theme configuration
2. **Color System**: Dynamic color loading from theme files
3. **Font System**: Custom font definitions
4. **CSS Integration**: Web view styling
5. **Forum-Specific Themes**: YOSPOS, FYAD, etc.
6. **Dynamic Switching**: Runtime theme changes

## SwiftUI Migration Strategy

### Phase 1: SwiftUI Theme Foundation

Create SwiftUI-compatible theme system:

```swift
// New AwfulTheme.swift
struct AwfulTheme: Equatable {
    let name: String
    let displayName: String
    let colors: ThemeColors
    let fonts: ThemeFonts
    let css: ThemeCSS
    
    static let `default` = AwfulTheme(
        name: "default",
        displayName: "Default",
        colors: ThemeColors(),
        fonts: ThemeFonts(),
        css: ThemeCSS()
    )
}

struct ThemeColors {
    // Primary colors
    let primary: Color
    let secondary: Color
    let accent: Color
    
    // Background colors
    let background: Color
    let secondaryBackground: Color
    let tertiaryBackground: Color
    
    // Text colors
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    
    // System colors
    let separator: Color
    let tint: Color
    let warning: Color
    let error: Color
    
    // Forum-specific colors
    let forumColors: [String: Color]
    
    init(from plist: [String: Any] = [:]) {
        // Initialize colors from plist data
        self.primary = Color(plist["primary"] as? String ?? "#007AFF")
        self.secondary = Color(plist["secondary"] as? String ?? "#8E8E93")
        // ... initialize all colors
        self.forumColors = Self.parseForumColors(plist["forumColors"] as? [String: String] ?? [:])
    }
    
    private static func parseForumColors(_ dict: [String: String]) -> [String: Color] {
        return dict.mapValues { Color($0) }
    }
}

struct ThemeFonts {
    let body: Font
    let title: Font
    let headline: Font
    let subheadline: Font
    let caption: Font
    let footnote: Font
    
    init(from plist: [String: Any] = [:]) {
        // Initialize fonts from plist data
        self.body = Font.system(size: 16, weight: .regular, design: .default)
        self.title = Font.system(size: 28, weight: .bold, design: .default)
        // ... initialize all fonts
    }
}

struct ThemeCSS {
    let postCSS: String
    let threadCSS: String
    let profileCSS: String
    let forumCSS: [String: String]
    
    init(from bundle: Bundle = .main) {
        // Load CSS files from bundle
        self.postCSS = Self.loadCSS(named: "post", from: bundle)
        self.threadCSS = Self.loadCSS(named: "thread", from: bundle)
        self.profileCSS = Self.loadCSS(named: "profile", from: bundle)
        self.forumCSS = Self.loadForumCSS(from: bundle)
    }
    
    private static func loadCSS(named name: String, from bundle: Bundle) -> String {
        guard let url = bundle.url(forResource: name, withExtension: "css"),
              let content = try? String(contentsOf: url) else {
            return ""
        }
        return content
    }
    
    private static func loadForumCSS(from bundle: Bundle) -> [String: String] {
        // Load forum-specific CSS files
        var forumCSS: [String: String] = [:]
        // Implementation to load CSS for each forum
        return forumCSS
    }
}
```

### Phase 2: SwiftUI Theme Manager

Create observable theme manager:

```swift
// New SwiftUIThemeManager.swift
@MainActor
class SwiftUIThemeManager: ObservableObject {
    @Published var currentTheme: AwfulTheme
    @Published var availableThemes: [AwfulTheme] = []
    @Published var isDarkMode: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "selectedTheme"
    
    init() {
        self.currentTheme = .default
        loadThemes()
        loadSelectedTheme()
    }
    
    func loadThemes() {
        var themes: [AwfulTheme] = []
        
        // Load built-in themes
        themes.append(contentsOf: loadBuiltInThemes())
        
        // Load user themes
        themes.append(contentsOf: loadUserThemes())
        
        availableThemes = themes
    }
    
    private func loadBuiltInThemes() -> [AwfulTheme] {
        guard let themesURL = Bundle.main.url(forResource: "Themes", withExtension: "plist"),
              let themesPlist = NSDictionary(contentsOf: themesURL) as? [String: [String: Any]] else {
            return []
        }
        
        return themesPlist.compactMap { (name, config) in
            AwfulTheme(
                name: name,
                displayName: config["displayName"] as? String ?? name,
                colors: ThemeColors(from: config["colors"] as? [String: Any] ?? [:]),
                fonts: ThemeFonts(from: config["fonts"] as? [String: Any] ?? [:]),
                css: ThemeCSS()
            )
        }
    }
    
    private func loadUserThemes() -> [AwfulTheme] {
        // Load user-created themes from Documents directory
        return []
    }
    
    func setTheme(_ theme: AwfulTheme) {
        currentTheme = theme
        userDefaults.set(theme.name, forKey: themeKey)
        applyTheme()
    }
    
    private func loadSelectedTheme() {
        let selectedThemeName = userDefaults.string(forKey: themeKey) ?? "default"
        if let theme = availableThemes.first(where: { $0.name == selectedThemeName }) {
            currentTheme = theme
        }
        applyTheme()
    }
    
    private func applyTheme() {
        // Apply theme to global appearance
        updateWindowTintColor()
        updateStatusBarStyle()
    }
    
    private func updateWindowTintColor() {
        // Update window tint color
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.first?.tintColor = UIColor(currentTheme.colors.tint)
        }
    }
    
    private func updateStatusBarStyle() {
        // Update status bar style based on theme
        let style: UIStatusBarStyle = isDarkMode ? .lightContent : .darkContent
        UIApplication.shared.setStatusBarStyle(style, animated: true)
    }
    
    func toggleDarkMode() {
        isDarkMode.toggle()
        applyTheme()
    }
    
    // Forum-specific theme methods
    func colorForForum(_ forumId: String) -> Color {
        return currentTheme.colors.forumColors[forumId] ?? currentTheme.colors.primary
    }
    
    func cssForForum(_ forumId: String) -> String {
        return currentTheme.css.forumCSS[forumId] ?? currentTheme.css.postCSS
    }
}
```

### Phase 3: Theme Environment

Create SwiftUI environment for theming:

```swift
// New ThemeEnvironment.swift
private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = AwfulTheme.default
}

extension EnvironmentValues {
    var theme: AwfulTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// Theme-aware view modifier
struct ThemedView: ViewModifier {
    @EnvironmentObject var themeManager: SwiftUIThemeManager
    
    func body(content: Content) -> some View {
        content
            .environment(\.theme, themeManager.currentTheme)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }
}

extension View {
    func themed() -> some View {
        self.modifier(ThemedView())
    }
}
```

### Phase 4: Theme-Aware Components

Create reusable themed components:

```swift
// New ThemedComponents.swift
struct ThemedButton: View {
    let title: String
    let action: () -> Void
    
    @Environment(\.theme) var theme
    
    var body: some View {
        Button(title, action: action)
            .foregroundColor(theme.colors.primaryText)
            .font(theme.fonts.body)
            .padding()
            .background(theme.colors.primary)
            .cornerRadius(8)
    }
}

struct ThemedTextField: View {
    let placeholder: String
    @Binding var text: String
    
    @Environment(\.theme) var theme
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(theme.fonts.body)
            .foregroundColor(theme.colors.primaryText)
            .padding()
            .background(theme.colors.secondaryBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.colors.separator, lineWidth: 1)
            )
    }
}

struct ThemedNavigationBar: View {
    let title: String
    
    @Environment(\.theme) var theme
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(theme.fonts.title)
                    .foregroundColor(theme.colors.primaryText)
                Spacer()
            }
            .padding()
            .background(theme.colors.background)
            
            Divider()
                .background(theme.colors.separator)
        }
    }
}
```

### Phase 5: Web View Theme Integration

Bridge SwiftUI themes with web view CSS:

```swift
// New WebViewThemeManager.swift
class WebViewThemeManager: ObservableObject {
    @Published var currentCSS: String = ""
    
    private let themeManager: SwiftUIThemeManager
    
    init(themeManager: SwiftUIThemeManager) {
        self.themeManager = themeManager
        updateCSS()
        
        // Listen for theme changes
        themeManager.$currentTheme
            .sink { [weak self] _ in
                self?.updateCSS()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func updateCSS() {
        currentCSS = generateCSS(from: themeManager.currentTheme)
    }
    
    private func generateCSS(from theme: AwfulTheme) -> String {
        let colors = theme.colors
        let fonts = theme.fonts
        
        return """
        :root {
            --primary-color: \(colors.primary.hex);
            --secondary-color: \(colors.secondary.hex);
            --background-color: \(colors.background.hex);
            --text-color: \(colors.primaryText.hex);
            --separator-color: \(colors.separator.hex);
            --tint-color: \(colors.tint.hex);
            
            --body-font: \(fonts.body.description);
            --title-font: \(fonts.title.description);
        }
        
        body {
            background-color: var(--background-color);
            color: var(--text-color);
            font-family: var(--body-font);
        }
        
        .post {
            background-color: var(--background-color);
            border-color: var(--separator-color);
        }
        
        .thread-title {
            color: var(--text-color);
            font-family: var(--title-font);
        }
        
        a {
            color: var(--tint-color);
        }
        
        \(theme.css.postCSS)
        """
    }
    
    func cssForForum(_ forumId: String) -> String {
        let baseCSS = currentCSS
        let forumCSS = themeManager.cssForForum(forumId)
        return baseCSS + "\n" + forumCSS
    }
}

// Color extension for hex conversion
extension Color {
    var hex: String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        return String(format: "#%02X%02X%02X", 
                      Int(r * 255), 
                      Int(g * 255), 
                      Int(b * 255))
    }
}
```

## Migration Steps

### Step 1: Create Theme Foundation (Week 1)
1. **Create Theme Structures**: Define SwiftUI theme data structures
2. **Migrate Theme Data**: Convert plist themes to Swift structures
3. **Create Theme Manager**: Observable theme management
4. **Test Theme Loading**: Verify themes load correctly

### Step 2: Environment Integration (Week 1)
1. **Create Theme Environment**: SwiftUI environment integration
2. **Create Theme Modifiers**: Reusable theme application
3. **Test Theme Switching**: Verify runtime theme changes
4. **Update App Structure**: Integrate theme environment

### Step 3: Component Migration (Week 2)
1. **Create Themed Components**: Reusable themed UI elements
2. **Convert Existing Views**: Apply themes to existing views
3. **Test Visual Consistency**: Verify theme application
4. **Handle Edge Cases**: Special theme behaviors

### Step 4: Web View Integration (Week 2)
1. **Create CSS Generation**: Convert themes to CSS
2. **Integrate with Web Views**: Apply themes to web content
3. **Test Forum-Specific Themes**: Verify custom forum styling
4. **Handle Dynamic Updates**: Theme changes in web views

## Custom Theme Features

### Forum-Specific Theming
```swift
// Forum-specific theme handling
struct ForumThemedView: View {
    let forum: Forum
    
    @EnvironmentObject var themeManager: SwiftUIThemeManager
    @Environment(\.theme) var theme
    
    var body: some View {
        VStack {
            // Use forum-specific colors
            Text(forum.name)
                .foregroundColor(themeManager.colorForForum(forum.id))
                .font(theme.fonts.title)
        }
        .background(theme.colors.background)
    }
}
```

### Dynamic Theme Creation
```swift
// User-created theme support
extension SwiftUIThemeManager {
    func createCustomTheme(name: String, baseTheme: AwfulTheme) -> AwfulTheme {
        // Create custom theme based on existing theme
        return AwfulTheme(
            name: name,
            displayName: name,
            colors: baseTheme.colors,
            fonts: baseTheme.fonts,
            css: baseTheme.css
        )
    }
    
    func saveCustomTheme(_ theme: AwfulTheme) {
        // Save custom theme to user documents
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(theme) {
            // Save to file system
        }
    }
}
```

## Risk Mitigation

### High-Risk Areas
1. **CSS Generation**: Converting themes to web CSS
2. **Color Conversion**: UIColor to SwiftUI Color conversion
3. **Font Mapping**: Font system differences
4. **Performance**: Theme switching performance

### Mitigation Strategies
1. **Gradual Migration**: Migrate themes incrementally
2. **Fallback Themes**: Ensure default themes always work
3. **Performance Testing**: Monitor theme switching performance
4. **Visual Validation**: Compare themed views pixel-by-pixel

## Testing Strategy

### Unit Tests
```swift
// ThemeTests.swift
class ThemeTests: XCTestCase {
    var themeManager: SwiftUIThemeManager!
    
    override func setUp() {
        themeManager = SwiftUIThemeManager()
    }
    
    func testThemeLoading() {
        XCTAssertFalse(themeManager.availableThemes.isEmpty)
        XCTAssertNotNil(themeManager.currentTheme)
    }
    
    func testThemeSwitching() {
        let initialTheme = themeManager.currentTheme
        let newTheme = themeManager.availableThemes.first { $0.name != initialTheme.name }
        
        if let newTheme = newTheme {
            themeManager.setTheme(newTheme)
            XCTAssertEqual(themeManager.currentTheme, newTheme)
        }
    }
    
    func testForumSpecificColors() {
        let forumColor = themeManager.colorForForum("YOSPOS")
        XCTAssertNotNil(forumColor)
    }
}
```

### Visual Tests
```swift
// ThemeVisualTests.swift
class ThemeVisualTests: XCTestCase {
    func testThemeConsistency() {
        // Compare themed views across different themes
        // Verify visual consistency
    }
    
    func testWebViewThemeIntegration() {
        // Test CSS generation and web view theming
        // Verify web content matches native theme
    }
}
```

## Performance Considerations

### Memory Management
- Use `@State` for local theme-related state
- Use `@EnvironmentObject` for shared theme manager
- Implement proper theme caching

### Theme Switching Performance
- Minimize theme-dependent computations
- Use lazy loading for theme resources
- Implement efficient color/font caching

### CSS Generation Efficiency
- Cache generated CSS strings
- Use incremental CSS updates
- Optimize CSS compilation

## Timeline Estimation

### Conservative Estimate: 2 weeks
- **Week 1**: Theme foundation and environment
- **Week 2**: Component migration and web view integration

### Aggressive Estimate: 1 week
- Assumes simple theme migration
- Minimal custom theme features
- No performance optimization needed

## Dependencies

### Internal Dependencies
- SwiftUIThemeManager: Core theme management
- Theme Data Structures: Theme definitions
- WebViewThemeManager: Web view integration

### External Dependencies
- SwiftUI: UI framework
- Combine: Reactive programming
- Foundation: Core functionality

## Success Criteria

### Functional Requirements
- [ ] All existing themes work identically
- [ ] Runtime theme switching works
- [ ] Forum-specific themes work
- [ ] Web view theming works
- [ ] Custom theme creation works

### Technical Requirements
- [ ] Theme state properly managed with ObservableObject
- [ ] No memory leaks during theme switching
- [ ] Efficient CSS generation
- [ ] Proper color/font conversion
- [ ] Thread-safe theme operations

### Visual Requirements
- [ ] Pixel-perfect theme reproduction
- [ ] Consistent theming across views
- [ ] Proper dark/light mode support
- [ ] Forum-specific visual styles
- [ ] Smooth theme transitions

## Migration Checklist

### Pre-Migration
- [ ] Review current theme system
- [ ] Identify all themed components
- [ ] Document theme requirements
- [ ] Prepare visual comparison tests

### During Migration
- [ ] Create theme data structures
- [ ] Implement theme manager
- [ ] Convert themed components
- [ ] Integrate web view theming
- [ ] Test theme switching

### Post-Migration
- [ ] Verify visual consistency
- [ ] Test all available themes
- [ ] Validate performance
- [ ] Update documentation
- [ ] Deploy to beta testing

This migration guide provides a comprehensive approach to converting the theming system while maintaining all existing visual design and custom behaviors.