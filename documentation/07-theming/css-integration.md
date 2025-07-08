# CSS Integration with Native UI

## Overview

Awful.app's CSS integration system bridges the gap between native iOS UI components and web-based content rendering. This sophisticated system ensures visual consistency across UIKit elements and WKWebView content while maintaining the flexibility to create highly customized forum-specific experiences.

## Architecture Overview

The CSS integration operates through several interconnected systems:

1. **Less Compilation Pipeline**: Converts `.less` files to CSS at build time
2. **Theme-CSS Bridge**: Links theme properties to CSS variables
3. **Runtime CSS Injection**: Dynamically updates web content styling
4. **Native-Web Coordination**: Ensures consistency between UIKit and CSS styling

## Less Stylesheet System

### Build-Time Compilation

The `LessStylesheet` package provides build-time CSS compilation:

**Location**: `LessStylesheet/` package
**Build Plugin**: `LessStylesheet/Plugins/LessStylesheet.swift`

```swift
// Build tool plugin automatically processes .less files
// Input: posts-view.less
// Output: posts-view.css (bundled with app)
```

### File Naming Convention

```
posts-view.less          → Compiled to posts-view.css
_base.less              → Importable partial (no output file)
_variables.less         → Importable partial (no output file)
posts-view-yospos.less  → Forum-specific stylesheet
```

**Import Syntax:**
```less
@import "base.less";        // Imports _base.less
@import "variables.less";   // Imports _variables.less
```

### Compilation Process

1. **Build phase**: Xcode build system triggers LessStylesheet plugin
2. **Dependency tracking**: All importable `.less` files marked as dependencies
3. **Less.js execution**: Browser version of Less.js run via JavaScriptCore
4. **Output bundling**: Generated CSS files included in app bundle

## Theme Properties to CSS Variables

### Property Mapping

Theme properties automatically become CSS variables through the compilation system:

**Theme Property (Themes.plist):**
```xml
<key>listTextColor</key>
<string>#000000</string>

<key>backgroundColor</key>
<string>#FFFFFF</string>
```

**CSS Access (posts-view.less):**
```less
@listTextColor: #000000;    // Automatically available
@backgroundColor: #FFFFFF;  // From theme properties

.post-content {
    color: @listTextColor;
    background-color: @backgroundColor;
}
```

### Dynamic Variable Substitution

At runtime, CSS files can access theme properties:

```swift
// Theme.swift - CSS property access
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

## CSS File Organization

### Base Stylesheets

**`_base.less`** - Common styles shared across all themes:
```less
// Typography base
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 14px;
    line-height: 1.4;
}

// Layout fundamentals
post {
    display: block;
    margin-bottom: 1px;
    padding: 8px;
    
    &.seen {
        opacity: 0.7;
    }
}

// Interactive elements
.action-button {
    cursor: pointer;
    transition: opacity 0.2s ease;
    
    &:hover {
        opacity: 0.8;
    }
}
```

**`_variables.less`** - Shared variables and mixins:
```less
// Animation timing
@fast-transition: 0.15s;
@normal-transition: 0.3s;

// Z-index management
@z-header: 100;
@z-overlay: 200;
@z-modal: 300;

// Mixins for common patterns
.tint-black-template-image-gray(@color) {
    filter: brightness(0) saturate(100%) invert(52%) sepia(0%) saturate(0%) hue-rotate(173deg) brightness(97%) contrast(86%);
}

.spoilers(@spoiler-color) {
    .bbc-spoiler {
        background-color: @spoiler-color;
        color: @spoiler-color;
        
        &.spoiled {
            color: inherit;
            background-color: transparent;
        }
    }
}
```

### Theme-Specific Stylesheets

Each theme can specify its own CSS file:

**posts-view.less** (default light theme):
```less
@import "base.less";
@import "magic-cake.less";

body {
    background-color: #f4f3f3;
}

post {
    background-color: #ffffff;
    border-bottom-color: #ddd;
    border-top-color: #ddd;
    
    &.seen {
        background-color: #e6eff8;
    }
}

.postbody a {
    color: #1682b2;
}

