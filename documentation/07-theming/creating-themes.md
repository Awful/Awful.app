# Creating Custom Themes

## Overview

This guide provides comprehensive instructions for designers and developers to create custom themes for Awful.app. The theming system supports everything from simple color variations to complex forum-specific experiences with custom CSS, animations, and interactive elements.

## Theme Design Process

### 1. Conceptualization

Before creating a theme, consider:

- **Target Audience**: Which forum or user group is this theme for?
- **Cultural Context**: What aesthetic matches the forum's personality?
- **Accessibility**: Will the theme be readable and usable for all users?
- **Technical Scope**: Simple color changes or complex CSS customizations?

### 2. Color Palette Development

#### Core Color Categories

**Background Colors**:
- `backgroundColor`: Main app background
- `listBackgroundColor`: Table view/list background
- `listSelectedBackgroundColor`: Selected cell background

**Text Colors**:
- `listTextColor`: Primary text
- `listSecondaryTextColor`: Secondary/subtitle text
- `navbarTitleTextColor`: Navigation bar titles

**Interactive Colors**:
- `navbarTintColor`: Navigation bar buttons and controls
- `tabBarTintColor`: Tab bar selection color
- `composeIconTintColor`: Compose/reply button color

**System Colors**:
- `listSeparatorColor`: Lines between table cells
- `linkColor`: Links in post content

#### Color Accessibility Guidelines

```swift
// Ensure sufficient contrast ratios
func validateContrast(foreground: UIColor, background: UIColor) -> Bool {
    let ratio = contrastRatio(foreground, background)
    return ratio >= 4.5 // WCAG AA standard
}

// Test color combinations
let validCombination = validateContrast(
    foreground: theme["listTextColor"]!,
    background: theme["listBackgroundColor"]!
)
```

### 3. Typography Specification

#### Font Properties

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

**Available Font Weights**:
- `ultraLight`, `thin`, `light`
- `regular`, `medium`, `semibold`
- `bold`, `heavy`, `black`

**iOS System Fonts**:
- `-apple-system`: Default system font
- `SF Pro Display`: Large text (iOS 13+)
- `SF Pro Text`: Body text (iOS 13+)
- `SF Mono`: Monospace font

**Custom Fonts**: Ensure fonts are included in app bundle and properly licensed.

## Basic Theme Creation

### Step 1: Theme Definition Structure

Create a new theme entry in `Themes.plist`:

```xml
<key>my-custom-theme</key>
<dict>
    <!-- Required Properties -->
    <key>descriptiveName</key>
    <string>My Custom Theme</string>
    
    <key>parent</key>
    <string>light</string>
    
    <key>descriptiveColor</key>
    <string>#FF6B35</string>
    
    <!-- Color Overrides -->
    <key>listTextColor</key>
    <string>#2C2C2E</string>
    
    <key>backgroundColor</key>
    <string>#F2F2F7</string>
    
    <key>navbarTintColor</key>
    <string>#FF6B35</string>
    
    <!-- Optional Properties -->
    <key>keyboardAppearance</key>
    <string>Light</string>
    
    <key>scrollIndicatorStyle</key>
    <string>Dark</string>
</dict>
```

### Step 2: Inheritance Planning

Choose an appropriate parent theme:

- **`default`**: Root theme with all base properties
- **`light`**: Light mode with system-appropriate colors
- **`dark`**: Dark mode with system-appropriate colors
- **`oled`**: True black for OLED displays

**Inheritance Example**:
```
Custom Theme → light → default
```

### Step 3: Property Override Strategy

Only override properties that differ from the parent:

```xml
<!-- Good: Minimal overrides -->
<key>minimalist-theme</key>
<dict>
    <key>parent</key>
    <string>light</string>
    <key>navbarTintColor</key>
    <string>#007AFF</string>
    <key>composeIconTintColor</key>
    <string>#007AFF</string>
</dict>

<!-- Avoid: Redundant overrides -->
<key>redundant-theme</key>
<dict>
    <key>parent</key>
    <string>light</string>
    <!-- Don't repeat parent properties -->
    <key>backgroundColor</key>
    <string>#FFFFFF</string> <!-- Same as light theme -->
</dict>
```

