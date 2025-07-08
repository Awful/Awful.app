# Themes.plist Complete Documentation

## Overview

The `Themes.plist` file is the heart of Awful.app's theming system. This comprehensive document explains every property, theme, and customization option available.

**Location**: `AwfulTheming/Sources/AwfulTheming/Themes.plist`

## Theme Structure

### Core Properties

Every theme can define these fundamental properties:

```xml
<dict>
    <key>descriptiveName</key>
    <string>Human-readable theme name</string>
    
    <key>mode</key>
    <string>light|dark</string>
    
    <key>parent</key>
    <string>Parent theme for inheritance</string>
    
    <key>relevantForumID</key>
    <string>Forum ID this theme applies to</string>
    
    <key>descriptiveColor</key>
    <string>#RRGGBB color for theme picker</string>
    
    <key>keyboardAppearance</key>
    <string>Light|Dark</string>
    
    <key>scrollIndicatorStyle</key>
    <string>Dark|Light</string>
    
    <key>roundedFonts</key>
    <boolean>Use rounded system fonts</boolean>
</dict>
```

### Theme Categories

Themes are organized into logical UI categories:

#### Lists (Table Views)
```xml
<key>listTextColor</key>
<string>#000000</string>

<key>listSecondaryTextColor</key>
<string>#666666</string>

<key>listBackgroundColor</key>
<string>#FFFFFF</string>

<key>listSelectedBackgroundColor</key>
<string>#E6E6E6</string>

<key>listSeparatorColor</key>
<string>#CCCCCC</string>

<key>listHeaderBackgroundColor</key>
<string>#F7F7F7</string>

<key>listHeaderTextColor</key>
<string>#333333</string>
```

#### Posts (Web Content)
```xml
<key>postsViewCSS</key>
<string>posts-view.less</string>

<key>backgroundColor</key>
<string>#FFFFFF</string>

<key>postsViewInvertedColors</key>
<boolean>false</boolean>

<key>externalStylesheetURL</key>
<string>Optional remote CSS URL</string>
```

#### Navigation Elements
```xml
<key>navbarTintColor</key>
<string>#007AFF</string>

<key>navbarTitleTextColor</key>
<string>#000000</string>

<key>toolbarTintColor</key>
<string>#007AFF</string>

<key>tabBarTintColor</key>
<string>#007AFF</string>

<key>showRootTabBarLabel</key>
<boolean>true</boolean>
```

#### Action Icons
```xml
<key>settingsIconTintColor</key>
<string>#666666</string>

<key>composeIconTintColor</key>
<string>#007AFF</string>

<key>searchIconTintColor</key>
<string>#666666</string>

<key>favoriteIconTintColor</key>
<string>#FFD700</string>

<key>bookmarkIconTintColor</key>
<string>#007AFF</string>
```

## Built-in Themes

### Base Themes

#### Default (Root Theme)
```xml
<key>default</key>
<dict>
    <key>descriptiveName</key>
    <string>Default</string>
    
    <key>mode</key>
    <string>light</string>
    
    <!-- All default values defined here -->
    <key>listTextColor</key>
    <string>#000000</string>
    
    <key>backgroundColor</key>
    <string>#FFFFFF</string>
    
    <!-- ... complete default color palette ... -->
</dict>
```

#### Light Theme
```xml
<key>light</key>
<dict>
    <key>descriptiveName</key>
    <string>Light</string>
    
    <key>parent</key>
    <string>default</string>
    
    <key>mode</key>
    <string>light</string>
    
    <key>descriptiveColor</key>
    <string>#E6E6E6</string>
    
    <!-- Overrides for light mode -->
</dict>
```

#### Dark Theme
```xml
<key>dark</key>
<dict>
    <key>descriptiveName</key>
    <string>Dark</string>
    
    <key>parent</key>
    <string>default</string>
    
    <key>mode</key>
    <string>dark</string>
    
    <key>descriptiveColor</key>
    <string>#333333</string>
    
    <!-- Dark mode color overrides -->
    <key>listTextColor</key>
    <string>#FFFFFF</string>
    
    <key>backgroundColor</key>
    <string>#000000</string>
    
    <key>keyboardAppearance</key>
    <string>Dark</string>
</dict>
```

#### OLED Theme
```xml
<key>oled</key>
<dict>
    <key>descriptiveName</key>
    <string>OLED</string>
    
    <key>parent</key>
    <string>dark</string>
    
    <key>descriptiveColor</key>
    <string>#000000</string>
    
    <!-- True black for OLED displays -->
    <key>backgroundColor</key>
    <string>#000000</string>
    
    <key>listBackgroundColor</key>
    <string>#000000</string>
</dict>
```

### Forum-Specific Themes