@import "spoilers.less";
.spoilers(#000);
```

**posts-view-dark.less** (dark theme):
```less
@import "base.less";

body {
    background-color: #000000;
}

post {
    background-color: #1c1c1e;
    border-bottom-color: #333;
    border-top-color: #333;
    
    &.seen {
        background-color: #2c2c2e;
    }
}

.postbody a {
    color: #5ac8fa;
}

@import "spoilers.less";
.spoilers(#fff);
```

## Forum-Specific CSS Customization

### YOSPOS Theme (Terminal Aesthetic)

**posts-view-yospos.less**:
```less
@import "base.less";

// Terminal green-on-black aesthetic
body {
    background-color: #000000;
    font-family: 'Monaco', 'Courier New', monospace;
}

post {
    background-color: #000000;
    color: #57ff57;
    border: 1px solid #57ff57;
    font-family: inherit;
    
    &.seen {
        color: #33cc33;
    }
}

// Retro terminal styling
.username {
    color: #57ff57;
    text-shadow: 0 0 2px #57ff57;
}

// Blinking cursor effect
.postdate:after {
    content: "_";
    animation: blink 1s infinite;
}

@keyframes blink {
    0%, 50% { opacity: 1; }
    51%, 100% { opacity: 0; }
}

// Custom emoticons for terminal feel
.awful-smile {
    filter: hue-rotate(120deg) contrast(200%);
}
```

### FYAD Theme (Hot Pink Aesthetic)

**posts-view-fyad.less**:
```less
@import "base.less";

body {
    background: linear-gradient(45deg, #ff69b4, #ff1493);
}

post {
    background-color: rgba(255, 255, 255, 0.9);
    border: 2px solid #ff1493;
    border-radius: 10px;
    
    &.seen {
        background-color: rgba(255, 105, 180, 0.3);
    }
}

.username {
    color: #ff1493;
    font-weight: bold;
    text-shadow: 1px 1px 0 rgba(0, 0, 0, 0.3);
}

// Aggressive styling for FYAD culture
.postbody {
    strong {
        color: #ff0066;
        text-transform: uppercase;
    }
}
```

### Macinyos Theme (Classic Mac OS)

**posts-view-macinyos.less**:
```less
@import "base.less";

// Classic Mac OS System 7 styling
body {
    background: url('mac-desktop-pattern.png') repeat;
    font-family: 'Chicago', 'Monaco', monospace;
}

post {
    background-color: #c0c0c0;
    border: 2px outset #c0c0c0;
    margin: 2px;
    
    &.seen {
        border: 2px inset #c0c0c0;
    }
}

// Classic Mac window styling
.post-header {
    background: linear-gradient(to bottom, #ffffff, #c0c0c0);
    border-bottom: 1px solid #808080;
    padding: 2px 4px;
}

.username {
    font-weight: bold;
    color: #000000;
}

// Classic Mac button styling
.action-button {
    background: #c0c0c0;
    border: 1px outset #c0c0c0;
    border-radius: 0;
    
    &:active {
        border: 1px inset #c0c0c0;
    }
}
```

## Runtime CSS Injection

### Web View Integration

CSS is injected into WKWebView instances during content loading:

```swift
// PostsPageViewController.swift
private func renderPosts() {
    let css = theme["postsViewCSS"] ?? ""
    
    // Inject CSS into web view
    webView.evaluateJavaScript("""
        var style = document.createElement('style');
        style.textContent = `\(css)`;
        document.head.appendChild(style);
    """)
}
```

### Dynamic Theme Switching

When themes change, CSS is updated without page reload:

```swift
// Theme change notification handler
@objc private func themeDidChange() {
    let newCSS = theme["postsViewCSS"] ?? ""
    
    // Update CSS dynamically
    webView.evaluateJavaScript("""
        // Remove existing theme CSS
        var existingThemeStyle = document.getElementById('theme-style');
        if (existingThemeStyle) {
            existingThemeStyle.remove();
        }
        
        // Add new theme CSS
        var style = document.createElement('style');
        style.id = 'theme-style';
        style.textContent = `\(newCSS)`;
        document.head.appendChild(style);
    """)
}
```

## Native UI Consistency

### Color Coordination

CSS colors are synchronized with native UI elements:

```swift
// ViewController.swift - Native UI theming
override func themeDidChange() {
    // Native UI colors match CSS
    view.backgroundColor = theme["backgroundColor"]
    navigationController?.navigationBar.tintColor = theme["navbarTintColor"]
    
    // Web view gets corresponding CSS
    let css = theme["postsViewCSS"] ?? ""
    injectCSS(css)
}
```

### Typography Coordination

Font specifications are shared between native and web:

**Theme Property:**
```xml
<key>listFont</key>
<dict>
    <key>fontName</key>
    <string>Helvetica-Bold</string>
    <key>fontSize</key>
    <real>16</real>
</dict>
```

**Native Usage:**
```swift
let font = UIFont(name: theme["listFont"]["fontName"], size: theme["listFont"]["fontSize"])
```

**CSS Usage:**
```less
.post-content {
    font-family: @listFontName;
    font-size: @listFontSize;
}
```

## Responsive Design Integration

### Device Adaptation

CSS includes responsive design patterns:

```less
// Base styles
.post-content {
    padding: 8px;
    font-size: 14px;
}

// iPad-specific adjustments
@media (min-width: 768px) {
    .post-content {
        padding: 12px;
        font-size: 16px;
        max-width: 800px;
        margin: 0 auto;
    }
}

// Large text accessibility
@media (prefers-reduced-motion: reduce) {
    * {
        animation: none !important;
        transition: none !important;
    }
}
```

### Dark Mode Integration

CSS automatically responds to system appearance changes:

```less
// Automatic dark mode support
@media (prefers-color-scheme: dark) {
    body {
        background-color: #000000;
        color: #ffffff;
    }
    
    post {
        background-color: #1c1c1e;
        border-color: #333333;
    }
}
```

## Performance Optimizations

### CSS Loading Strategy

1. **Precompiled CSS**: All Less files compiled at build time
2. **Bundle inclusion**: CSS files included in app bundle for instant access
3. **Lazy loading**: CSS loaded only when theme property accessed
4. **Caching**: Compiled CSS cached in memory after first load

### Injection Optimization

```swift
// Efficient CSS injection with change detection
private var currentCSS: String?

func injectCSS(_ css: String) {
    guard css != currentCSS else { return } // Skip if unchanged
    currentCSS = css
    
    // Inject only changed CSS
    webView.evaluateJavaScript(updateCSSScript(css))
}
```

### Memory Management

- **CSS reuse**: Same CSS string reused across multiple web views
- **Cleanup**: Old style elements removed when themes change
- **Weak references**: Web view references held weakly to prevent retain cycles

## Testing CSS Integration

### Unit Tests

```swift
func testCSSCompilation() {
    let theme = Theme.theme(named: "yospos")!
    let css = theme["postsViewCSS"]!
    
    XCTAssertTrue(css.contains("background-color: #000000"))
    XCTAssertTrue(css.contains("color: #57ff57"))
}

func testCSSInjection() {
    let expectation = XCTestExpectation(description: "CSS injected")
    
    webView.evaluateJavaScript("document.body.style.backgroundColor") { result, error in
        XCTAssertEqual(result as? String, "rgb(0, 0, 0)")
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 1.0)
}
```

### Visual Testing

- **Screenshot comparison**: Automated visual regression tests
- **Theme switching**: Verify UI updates correctly when themes change
- **Cross-platform consistency**: Ensure identical rendering across devices

## Debugging CSS Issues

### Development Tools

1. **Safari Web Inspector**: Connect to WKWebView for live CSS debugging
2. **CSS logging**: Log CSS injection for runtime debugging
3. **Theme validation**: Compile-time validation of CSS file references

### Common Issues and Solutions

**Problem**: CSS not applying after theme change
**Solution**: Verify CSS injection JavaScript and check for syntax errors

**Problem**: Native UI and CSS colors don't match
**Solution**: Ensure both use the same theme property source

**Problem**: Font rendering inconsistencies
**Solution**: Check font loading and fallback specifications

## Future Enhancements

### Planned Improvements

1. **CSS Hot Reload**: Development-time CSS reloading without app restart
2. **Advanced Less Features**: Utilize more Less.js capabilities for dynamic styling
3. **CSS Custom Properties**: Modern CSS variable support for runtime theming
4. **Component-Scoped CSS**: Isolated styling for complex UI components

### SwiftUI Migration

The CSS integration will need adaptation for SwiftUI:

```swift
// Proposed SwiftUI CSS integration
struct ThemedWebView: UIViewRepresentable {
    @Environment(\.theme) var theme
    let content: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        injectThemeCSS(webView, theme: theme)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        injectThemeCSS(webView, theme: theme)
    }
}
```

This CSS integration system demonstrates how thoughtful architecture can bridge native and web technologies while maintaining performance, flexibility, and visual consistency across complex theming requirements.