## Advanced Theme Creation

### Forum-Specific Themes

#### Automatic Forum Association

```xml
<key>my-forum-theme</key>
<dict>
    <key>relevantForumID</key>
    <string>123</string>
    
    <!-- Theme automatically applies to forum 123 -->
</dict>
```

#### Multiple Forum Association

```xml
<key>multi-forum-theme</key>
<dict>
    <key>relevantForumsPattern</key>
    <string>^(123|456|789)$</string>
    
    <!-- Regex pattern for multiple forums -->
</dict>
```

### Custom CSS Integration

#### Creating CSS Files

1. **Create Less file**: `AwfulTheming/Sources/AwfulTheming/Stylesheets/posts-view-mytheme.less`

```less
@import "base.less";

// Custom color variables
@primary-color: #FF6B35;
@secondary-color: #2C2C2E;
@background-color: #F2F2F7;

body {
    background-color: @background-color;
    font-family: 'Georgia', serif;
}

post {
    background-color: #ffffff;
    border: 2px solid @primary-color;
    border-radius: 8px;
    margin: 4px 0;
    
    &.seen {
        border-color: lighten(@primary-color, 20%);
        background-color: lighten(@background-color, 5%);
    }
}

.username {
    color: @primary-color;
    font-weight: bold;
    font-family: 'Georgia', serif;
}

.postbody {
    font-family: 'Georgia', serif;
    line-height: 1.6;
    
    a {
        color: darken(@primary-color, 10%);
        
        &:hover {
            color: @primary-color;
        }
    }
}
```

2. **Reference in theme**:

```xml
<key>my-custom-theme</key>
<dict>
    <key>postsViewCSS</key>
    <string>posts-view-mytheme.less</string>
</dict>
```

### Pattern Backgrounds

#### Using Pattern Images

```xml
<key>textured-theme</key>
<dict>
    <key>backgroundColor</key>
    <dict>
        <key>patternImage</key>
        <string>paper-texture.png</string>
    </dict>
</dict>
```

#### CSS Pattern Integration

```less
// In your custom CSS file
body {
    background-image: url('data:image/svg+xml,<svg>...</svg>');
    background-repeat: repeat;
    background-size: 20px 20px;
}
```

### Animation and Special Effects

#### Loading Animations

```xml
<key>animated-theme</key>
<dict>
    <key>loadingViewType</key>
    <string>custom</string>
</dict>
```

#### CSS Animations

```less
// Floating username animation
.username {
    animation: float 3s ease-in-out infinite;
}

@keyframes float {
    0%, 100% { transform: translateY(0px); }
    50% { transform: translateY(-5px); }
}

// Subtle post highlighting
post:target {
    animation: highlight 2s ease-out;
}

@keyframes highlight {
    0% { box-shadow: 0 0 20px rgba(255, 107, 53, 0.5); }
    100% { box-shadow: none; }
}
```

## Theme Examples

### Example 1: Sunset Theme

**Design Concept**: Warm, gradient-based theme inspired by sunset colors.

```xml
<key>sunset</key>
<dict>
    <key>descriptiveName</key>
    <string>Sunset</string>
    
    <key>parent</key>
    <string>light</string>
    
    <key>descriptiveColor</key>
    <string>#FF6B35</string>
    
    <!-- Warm color palette -->
    <key>backgroundColor</key>
    <string>#FFF8F0</string>
    
    <key>listBackgroundColor</key>
    <string>#FFFFFF</string>
    
    <key>listTextColor</key>
    <string>#8B4513</string>
    
    <key>navbarTintColor</key>
    <string>#FF6B35</string>
    
    <key>composeIconTintColor</key>
    <string>#FF8C42</string>
    
    <key>linkColor</key>
    <string>#D2691E</string>
    
    <!-- Custom CSS -->
    <key>postsViewCSS</key>
    <string>posts-view-sunset.less</string>
</dict>
```

**CSS Implementation** (`posts-view-sunset.less`):