#### YOSPOS (You Only Screenshot Posts Once)
```xml
<key>yospos</key>
<dict>
    <key>descriptiveName</key>
    <string>YOSPOS</string>
    
    <key>parent</key>
    <string>dark</string>
    
    <key>relevantForumID</key>
    <string>219</string>
    
    <key>descriptiveColor</key>
    <string>#57ff57</string>
    
    <!-- Terminal green aesthetic -->
    <key>listTextColor</key>
    <string>#57ff57</string>
    
    <key>backgroundColor</key>
    <string>#000000</string>
    
    <key>postsViewCSS</key>
    <string>posts-view-yospos.less</string>
    
    <!-- Custom loading animation -->
    <key>loadingViewType</key>
    <string>macinyos</string>
    
    <!-- Retro fonts -->
    <key>listFont</key>
    <dict>
        <key>fontName</key>
        <string>Courier</string>
        <key>fontSize</key>
        <real>14</real>
    </dict>
</dict>
```

#### FYAD (F*** You And Die)
```xml
<key>fyad</key>
<dict>
    <key>descriptiveName</key>
    <string>FYAD</string>
    
    <key>parent</key>
    <string>light</string>
    
    <key>relevantForumID</key>
    <string>26</string>
    
    <key>descriptiveColor</key>
    <string>#ff3399</string>
    
    <!-- Pink/hot pink color scheme -->
    <key>listTextColor</key>
    <string>#000000</string>
    
    <key>navbarTintColor</key>
    <string>#fd9a9a</string>
    
    <key>composeIconTintColor</key>
    <string>#ff3399</string>
    
    <key>postsViewCSS</key>
    <string>posts-view-fyad.less</string>
</dict>
```

#### BYOB (Bring Your Own Book)
```xml
<key>byob</key>
<dict>
    <key>descriptiveName</key>
    <string>BYOB</string>
    
    <key>parent</key>
    <string>light</string>
    
    <key>relevantForumID</key>
    <string>268</string>
    
    <key>descriptiveColor</key>
    <string>#9999ff</string>
    
    <!-- Chill blue theme -->
    <key>postsViewCSS</key>
    <string>posts-view-byob.less</string>
    
    <key>listFont</key>
    <dict>
        <key>fontName</key>
        <string>ChalkboardSE-Regular</string>
        <key>fontSize</key>
        <real>16</real>
    </dict>
</dict>
```

#### Gas Chamber
```xml
<key>Gas Chamber</key>
<dict>
    <key>descriptiveName</key>
    <string>Gas Chamber</string>
    
    <key>parent</key>
    <string>light</string>
    
    <key>relevantForumID</key>
    <string>25</string>
    
    <key>descriptiveColor</key>
    <string>#68cc24</string>
    
    <!-- Sickly green theme -->
    <key>postsViewCSS</key>
    <string>posts-view-gas-chamber.less</string>
</dict>
```

### Retro Themes

#### Macinyos (Classic Mac OS)
```xml
<key>macinyos</key>
<dict>
    <key>descriptiveName</key>
    <string>Macinyos</string>
    
    <key>parent</key>
    <string>light</string>
    
    <key>relevantForumID</key>
    <string>219</string>
    
    <key>descriptiveColor</key>
    <string>#C0C0C0</string>
    
    <!-- Classic Mac OS aesthetic -->
    <key>postsViewCSS</key>
    <string>posts-view-macinyos.less</string>
    
    <key>loadingViewType</key>
    <string>macinyos</string>
    
    <!-- Retro typography -->
    <key>listFont</key>
    <dict>
        <key>fontName</key>
        <string>Chicago</string>
        <key>fontSize</key>
        <real>12</real>
    </dict>
</dict>
```

#### Winpos 95 (Windows 95)
```xml
<key>winpos95</key>
<dict>
    <key>descriptiveName</key>
    <string>Winpos 95</string>
    
    <key>parent</key>
    <string>light</string>
    
    <key>relevantForumID</key>
    <string>219</string>
    
    <key>descriptiveColor</key>
    <string>#008080</string>
    
    <!-- Windows 95 aesthetic -->
    <key>postsViewCSS</key>
    <string>posts-view-winpos95.less</string>
    
    <key>loadingViewType</key>
    <string>winpos95</string>
</dict>
```

#### Green Amber (Terminal Theme)
```xml
<key>green-amber</key>
<dict>
    <key>descriptiveName</key>
    <string>Green Amber</string>
    
    <key>parent</key>
    <string>dark</string>
    
    <key>descriptiveColor</key>
    <string>#00ff00</string>
    
    <!-- Terminal/Matrix aesthetic -->
    <key>listTextColor</key>
    <string>#00ff00</string>
    
    <key>backgroundColor</key>
    <string>#000000</string>
    
    <key>listFont</key>
    <dict>
        <key>fontName</key>
        <string>Monaco</string>
        <key>fontSize</key>
        <real>13</real>
    </dict>
</dict>
```

## Advanced Features

### Theme Inheritance

Themes inherit from parent themes using the `parent` key:

```xml
<!-- Child theme -->
<key>custom-theme</key>
<dict>
    <key>parent</key>
    <string>dark</string>
    
    <!-- Only override specific properties -->
    <key>listTextColor</key>
    <string>#FF0000</string>
    
    <!-- All other properties inherited from dark theme -->
</dict>
```

**Inheritance Chain Example**:
```
custom-theme → dark → default
```

### Pattern Images

Themes can use pattern images for backgrounds:

```xml
<key>backgroundColor</key>
<dict>
    <key>patternImage</key>
    <string>background-pattern.png</string>
</dict>
```

