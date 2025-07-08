# Less Stylesheet System

## Overview

The Less stylesheet system in Awful.app provides dynamic CSS compilation, enabling sophisticated theming through variables, mixins, and modular CSS architecture. This system bridges native iOS theming with web content styling, ensuring visual consistency across UIKit components and WKWebView content.

## Architecture Components

### LessStylesheet Package

**Location**: `LessStylesheet/` package
**Purpose**: Build-time CSS compilation from Less sources

```
LessStylesheet/
├── Package.swift                 # Swift Package Manager definition
├── Plugins/
│   └── LessStylesheet.swift     # Build tool plugin
├── Sources/
│   └── lessc/                   # Less compiler executable
└── Prebuilt/                    # Pre-compiled binaries for Xcode Archive
    ├── lessc                    # Executable
    └── LessStylesheet_lessc.bundle/
```

### Build Tool Plugin Architecture

```swift
// LessStylesheet/Plugins/LessStylesheet.swift
import PackagePlugin

@main
struct LessStylesheetPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        var commands: [Command] = []
        
        // Find all .less files in the target
        let lessFiles = target.sourceFiles.filter { $0.path.extension == "less" }
        
        for lessFile in lessFiles {
            // Skip importable files (those starting with _)
            guard !lessFile.path.lastComponent.hasPrefix("_") else { continue }
            
            let outputPath = context.pluginWorkDirectory.appending(
                lessFile.path.stem + ".css"
            )
            
            let command = Command.buildCommand(
                displayName: "Compiling \(lessFile.path.lastComponent)",
                executable: try context.tool(named: "lessc").path,
                arguments: [
                    lessFile.path.string,
                    outputPath.string
                ],
                inputFiles: [lessFile.path],
                outputFiles: [outputPath]
            )
            
            commands.append(command)
        }
        
        return commands
    }
}
```

## File Organization and Naming Conventions

### File Types

**Compiled Files** (generate .css output):
```
posts-view.less           → posts-view.css
posts-view-dark.less      → posts-view-dark.css
posts-view-yospos.less    → posts-view-yospos.css
```

**Importable Partials** (no direct output):
```
_base.less               # Common base styles
_variables.less          # Shared variables
_mixins.less            # Reusable mixins
_spoilers.less          # Spoiler functionality
_magic-cake.less        # Special effects
_dark-emoticons.less    # Dark mode emoticon filters
```

### Import Resolution

```less
// In posts-view.less
@import "base.less";        // Imports _base.less
@import "variables.less";   // Imports _variables.less
@import "spoilers.less";    // Imports _spoilers.less
```

The build system automatically maps imports to underscore-prefixed files.

## Less Compiler Integration

### JavaScriptCore Execution

The Less compiler runs via JavaScriptCore for cross-platform compatibility:

```javascript
// LessStylesheet/Sources/lessc/main.swift
import JavaScriptCore
import Foundation

// Load Less.js from bundle
let lessJS = try String(contentsOf: Bundle.module.url(forResource: "less", withExtension: "js")!)

// Create JavaScript context
let context = JSContext()!
context.evaluateScript(lessJS)

// Compile Less to CSS
let lessSource = try String(contentsOfFile: inputPath)
let compileScript = """
    less.render('\(escapedLessSource)', {
        filename: '\(inputPath)',
        compress: false,
        sourceMap: {}
    }).then(function(result) {
        // result.css contains the compiled CSS
        completion(result.css);
    }).catch(function(error) {
        errorHandler(error.message);
    });
"""

context.evaluateScript(compileScript)
```

### Dependency Tracking

The build system tracks all importable Less files as dependencies:

```swift
// All importable .less files are dependencies for all compiled files
let importableFiles = target.sourceFiles.filter { 
    $0.path.extension == "less" && $0.path.lastComponent.hasPrefix("_") 
}

let command = Command.buildCommand(
    // ... other parameters ...
    inputFiles: [lessFile.path] + importableFiles.map(\.path),
    outputFiles: [outputPath]
)
```

