# Theme Architecture Overview

## Introduction

Awful.app's theming system is one of the most sophisticated theming implementations in iOS development, providing a unified approach to styling both native UIKit components and web-based content. The architecture seamlessly integrates:

- **Native UI theming** through the Theme class and Themeable protocol
- **CSS generation** via Less compilation for web views
- **Dynamic theme switching** with real-time updates
- **Forum-specific customization** that automatically applies context-aware themes
- **Hierarchical inheritance** reducing duplication and enabling efficient overrides

## Core Architecture Components

### 1. Theme Class (`AwfulTheming/Sources/AwfulTheming/Themes.swift`)

The `Theme` class is the foundation of the entire system:

```swift
public class Theme {
    public let name: String
    fileprivate let dictionary: [String: Any]
    fileprivate var parent: Theme?
    
    // Theme mode (light/dark)
    public enum Mode: CaseIterable, Hashable {
        case light, dark
    }
}
```

**Key Features:**
- **Property-based access**: Uses subscript operators for type-safe property retrieval
- **Inheritance chain**: Themes inherit from parent themes up to the root "default" theme
- **Dictionary flattening**: Nested dictionaries in Themes.plist are automatically flattened
- **CSS integration**: Automatically loads and compiles CSS files referenced in theme properties

### 2. Themeable Protocol

```swift
public protocol Themeable {
    var theme: Theme { get }
    func themeDidChange()
}
```

The protocol ensures consistent theming across all UI components:

- **Automatic updates**: `themeDidChange()` called when themes change
- **Lazy evaluation**: Themes computed on-demand for performance
- **Context awareness**: Different view controllers can use different themes

### 3. Theme Data Source (Themes.plist)

Located at `AwfulTheming/Sources/AwfulTheming/Themes.plist`, this file defines:

```xml
<dict>
    <key>default</key>
    <dict>
        <!-- Root theme with all base properties -->
    </dict>
    
    <key>dark</key>
    <dict>
        <key>parent</key>
        <string>default</string>
        <!-- Dark mode overrides -->
    </dict>
    
    <key>yospos</key>
    <dict>
        <key>parent</key>
        <string>dark</string>
        <key>relevantForumID</key>
        <string>219</string>
        <!-- Forum-specific customizations -->
    </dict>
</dict>
```

## Theme Inheritance Hierarchy

### Inheritance Chain Resolution

The theme system uses a sophisticated inheritance chain:

```
Custom Theme → Forum Theme → Base Theme → Default Theme
```

**Example Resolution Path:**
```
YOSPOS → dark → default
```

**Property Lookup Algorithm:**
1. Check current theme's dictionary
2. If not found, check parent theme recursively
3. Continue until property found or reach root theme
4. Fatal error if property not found in entire chain

### Performance Optimizations

- **Lazy loading**: Themes loaded only when first accessed
- **Caching**: Bundled themes cached at app launch
- **Dictionary flattening**: Nested dictionaries preprocessed for O(1) access
- **Property validation**: Theme validation happens at load time, not access time

## Theme Property Categories

### 1. Colors (`xxxColor`)

```swift
// Theme property definition
"listTextColor": "#000000"

// Runtime access
let textColor: UIColor = theme["listTextColor"]!
```