### Font Specifications

Custom fonts with size and weight:

```xml
<key>listFont</key>
<dict>
    <key>fontName</key>
    <string>Helvetica-Bold</string>
    
    <key>fontSize</key>
    <real>16</real>
    
    <key>fontWeight</key>
    <string>semibold</string>
</dict>
```

### Conditional Properties

Some properties are conditional based on device or context:

```xml
<!-- Show/hide tab bar labels -->
<key>showRootTabBarLabel</key>
<boolean>false</boolean>

<!-- Loading animation type -->
<key>loadingViewType</key>
<string>macinyos|winpos95|standard</string>

<!-- Invert web view colors -->
<key>postsViewInvertedColors</key>
<boolean>true</boolean>
```

## Badge System

Themes define colors for various badge states:

```xml
<!-- Unread thread badges -->
<key>unreadBadgeBlueColor</key>
<string>#007AFF</string>

<key>unreadBadgeGreenColor</key>
<string>#4CD964</string>

<key>unreadBadgeRedColor</key>
<string>#FF3B30</string>

<key>unreadBadgeYellowColor</key>
<string>#FFCC00</string>

<key>unreadBadgeGrayColor</key>
<string>#8E8E93</string>

<key>unreadBadgePurpleColor</key>
<string>#5856D6</string>

<key>unreadBadgeOrangeColor</key>
<string>#FF9500</string>

<key>unreadBadgeTealColor</key>
<string>#5AC8FA</string>

<key>unreadBadgePinkColor</key>
<string>#FF2D92</string>
```

## CSS Integration

Themes specify CSS files for web content:

```xml
<key>postsViewCSS</key>
<string>posts-view-custom.less</string>

<key>externalStylesheetURL</key>
<string>https://example.com/custom.css</string>
```

**CSS Files Location**: `App/Resources/Templates/`

## Forum Association

Themes can be automatically applied to specific forums:

```xml
<key>relevantForumID</key>
<string>219</string>

<!-- Or multiple forums with regex -->
<key>relevantForumsPattern</key>
<string>^(25|26|154|666)$</string>
```

## Creating Custom Themes

### Basic Custom Theme

```xml
<key>my-custom-theme</key>
<dict>
    <key>descriptiveName</key>
    <string>My Custom Theme</string>
    
    <key>parent</key>
    <string>dark</string>
    
    <key>descriptiveColor</key>
    <string>#FF6B35</string>
    
    <!-- Override specific colors -->
    <key>listTextColor</key>
    <string>#FF6B35</string>
    
    <key>navbarTintColor</key>
    <string>#FF6B35</string>
    
    <!-- Custom CSS -->
    <key>postsViewCSS</key>
    <string>posts-view-custom.less</string>
</dict>
```

### Advanced Custom Theme

```xml
<key>advanced-custom</key>
<dict>
    <key>descriptiveName</key>
    <string>Advanced Custom</string>
    
    <key>parent</key>
    <string>light</string>
    
    <key>descriptiveColor</key>
    <string>#8A2BE2</string>
    
    <!-- Custom fonts -->
    <key>listFont</key>
    <dict>
        <key>fontName</key>
        <string>Georgia</string>
        <key>fontSize</key>
        <real>15</real>
    </dict>
    
    <!-- Pattern background -->
    <key>backgroundColor</key>
    <dict>
        <key>patternImage</key>
        <string>purple-texture.png</string>
    </dict>
    
    <!-- Custom loading animation -->
    <key>loadingViewType</key>
    <string>custom</string>
    
    <!-- Hide tab labels -->
    <key>showRootTabBarLabel</key>
    <boolean>false</boolean>
</dict>
```

## Theme Validation

When creating themes, ensure:

1. **Parent Exists**: Referenced parent theme must be defined
2. **Color Format**: Colors must be valid hex codes (#RRGGBB)
3. **CSS Files**: Referenced CSS files must exist
4. **Font Names**: Font names must be available on iOS
5. **Boolean Values**: Use `<boolean>true</boolean>` or `<boolean>false</boolean>`
6. **Real Numbers**: Use `<real>16.0</real>` for floating point values

## Testing Themes

### Preview in App
1. Add theme to Themes.plist
2. Build and run app
3. Go to Settings → Theme
4. Select custom theme
5. Navigate through app to test all UI elements

### CSS Testing
1. Load a thread with posts
2. Verify CSS is applied correctly
3. Test in both light and dark modes
4. Check responsive behavior

## Migration to SwiftUI

For SwiftUI migration, themes will need:

1. **Color Mapping**: Convert hex colors to SwiftUI Color
2. **Font Mapping**: Convert font specs to SwiftUI Font
3. **Environment Values**: Use SwiftUI environment for theme access
4. **View Modifiers**: Create theme-aware view modifiers

```swift
// SwiftUI theme usage example
Text("Hello")
    .foregroundColor(Color(theme["listTextColor"]))
    .font(Font(theme.listFont))
```

## Complete Property Reference

For the full list of available theme properties, see the default theme in Themes.plist. Every property defined in the default theme can be overridden in custom themes.