This ensures that changes to any imported file trigger recompilation of dependent stylesheets.

## Base Stylesheet Architecture

### _base.less - Foundation Styles

```less
// Typography foundation
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 14px;
    line-height: 1.4;
    margin: 0;
    padding: 8px;
    word-wrap: break-word;
}

// Post structure
post {
    display: block;
    margin-bottom: 1px;
    padding: 8px;
    border-top: 1px solid transparent;
    border-bottom: 1px solid transparent;
    
    &.seen {
        opacity: 0.7;
    }
    
    &:target {
        animation: highlight 2s ease-out;
    }
}

@keyframes highlight {
    0% { background-color: rgba(255, 255, 0, 0.5); }
    100% { background-color: transparent; }
}

// Header structure
header {
    display: flex;
    align-items: center;
    margin-bottom: 8px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
    padding-bottom: 4px;
    
    .avatar {
        width: 64px;
        height: 64px;
        margin-right: 8px;
        border-radius: 4px;
    }
    
    .nameanddate {
        flex: 1;
        
        .username {
            font-weight: bold;
            margin-bottom: 2px;
        }
        
        .postdate {
            font-size: 12px;
            opacity: 0.7;
        }
    }
}

// Post content
.postbody {
    margin: 8px 0;
    
    p {
        margin: 0.5em 0;
    }
    
    img {
        max-width: 100%;
        height: auto;
    }
    
    // Link styling
    a {
        text-decoration: none;
        
        &:hover {
            text-decoration: underline;
        }
    }
    
    // Code blocks
    .bbc-code {
        background-color: rgba(0, 0, 0, 0.05);
        border: 1px solid rgba(0, 0, 0, 0.1);
        border-radius: 4px;
        padding: 8px;
        font-family: 'Monaco', 'Courier New', monospace;
        font-size: 12px;
        overflow-x: auto;
    }
    
    // Quote blocks
    .bbc-quote {
        border-left: 4px solid rgba(0, 0, 0, 0.2);
        margin: 8px 0;
        padding: 8px 12px;
        background-color: rgba(0, 0, 0, 0.02);
        font-style: italic;
        
        .attribution {
            font-weight: bold;
            margin-bottom: 4px;
        }
    }
}

// Footer elements
footer {
    margin-top: 8px;
    padding-top: 4px;
    border-top: 1px solid rgba(0, 0, 0, 0.1);
    font-size: 12px;
    
    .postindex {
        float: right;
        opacity: 0.7;
    }
}

// Action buttons
.action-button {
    display: inline-block;
    padding: 4px 8px;
    margin: 2px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: 4px;
    background-color: rgba(0, 0, 0, 0.05);
    text-decoration: none;
    font-size: 12px;
    cursor: pointer;
    
    &:hover {
        background-color: rgba(0, 0, 0, 0.1);
    }
    
    &:active {
        background-color: rgba(0, 0, 0, 0.15);
    }
}

// End marker
#end {
    text-align: center;
    padding: 16px;
    font-style: italic;
    opacity: 0.7;
}
```

### _variables.less - Shared Variables

```less
// Animation timing
@fast-transition: 0.15s;
@normal-transition: 0.3s;
@slow-transition: 0.5s;

// Spacing units
@base-spacing: 8px;
@small-spacing: 4px;
@large-spacing: 16px;

// Border radius values
@small-radius: 4px;
@medium-radius: 8px;
@large-radius: 12px;

// Z-index layers
@z-base: 1;
@z-overlay: 100;
@z-modal: 200;
@z-tooltip: 300;

// Breakpoints
@mobile-max: 767px;
@tablet-min: 768px;
@desktop-min: 1024px;

// Typography scale
@font-size-small: 12px;
@font-size-normal: 14px;
@font-size-large: 16px;
@font-size-xlarge: 18px;

// Font families
@font-system: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
@font-monospace: 'Monaco', 'Courier New', monospace;
@font-serif: 'Georgia', 'Times New Roman', serif;
```

### _mixins.less - Reusable Mixins