```less
@import "base.less";

// Sunset gradient background
body {
    background: linear-gradient(to bottom, #fff8f0, #ffe4d6);
}

post {
    background: linear-gradient(to bottom, #ffffff, #fef9f7);
    border: 1px solid #ffb380;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(255, 107, 53, 0.1);
    
    &.seen {
        background: linear-gradient(to bottom, #fef9f7, #fef2ed);
    }
}

.username {
    color: #d2691e;
    text-shadow: 0 1px 2px rgba(255, 107, 53, 0.2);
}

.postbody a {
    color: #ff6b35;
    
    &:visited {
        color: #d2691e;
    }
}
```

### Example 2: Neon Cyberpunk Theme

**Design Concept**: High-contrast neon aesthetic for tech forums.

```xml
<key>cyberpunk</key>
<dict>
    <key>descriptiveName</key>
    <string>Cyberpunk</string>
    
    <key>parent</key>
    <string>dark</string>
    
    <key>descriptiveColor</key>
    <string>#00FFFF</string>
    
    <!-- Neon color scheme -->
    <key>backgroundColor</key>
    <string>#0A0A0A</string>
    
    <key>listBackgroundColor</key>
    <string>#1A1A1A</string>
    
    <key>listTextColor</key>
    <string>#00FFFF</string>
    
    <key>navbarTintColor</key>
    <string>#FF00FF</string>
    
    <key>linkColor</key>
    <string>#00FF41</string>
    
    <!-- Monospace font for tech aesthetic -->
    <key>listFont</key>
    <dict>
        <key>fontName</key>
        <string>Monaco</string>
        <key>fontSize</key>
        <real>14</real>
    </dict>
    
    <key>postsViewCSS</key>
    <string>posts-view-cyberpunk.less</string>
</dict>
```

**CSS Implementation** (`posts-view-cyberpunk.less`):

```less
@import "base.less";

// Cyberpunk grid background
body {
    background-color: #0a0a0a;
    background-image: 
        linear-gradient(cyan 1px, transparent 1px),
        linear-gradient(90deg, cyan 1px, transparent 1px);
    background-size: 20px 20px;
    background-opacity: 0.1;
    font-family: 'Monaco', monospace;
}

post {
    background-color: #1a1a1a;
    border: 1px solid #00ffff;
    border-radius: 0;
    box-shadow: 
        0 0 10px rgba(0, 255, 255, 0.3),
        inset 0 0 10px rgba(0, 255, 255, 0.1);
    
    &.seen {
        border-color: #ff00ff;
        box-shadow: 
            0 0 10px rgba(255, 0, 255, 0.3),
            inset 0 0 10px rgba(255, 0, 255, 0.1);
    }
}

.username {
    color: #00ffff;
    text-shadow: 0 0 5px #00ffff;
    text-transform: uppercase;
    letter-spacing: 1px;
}

.postbody {
    a {
        color: #00ff41;
        text-shadow: 0 0 3px #00ff41;
        
        &:hover {
            text-shadow: 0 0 8px #00ff41;
        }
    }
}

// Glitch effect for special elements
.postdate {
    position: relative;
    
    &:before {
        content: attr(data-text);
        position: absolute;
        top: 0;
        left: 2px;
        color: #ff00ff;
        opacity: 0.5;
        z-index: -1;
        animation: glitch 0.3s infinite;
    }
}

@keyframes glitch {
    0% { transform: translate(0); }
    20% { transform: translate(-2px, 2px); }
    40% { transform: translate(-2px, -2px); }
    60% { transform: translate(2px, 2px); }
    80% { transform: translate(2px, -2px); }
    100% { transform: translate(0); }
}
```

### Example 3: Vintage Newspaper Theme

**Design Concept**: Classic newspaper layout with serif typography.

