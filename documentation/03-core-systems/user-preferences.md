# User Preferences System

## Overview

Awful.app uses a sophisticated preferences system built around the FOIL package, providing type-safe, reactive UserDefaults access with comprehensive migration support. The system seamlessly bridges UIKit and SwiftUI while maintaining backward compatibility.

## Architecture

```
Settings.swift (Registry) ──┐
                          ├─→ @FoilDefaultStorage (UIKit)
                          ├─→ @AppStorage (SwiftUI)
                          └─→ Migration System
                               │
Themes.plist ──────────────┘
ForumTweaks.plist
```

## The FOIL Package

### What is FOIL?

**External Dependency**: [Jesse Squires' Foil package](http://github.com/jessesquires/Foil) v5.0.1

**Core Features**:
- Type-safe UserDefaults access via property wrappers
- Automatic default value registration
- Combine publisher support for reactive programming
- Support for both optional and non-optional values

### Property Wrappers

**@FoilDefaultStorage**: For non-optional values with defaults
```swift
@FoilDefaultStorage(Settings.autoDarkTheme) private var autoDarkTheme
// Automatically uses default value: true
```

**@FoilDefaultStorageOptional**: For optional values
```swift
@FoilDefaultStorageOptional(Settings.userID) private var loggedInUserID
// Can be nil
```

**Reactive Updates**: Access publisher via projected value
```swift
$autoDarkTheme.sink { newValue in
    // React to changes
}
```

## Settings Registry

### Settings.swift Structure

**Location**: `AwfulSettings/Sources/AwfulSettings/Settings.swift`

**Core Pattern**:
```swift
public enum Settings {
    // String optional setting
    public static let appIconName = Setting<String?>(key: "app_icon_name")
    
    // Boolean with default
    public static let autoDarkTheme = Setting(key: "auto_dark_theme", default: true)
    
    // Double with default
    public static let fontScale = Setting(key: "font_scale", default: 100.0)
    
    // Custom enum with default
    public static let defaultBrowser = Setting(
        key: "default_browser", 
        default: DefaultBrowser.default
    )
}
```

### Setting Types

**Basic Types**: String, Bool, Int, Double, Float
**Custom Enums**: BuiltInTheme, DefaultBrowser, ImgurUploadMode
**Optional Types**: Any type can be optional

**Example Enum Setting**:
```swift
public enum DefaultBrowser: String, CaseIterable {
    case `default` = "default"
    case chrome = "chrome"
    case firefox = "firefox"
    case edge = "edge"
}
```

## Plist Configuration Files

### Themes.plist

**Location**: `AwfulTheming/Sources/AwfulTheming/Themes.plist`

**Structure**: Nested dictionaries defining theme properties
```xml
<dict>
    <key>dark</key>
    <dict>
        <key>descriptiveName</key>
        <string>Dark</string>
        <key>relevantForumsPattern</key>
        <string>.*</string>
        <key>parent</key>
        <string>light</string>
        <!-- Color and font definitions -->
    </dict>
</dict>
```

**Key Features**:
- **Theme Inheritance**: `parent` key allows theme extension
- **Forum Patterns**: `relevantForumsPattern` regex for forum-specific themes
- **Color Definitions**: Hex colors for light/dark modes
- **Font Specifications**: Typography settings
- **CSS References**: Stylesheet associations

### ForumTweaks.plist

**Location**: `AwfulTheming/Sources/AwfulTheming/ForumTweaks.plist`

**Purpose**: Forum-specific behavior modifications
```xml
<dict>
    <key>26</key> <!-- Forum ID -->
    <dict>
        <key>autocorrectionType</key>
        <string>no</string>
        <key>spellCheckingType</key>
        <string>no</string>
    </dict>
</dict>
```

**Controls**:
- Spell checking per forum
- Autocorrection behavior
- Autocapitalization settings
- Custom keyboard configurations

## Migration System

### Migration Architecture

**Location**: `AwfulSettings/Sources/AwfulSettings/Migration.swift`

**Trigger**: Called during app startup
```swift
// In AppDelegate
SettingsMigration.migrate(.standard)
```

### Migration Types

#### 1. UserDefaults to UserDefaults

**YOSPOS Style Migration**:
```swift
func migrateYOSPOSStyle() {
    // Convert old single theme key to light/dark keys
    if let oldTheme = UserDefaults.standard.string(forKey: "theme") {
        UserDefaults.standard.set(oldTheme + "-light", forKey: "theme-light")
        UserDefaults.standard.set(oldTheme + "-dark", forKey: "theme-dark")
        UserDefaults.standard.removeObject(forKey: "theme")
    }
}
```

**Forum Theme Migration**:
```swift
func migrateForumSpecificThemes() {
    // Update forum-specific theme keys for light/dark support
    for (forumID, theme) in oldForumThemes {
        let newKey = "theme-\(forumID)-light"
        UserDefaults.standard.set(theme, forKey: newKey)
    }
}
```

#### 2. UserDefaults to Core Data

**Favorite Forums Migration**:
```swift
func migrateFavoriteForums() {
    if let favoriteForumIDs = UserDefaults.standard.array(forKey: "favorite_forums") {
        // Create Core Data entities for each favorite
        for forumID in favoriteForumIDs {
            createFavoriteForumEntity(forumID: forumID)
        }
        UserDefaults.standard.removeObject(forKey: "favorite_forums")
    }
}
```

### Migration Strategy

**Version Tracking**: Uses internal version numbers
**Incremental Migrations**: Each migration targets specific version ranges
**Rollback Safety**: Preserves original data until migration confirmed
**Error Handling**: Graceful fallbacks for migration failures

## SwiftUI Integration

### AppStorage Bridge

**Location**: `AwfulSettings/Sources/AwfulSettings/AppStorage+Setting.swift`

**Custom Initializers**:
```swift
public extension AppStorage {
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == Bool {
        self.init(wrappedValue: setting.default, setting.key, store: store)
    }
    
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == Double {
        self.init(wrappedValue: setting.default, setting.key, store: store)
    }
    
    // Additional type-specific initializers...
}
```

**Usage in SwiftUI**:
```swift
struct SettingsView: View {
    @AppStorage(Settings.autoplayGIFs) private var alwaysAnimateGIFs
    @AppStorage(Settings.fontScale) private var fontScale
    
    var body: some View {
        Toggle("Autoplay GIFs", isOn: $alwaysAnimateGIFs)
        Slider(value: $fontScale, in: 75...150)
    }
}
```

### Hybrid Architecture

**UIKit Controllers**: Use `@FoilDefaultStorage` for reactive updates
**SwiftUI Views**: Use `@AppStorage` for native integration
**Shared Data**: Both access same UserDefaults keys

## Theme Integration

### Dynamic Theme Switching

**Settings**:
- `Settings.autoDarkTheme`: Automatic light/dark switching
- `Settings.darkMode`: Manual dark mode override
- Forum-specific theme overrides

**Implementation**:
```swift
@FoilDefaultStorage(Settings.autoDarkTheme) private var autoDarkTheme
@FoilDefaultStorage(Settings.darkMode) private var darkMode

var effectiveTheme: String {
    if autoDarkTheme {
        return UITraitCollection.current.userInterfaceStyle == .dark ? "dark" : "light"
    } else {
        return darkMode ? "dark" : "light"
    }
}
```

### Forum-Specific Themes

**Pattern**: Each forum can have custom light/dark themes
**Storage**: `theme-{forumID}-{mode}` UserDefaults keys
**Fallback**: Forum themes inherit from base themes via plist parent system

## Migration to AppStorage Considerations

### Current State Analysis

**Pros of Current System**:
- Reactive updates via Combine publishers
- Type safety with custom Setting types
- Comprehensive migration framework
- Proven reliability over years of use

**Pros of AppStorage Migration**:
- Native SwiftUI integration
- Fewer dependencies (removes FOIL)
- Simpler property wrapper syntax
- Apple-supported long-term

### Migration Strategy

#### Phase 1: Assessment (Current)
- Keep FOIL for complex reactive scenarios
- Use AppStorage for simple SwiftUI-only preferences
- Bridge between systems using existing pattern

#### Phase 2: Gradual Migration
- Replace simple boolean/string preferences with AppStorage
- Maintain FOIL for complex enum types
- Keep reactive updates where needed

#### Phase 3: Complete Migration (Future)
- Custom reactive wrapper around AppStorage
- Migrate all settings to AppStorage
- Remove FOIL dependency

### Implementation Recommendation

**For SwiftUI Migration**: Keep current system initially
**Reason**: 
1. System is working well
2. Migration framework is valuable
3. Reactive updates are heavily used
4. Risk vs. benefit doesn't justify immediate change

**Future Enhancement**: Consider AppStorage when:
- Combine usage significantly reduced
- All UI migrated to SwiftUI
- Migration framework no longer needed

## Testing Preferences

### Unit Testing

```swift
func testSettingDefault() {
    let testDefaults = UserDefaults(suiteName: "test")
    XCTAssertEqual(Settings.autoDarkTheme.defaultValue, true)
}

func testSettingMigration() {
    // Test migration logic
    let testDefaults = UserDefaults(suiteName: "test")
    testDefaults.set("old_value", forKey: "old_key")
    
    runMigration(testDefaults)
    
    XCTAssertNil(testDefaults.object(forKey: "old_key"))
    XCTAssertEqual(testDefaults.string(forKey: "new_key"), "migrated_value")
}
```

### Integration Testing

```swift
func testThemePreferences() {
    // Test theme switching with preferences
    Settings.darkMode.set(true)
    XCTAssertEqual(ThemeManager.current.name, "dark")
}
```

## Best Practices

### Adding New Settings

1. **Define in Settings.swift**:
```swift
public static let newFeature = Setting(key: "new_feature", default: false)
```

2. **Add migration if needed**:
```swift
func migrateNewFeature() {
    // Handle old data format
}
```

3. **Use appropriate wrapper**:
```swift
// UIKit
@FoilDefaultStorage(Settings.newFeature) private var newFeature

// SwiftUI
@AppStorage(Settings.newFeature) private var newFeature
```

### Debugging Preferences

**View Current Values**:
```swift
for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
    print("\(key): \(value)")
}
```

**Reset All Preferences**:
```swift
UserDefaults.standard.removeAllObjectsInMainBundleDomain()
```

## Files to Monitor

**Core Files**:
- `AwfulSettings/Sources/AwfulSettings/Settings.swift`
- `AwfulSettings/Sources/AwfulSettings/Migration.swift`
- `AwfulTheming/Sources/AwfulTheming/Themes.plist`
- `AwfulTheming/Sources/AwfulTheming/ForumTweaks.plist`

**Integration Files**:
- `AwfulSettings/Sources/AwfulSettings/AppStorage+Setting.swift`
- Any view controllers using `@FoilDefaultStorage`
- SwiftUI views using `@AppStorage`

## Summary

The user preferences system in Awful.app is a well-architected solution that successfully bridges UIKit and SwiftUI while providing type safety, migration support, and reactive programming capabilities. The system's maturity and reliability make it a strong foundation for the SwiftUI migration, with minimal changes needed to support modern development patterns.