```less
// Image tinting for template images
.tint-black-template-image-gray(@color) {
    filter: brightness(0) 
            saturate(100%) 
            invert(52%) 
            sepia(0%) 
            saturate(0%) 
            hue-rotate(173deg) 
            brightness(97%) 
            contrast(86%);
}

.tint-template-image(@color) {
    @r: red(@color);
    @g: green(@color);
    @b: blue(@color);
    
    filter: brightness(0) 
            saturate(100%) 
            invert(@r/255 * 100%) 
            sepia(@g/255 * 100%) 
            saturate(@b/255 * 100%);
}

// Responsive design helpers
.mobile-only() {
    @media (max-width: @mobile-max) {
        @content();
    }
}

.tablet-and-up() {
    @media (min-width: @tablet-min) {
        @content();
    }
}

.desktop-and-up() {
    @media (min-width: @desktop-min) {
        @content();
    }
}

// Flexbox helpers
.flex-center() {
    display: flex;
    align-items: center;
    justify-content: center;
}

.flex-between() {
    display: flex;
    align-items: center;
    justify-content: space-between;
}

// Animation helpers
.smooth-transition(@property: all, @duration: @normal-transition) {
    transition: @property @duration ease-out;
}

.hover-lift() {
    .smooth-transition(transform);
    
    &:hover {
        transform: translateY(-1px);
    }
}

// Clearfix for legacy float layouts
.clearfix() {
    &:after {
        content: "";
        display: table;
        clear: both;
    }
}

// Text overflow handling
.text-ellipsis() {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.text-clamp(@lines: 3) {
    display: -webkit-box;
    -webkit-line-clamp: @lines;
    -webkit-box-orient: vertical;
    overflow: hidden;
}
```

## Specialized Stylesheet Modules

### _spoilers.less - Spoiler Functionality

```less
.spoilers(@spoiler-color) {
    .bbc-spoiler {
        background-color: @spoiler-color;
        color: @spoiler-color;
        border-radius: 2px;
        padding: 0 2px;
        cursor: pointer;
        transition: all 0.3s ease;
        
        &.spoiled {
            color: inherit;
            background-color: rgba(0, 0, 0, 0.1);
        }
        
        // Prevent text selection of unspoiled content
        &:not(.spoiled) {
            user-select: none;
            -webkit-user-select: none;
        }
    }
    
    // Nested spoilers
    .bbc-spoiler .bbc-spoiler {
        background-color: lighten(@spoiler-color, 10%);
        
        &.spoiled {
            background-color: rgba(0, 0, 0, 0.15);
        }
    }
}
```

### _magic-cake.less - Special Effects

```less
// Rainbow text animation
@keyframes rainbow {
    0% { color: #ff0000; }
    16.66% { color: #ff8800; }
    33.33% { color: #ffff00; }
    50% { color: #00ff00; }
    66.66% { color: #0088ff; }
    83.33% { color: #8800ff; }
    100% { color: #ff0000; }
}

.magic-cake {
    animation: rainbow 2s linear infinite;
    font-weight: bold;
    text-shadow: 0 0 10px currentColor;
}

// Floating animation
@keyframes float {
    0%, 100% { transform: translateY(0px); }
    50% { transform: translateY(-10px); }
}

.float {
    animation: float 3s ease-in-out infinite;
}

// Shake animation for emphasis
@keyframes shake {
    0%, 100% { transform: translateX(0); }
    10%, 30%, 50%, 70%, 90% { transform: translateX(-2px); }
    20%, 40%, 60%, 80% { transform: translateX(2px); }
}

.shake {
    animation: shake 0.82s cubic-bezier(.36,.07,.19,.97) both;
}

// Pulse glow effect
@keyframes pulse-glow {
    0% { box-shadow: 0 0 5px rgba(255, 255, 255, 0.5); }
    50% { box-shadow: 0 0 20px rgba(255, 255, 255, 0.8); }
    100% { box-shadow: 0 0 5px rgba(255, 255, 255, 0.5); }
}

.pulse-glow {
    animation: pulse-glow 2s ease-in-out infinite;
}
```