```xml
<key>newspaper</key>
<dict>
    <key>descriptiveName</key>
    <string>Vintage Newspaper</string>
    
    <key>parent</key>
    <string>light</string>
    
    <key>descriptiveColor</key>
    <string>#D2B48C</string>
    
    <!-- Newspaper color scheme -->
    <key>backgroundColor</key>
    <string>#F5F5DC</string>
    
    <key>listTextColor</key>
    <string>#2F2F2F</string>
    
    <key>listSecondaryTextColor</key>
    <string>#666666</string>
    
    <!-- Serif typography -->
    <key>listFont</key>
    <dict>
        <key>fontName</key>
        <string>Times New Roman</string>
        <key>fontSize</key>
        <real>16</real>
    </dict>
    
    <key>postsViewCSS</key>
    <string>posts-view-newspaper.less</string>
</dict>
```

**CSS Implementation** (`posts-view-newspaper.less`):

```less
@import "base.less";

// Aged paper background
body {
    background-color: #f5f5dc;
    background-image: url('data:image/svg+xml,<svg>/* paper texture */</svg>');
    font-family: 'Times New Roman', serif;
}

post {
    background-color: #fafaf0;
    border-top: 3px double #8b4513;
    border-bottom: 1px solid #d2b48c;
    margin: 0;
    padding: 16px;
    
    &:first-child {
        border-top: none;
    }
}

.username {
    font-family: 'Times New Roman', serif;
    font-weight: bold;
    font-variant: small-caps;
    letter-spacing: 1px;
    color: #8b4513;
    border-bottom: 2px solid #d2b48c;
    display: inline-block;
    padding-bottom: 2px;
}

.postbody {
    column-count: 1;
    column-gap: 20px;
    text-align: justify;
    line-height: 1.6;
    font-family: 'Times New Roman', serif;
    
    p {
        text-indent: 1.5em;
        margin: 0.5em 0;
    }
    
    // Drop cap for first paragraph
    p:first-of-type:first-letter {
        float: left;
        font-size: 3em;
        line-height: 0.8;
        margin: 0.1em 0.1em 0 0;
        font-weight: bold;
        color: #8b4513;
    }
}

// Newspaper-style links
.postbody a {
    color: #8b4513;
    text-decoration: underline;
    
    &:hover {
        background-color: #fffacd;
    }
}
```

## Testing and Validation

### Visual Testing

#### Theme Preview Generation

```swift
// ThemePreview.swift - Development tool
class ThemePreviewGenerator {
    static func generatePreview(for theme: Theme) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 480))
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: 320, height: 480))
            
            // Background
            theme["backgroundColor"]?.setFill()
            context.fill(rect)
            
            // Sample elements
            drawSamplePost(in: rect, theme: theme, context: context.cgContext)
        }
    }
    
    private static func drawSamplePost(in rect: CGRect, theme: Theme, context: CGContext) {
        // Draw representative UI elements using theme colors
        // ... implementation
    }
}
```

#### Automated Screenshot Testing

```swift
// ThemeScreenshotTests.swift
class ThemeScreenshotTests: XCTestCase {
    func testAllThemeScreenshots() {
        for theme in Theme.allThemes {
            let screenshot = generateThemeScreenshot(theme)
            
            // Save screenshot for manual review
            saveScreenshot(screenshot, name: "theme-\(theme.name)")
            
            // Verify basic requirements
            XCTAssertNotNil(screenshot)
        }
    }
}
```

### Accessibility Testing

#### Color Contrast Validation

```swift
// AccessibilityValidator.swift
struct AccessibilityValidator {
    static func validateTheme(_ theme: Theme) -> [AccessibilityIssue] {
        var issues: [AccessibilityIssue] = []
        
        // Check contrast ratios
        let combinations = [
            ("listTextColor", "listBackgroundColor"),
            ("navbarTitleTextColor", "navbarBackgroundColor"),
            ("linkColor", "backgroundColor")
        ]
        
        for (foreground, background) in combinations {
            if let fgColor = theme[foreground],
               let bgColor = theme[background] {
                let ratio = contrastRatio(fgColor, bgColor)
                if ratio < 4.5 {
                    issues.append(.insufficientContrast(foreground, background, ratio))
                }
            }
        }
        
        return issues
    }
}

enum AccessibilityIssue {
    case insufficientContrast(String, String, Double)
    case missingProperty(String)
    case invalidColorValue(String)
}
```

### Performance Testing

#### CSS Compilation Testing