**Color Resolution:**
- Hex codes (#RRGGBB, #RRGGBBAA)
- Pattern images (for textured backgrounds)
- Automatic UIColor/SwiftUI Color conversion

### 2. CSS Files (`xxxCSS`)

```swift
// Theme property
"postsViewCSS": "posts-view-yospos.less"

// Automatic CSS compilation
let css: String = theme["postsViewCSS"]!
```

**CSS Processing:**
- Less files automatically compiled to CSS
- Variable substitution from theme properties
- Bundle resource loading with error handling

### 3. Fonts (`xxxFont`)

```swift
// Complex font specification
"listFont": {
    "fontName": "Helvetica-Bold",
    "fontSize": 16.0,
    "fontWeight": "semibold"
}
```

### 4. Boolean Flags (`xxxBoolean`)

```swift
"showRootTabBarLabel": true
"postsViewInvertedColors": false
```

### 5. Special Properties

- **`parent`**: Inheritance chain specification
- **`relevantForumID`**: Auto-application to specific forums
- **`descriptiveName`**: Human-readable theme name
- **`descriptiveColor`**: Theme picker color representation
- **`mode`**: Light/dark mode designation

## Dynamic Theme Application

### 1. Theme Manager System

```swift
// Get current theme for forum context
let theme = Theme.currentTheme(for: ForumID("219"))

// Apply to view controller
viewController.theme = theme
viewController.themeDidChange()
```

### 2. Real-Time Updates

When themes change, the system:

1. **Broadcasts notification**: `Theme.themeForForumDidChangeNotification`
2. **Updates all Themeable objects**: Automatic `themeDidChange()` calls
3. **Reloads web content**: CSS regenerated and injected
4. **Persists preferences**: Theme selections saved to UserDefaults

### 3. Context-Aware Theme Selection

```swift
// Forum-specific theme resolution
private static func themeNameForForum(identifiedBy forumID: String, mode: Mode) -> String? {
    return UserDefaults.standard.string(forKey: defaultsKeyForForum(identifiedBy: forumID, mode: mode))
}

// Automatic forum theme defaults
public static var forumSpecificDefaults: [String: Any] {
    return [
        "theme-dark-219": "YOSPOS",    // YOSPOS forum
        "theme-light-219": "YOSPOS",
        "theme-dark-26": "FYAD",       // FYAD forum
        "theme-light-26": "FYAD"
    ]
}
```

## CSS Integration Architecture

### 1. Less Compilation Pipeline

```
Theme Property → Less File → CSS Compilation → Runtime Injection
```

**Build Process:**
1. **Build plugin**: `LessStylesheet` package processes `.less` files
2. **Variable injection**: Theme properties available as Less variables
3. **Import resolution**: `@import` statements resolved from bundle
4. **Output generation**: Compiled CSS bundled with app

### 2. Runtime CSS Loading

```swift
// Theme CSS property access
public subscript(string key: String) -> String? {
    guard let value = dictionary[key] as? String ?? parent?[key] else { return nil }
    if key.hasSuffix("CSS") {
        let css: String?
        do {
            css = try stylesheet(named: value)
        } catch {
            fatalError("Could not find CSS file \(value)")
        }
        return css
    }
    return value
}
```

### 3. Web View Integration

Posts are rendered in WKWebView with theme-aware CSS:

```swift
// PostsPageViewController theme integration
override var theme: Theme {
    guard let forum = thread.forum, !forum.forumID.isEmpty else {
        return Theme.defaultTheme()
    }
    return Theme.currentTheme(for: ForumID(forum.forumID))
}
```

The web view receives:
- **Base CSS**: Common styling rules
- **Theme CSS**: Theme-specific overrides
- **JavaScript integration**: Dynamic theme switching without page reload

## Storage and Persistence

### 1. Theme Selection Storage

```swift
// Per-forum, per-mode storage
public static func defaultsKeyForForum(identifiedBy forumID: String, mode: Mode) -> String {
    switch mode {
    case .light:
        return "theme-light-\(forumID)"
    case .dark:
        return "theme-dark-\(forumID)"
    }
}
```

### 2. Default Theme Management

```swift
@FoilDefaultStorage(Settings.defaultDarkThemeName) private static var defaultDarkTheme
@FoilDefaultStorage(Settings.defaultLightThemeName) private static var defaultLightTheme
```

Uses the FOIL package for type-safe UserDefaults access with automatic change notifications.

## Performance Characteristics

### 1. Load Time Optimizations

- **Bundle parsing**: Themes.plist parsed once at app launch
- **Dictionary flattening**: O(n) preprocessing for O(1) runtime access
- **Parent chain caching**: Inheritance resolved once per theme

### 2. Memory Usage

- **Shared instances**: Single Theme instance per theme name
- **Lazy CSS loading**: CSS compiled only when first accessed
- **Property caching**: No redundant property resolution

### 3. Update Performance

- **Incremental updates**: Only changed components receive updates
- **Batch processing**: Multiple theme changes batched together
- **Background processing**: CSS compilation happens off main thread when possible

## Error Handling and Validation

### 1. Theme Validation

```swift
// Compile-time validation
guard let theme = bundledThemes[themeName] else {
    return bundledThemes["default"]! // Fallback to default
}
```

### 2. Property Validation

```swift
// Runtime property validation with descriptive errors
guard let hexColor = UIColor(hex: value) else {
    fatalError("Unrecognized theme attribute color: \(value) (in theme \(name), for key \(colorName)")
}
```

### 3. CSS Loading Validation

```swift
// CSS file existence validation
guard let url = Bundle.module.url(forResource: name, withExtension: ".css") else {
    return nil
}
```

## Extension Points

### 1. Custom Theme Properties

Add new properties to themes by:
1. Adding property to default theme in Themes.plist
2. Creating accessor method in Theme class
3. Using property in UI components

### 2. Custom Themeable Components

```swift
class CustomView: UIView, Themeable {
    var theme: Theme { Theme.defaultTheme() }
    
    func themeDidChange() {
        backgroundColor = theme["customBackgroundColor"]
        layer.borderColor = theme["customBorderColor"]?.cgColor
    }
}
```

### 3. Dynamic Theme Creation

Themes can be created at runtime, though the current implementation focuses on bundle-based themes for performance and validation.

## Testing Strategy

### 1. Theme Inheritance Testing

Verify inheritance chains resolve correctly:

```swift
func testThemeInheritance() {
    let theme = Theme.theme(named: "yospos")!
    // Should inherit from dark → default chain
    XCTAssertEqual(theme["backgroundColor"], dark_theme_color)
}
```

### 2. CSS Compilation Testing

Ensure Less files compile correctly and variable substitution works.

### 3. Performance Testing

Monitor theme switching performance, especially with complex CSS compilation.

## SwiftUI Migration Considerations

The current architecture provides a solid foundation for SwiftUI migration:

1. **Environment integration**: Theme can be provided via SwiftUI Environment
2. **View modifier pattern**: Current property-based access maps well to view modifiers
3. **Dynamic updates**: SwiftUI's reactive nature aligns with current change notification system

This architecture demonstrates how thoughtful design can create a powerful, flexible, and performant theming system that scales from simple color changes to complex forum-specific customizations while maintaining excellent performance characteristics.