### _dark-emoticons.less - Dark Mode Image Filters

```less
// Dark mode emoticon filters
.dark-emoticons() {
    .awful-smile {
        // Invert and adjust contrast for dark backgrounds
        filter: invert(1) hue-rotate(180deg) contrast(1.2) brightness(0.9);
    }
    
    // Specific emoticon adjustments
    .awful-smile[title*="icon-haw"] {
        filter: invert(1) hue-rotate(180deg) contrast(1.4) brightness(0.8);
    }
    
    .awful-smile[title*="icon-cool"] {
        filter: invert(1) hue-rotate(180deg) contrast(1.1) brightness(1.1);
    }
    
    // Avatar adjustments for dark mode
    .avatar {
        border: 1px solid rgba(255, 255, 255, 0.2);
        filter: brightness(0.9) contrast(1.1);
    }
}
```

### _dead-tweet-ghost.less - Tweet Embedding

```less
.dead-tweet(@link-color, @background-color, @ghost-color) {
    .dead-tweet {
        background-color: fade(@ghost-color, 10%);
        border: 1px solid fade(@ghost-color, 30%);
        border-radius: 8px;
        padding: 12px;
        margin: 8px 0;
        position: relative;
        
        &:before {
            content: "🐦";
            position: absolute;
            top: 8px;
            right: 8px;
            opacity: 0.5;
            font-size: 16px;
        }
        
        .tweet-text {
            color: @ghost-color;
            font-style: italic;
            margin-bottom: 8px;
        }
        
        .tweet-author {
            color: fade(@ghost-color, 70%);
            font-size: 12px;
            
            &:before {
                content: "@ ";
            }
        }
        
        .tweet-link {
            color: @link-color;
            text-decoration: none;
            
            &:hover {
                text-decoration: underline;
            }
        }
    }
    
    // Live tweet styling
    .tweet-embed {
        background-color: @background-color;
        border: 1px solid fade(@link-color, 30%);
        border-radius: 8px;
        overflow: hidden;
        
        iframe {
            width: 100%;
            border: none;
        }
    }
}
```

## Theme-Specific Stylesheets

### Light Theme (posts-view.less)

```less
@import "base.less";
@import "magic-cake.less";

// Light theme color palette
@background-color: #f4f3f3;
@post-background: #ffffff;
@post-background-seen: #e6eff8;
@text-color: #000000;
@link-color: #1682b2;
@border-color: #ddd;

body {
    background-color: @background-color;
    color: @text-color;
}

post {
    background-color: @post-background;
    border-bottom-color: @border-color;
    border-top-color: @border-color;
    
    &.seen {
        background-color: @post-background-seen;
    }
}

header {
    border-bottom: 0;
}

.awful-smile {
    image-rendering: -webkit-crisp-edges;
}

.postbody a, [data-awful-linkified-image] {
    color: @link-color;
}

@import "spoilers.less";
.spoilers(#000);

.bbc-block {
    h4, h5 {
        color: #555;
    }
}

footer {
    margin-top: .6em;
}

@postdate-color: rgba(0, 0, 0, 30%);
.postdate, .regdate {
    color: @postdate-color;
}

.action-button img {
    .tint-black-template-image-gray(#8e8e8e);
}

#end {
    color: @postdate-color;
    line-height: 3em;
}

@import "dead-tweet-ghost.less";
.dead-tweet(@link-color, @background-color, #8e8e8e);
```

### Dark Theme (posts-view-dark.less)