```swift
// CSSPerformanceTests.swift
class CSSPerformanceTests: XCTestCase {
    func testCSSCompilationPerformance() {
        measure {
            for _ in 0..<100 {
                let css = Theme.theme(named: "cyberpunk")!["postsViewCSS"]
                XCTAssertNotNil(css)
            }
        }
    }
    
    func testThemeApplicationPerformance() {
        let viewController = PostsPageViewController(thread: sampleThread)
        
        measure {
            viewController.theme = Theme.theme(named: "sunset")!
            viewController.themeDidChange()
        }
    }
}
```

## Deployment and Distribution

### Theme Validation Checklist

Before submitting a theme:

- [ ] **Color contrast meets WCAG AA standards**
- [ ] **All required properties defined or inherited**
- [ ] **CSS file compiles without errors**
- [ ] **Theme displays correctly on all device sizes**
- [ ] **Font licenses allow app distribution**
- [ ] **Performance impact is acceptable**
- [ ] **Visual regression tests pass**

### Theme Documentation

Document your theme with:

```markdown
# Theme Name

## Design Concept
Brief description of the theme's inspiration and intended use.

## Color Palette
- Primary: #FF6B35
- Secondary: #2C2C2E
- Background: #F2F2F7

## Typography
- Primary Font: Georgia, serif
- Secondary Font: System default

## Target Forums
- Forum ID 123: Tech Discussion
- Forum ID 456: Design Critique

## Special Features
- Custom loading animation
- Gradient backgrounds
- Hover effects on links

## Accessibility Notes
- Meets WCAG AA contrast requirements
- Supports Dynamic Type scaling
- Compatible with VoiceOver
```

### Distribution Options

1. **Built-in Theme**: Submit for inclusion in main app
2. **Theme Pack**: Distribute as separate download
3. **Custom Build**: Create custom app version with theme

## Advanced Techniques

### Dynamic Color Generation

```swift
// DynamicThemeGenerator.swift
class DynamicThemeGenerator {
    static func generateTheme(baseColor: UIColor, mode: Theme.Mode) -> [String: Any] {
        let palette = ColorPalette(baseColor: baseColor, mode: mode)
        
        return [
            "descriptiveName": "Dynamic \(baseColor.hexString)",
            "backgroundColor": palette.background.hexString,
            "listTextColor": palette.text.hexString,
            "navbarTintColor": palette.accent.hexString,
            // ... generate all required properties
        ]
    }
}

struct ColorPalette {
    let background: UIColor
    let text: UIColor
    let accent: UIColor
    
    init(baseColor: UIColor, mode: Theme.Mode) {
        switch mode {
        case .light:
            background = baseColor.lightened(by: 0.9)
            text = UIColor.black
            accent = baseColor
        case .dark:
            background = baseColor.darkened(by: 0.9)
            text = UIColor.white
            accent = baseColor.lightened(by: 0.3)
        }
    }
}
```

### CSS Variable Integration

```less
// Modern CSS custom properties for dynamic theming
:root {
    --primary-color: #FF6B35;
    --secondary-color: #2C2C2E;
    --background-color: #F2F2F7;
}

post {
    background-color: var(--background-color);
    border-color: var(--primary-color);
}

.username {
    color: var(--primary-color);
}

// JavaScript integration for runtime changes
document.documentElement.style.setProperty('--primary-color', newColor);
```

### Theme Inheritance Strategies

```xml
<!-- Multi-level inheritance -->
<key>base-tech-theme</key>
<dict>
    <key>parent</key>
    <string>dark</string>
    <!-- Common properties for all tech themes -->
</dict>

<key>cyberpunk-variant</key>
<dict>
    <key>parent</key>
    <string>base-tech-theme</string>
    <!-- Cyberpunk-specific overrides -->
</dict>

<key>matrix-variant</key>
<dict>
    <key>parent</key>
    <string>base-tech-theme</string>
    <!-- Matrix-specific overrides -->
</dict>
```

Creating custom themes for Awful.app allows for endless creativity while maintaining usability and performance. The flexible architecture supports everything from simple color variations to complex, animated experiences that reflect the unique culture of different forum communities.