```less
@import "base.less";
@import "dark-emoticons.less";

// Dark theme color palette
@background-color: #000000;
@post-background: #1c1c1e;
@post-background-seen: #2c2c2e;
@text-color: #ffffff;
@link-color: #5ac8fa;
@border-color: #333333;

body {
    background-color: @background-color;
    color: @text-color;
}

post {
    background-color: @post-background;
    border-bottom-color: @border-color;
    border-top-color: @border-color;
    
    &.seen {
        background-color: @post-background-seen;
    }
}

// Apply dark mode emoticon filters
.dark-emoticons();

.postbody a, [data-awful-linkified-image] {
    color: @link-color;
}

@import "spoilers.less";
.spoilers(@text-color);

.bbc-block {
    h4, h5 {
        color: #aaa;
    }
}

@postdate-color: rgba(255, 255, 255, 30%);
.postdate, .regdate {
    color: @postdate-color;
}

.action-button img {
    .tint-template-image(@text-color);
}

#end {
    color: @postdate-color;
    line-height: 3em;
}

@import "dead-tweet-ghost.less";
.dead-tweet(@link-color, @background-color, #8e8e8e);
```

## Build Process Integration

### Xcode Build Phase

The Less compilation integrates with Xcode's build system:

1. **Dependency Resolution**: Build plugin scans for `.less` files
2. **Change Detection**: Only recompiles changed files and their dependents
3. **Error Reporting**: Compilation errors shown in Xcode's issue navigator
4. **Output Integration**: Generated CSS files included in app bundle

### Archive Build Workaround

Xcode Archives don't build executable dependencies, requiring prebuilt binaries:

```bash
# Update prebuilt lessc for archive builds
cd LessStylesheet/
swift build --product lessc --configuration release --arch arm64 --arch x86_64
cp -R .build/apple/Products/Release/lessc .build/apple/Products/Release/*.bundle Prebuilt/
```

### Development Workflow

```bash
# Watch for Less changes during development
find AwfulTheming/Sources/AwfulTheming/Stylesheets -name "*.less" | entr -r xcodebuild -target Awful
```

## Runtime CSS Loading

### Theme Property Integration

```swift
// Theme.swift - CSS property loading
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

public func stylesheet(named name: String) throws -> String? {
    guard let url = Bundle.module.url(forResource: name, withExtension: ".css") else {
        return nil
    }
    return try String(contentsOf: url, encoding: .utf8)
}
```

### Dynamic CSS Injection

```swift
private func injectCSS() {
    guard let css = theme["postsViewCSS"] else { return }
    
    let script = """
        var style = document.createElement('style');
        style.id = 'theme-stylesheet';
        style.textContent = `\(css)`;
        
        // Replace existing theme stylesheet
        var existing = document.getElementById('theme-stylesheet');
        if (existing) {
            existing.remove();
        }
        
        document.head.appendChild(style);
    """
    
    webView.evaluateJavaScript(script)
}
```

## Performance Optimizations

### Build-Time Optimizations

- **Selective Compilation**: Only changed files are recompiled
- **Dependency Caching**: Import relationships cached between builds
- **Parallel Processing**: Multiple Less files compiled concurrently

### Runtime Optimizations

- **CSS Caching**: Compiled CSS cached in memory after first load
- **Lazy Loading**: CSS loaded only when theme property accessed
- **Minification**: Production builds can enable CSS minification

## Testing Less Compilation

### Unit Tests

```swift
func testLessCompilation() {
    let themes = ["default", "dark", "yospos", "fyad"]
    
    for themeName in themes {
        let theme = Theme.theme(named: themeName)!
        let css = theme["postsViewCSS"]
        
        XCTAssertNotNil(css, "Theme \(themeName) should have compiled CSS")
        XCTAssertFalse(css!.isEmpty, "CSS should not be empty")
        XCTAssertFalse(css!.contains("@import"), "CSS should not contain unresolved imports")
    }
}
```

### CSS Validation

```swift
func testCSSValidity() {
    let css = Theme.theme(named: "yospos")!["postsViewCSS"]!
    
    // Basic syntax validation
    XCTAssertFalse(css.contains("undefined"), "CSS should not contain undefined references")
    XCTAssertEqual(css.filter { $0 == "{" }.count, css.filter { $0 == "}" }.count, "Braces should be balanced")
}
```

The Less stylesheet system provides a powerful foundation for theme-aware styling, enabling sophisticated visual customization while maintaining development efficiency and runtime performance.