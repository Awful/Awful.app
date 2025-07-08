# Forum-Specific Themes

## Overview

Awful.app's forum-specific theming system reflects the unique culture and identity of different Something Awful forum communities. Each forum can have its own distinct visual style, creating an immersive experience that matches the personality and posting culture of that community.

## Automatic Forum Theme Application

### Theme-Forum Association

Themes are automatically applied based on forum context using the `relevantForumID` property:

```xml
<key>yospos</key>
<dict>
    <key>relevantForumID</key>
    <string>219</string>
    <!-- YOSPOS automatically applies to forum 219 -->
</dict>
```

### Runtime Forum Detection

```swift
// PostsPageViewController.swift
override var theme: Theme {
    guard let forum = thread.forum, !forum.forumID.isEmpty else {
        return Theme.defaultTheme()
    }
    return Theme.currentTheme(for: ForumID(forum.forumID))
}
```

### Default Forum Associations

Hard-coded forum-theme mappings ensure consistent experiences:

```swift
public static var forumSpecificDefaults: [String: Any] {
    let modeless = [
        "25": "Gas Chamber",      // Gas Chamber forum
        "26": "FYAD",            // F*** You and Die
        "154": "FYAD",           // FYAD-related subforum
        "666": "FYAD",           // Another FYAD subforum
        "219": "YOSPOS",         // You Only Screenshot Posts Once
        "268": "BYOB",           // Bring Your Own Book
        "196": "BYOB"            // BYOB-related subforum
    ]
    // Applied to both light and dark modes
}
```

## Major Forum Themes

### YOSPOS (You Only Screenshot Posts Once)

**Forum ID**: 219 - Computer programming and tech discussion
**Theme Philosophy**: Terminal/hacker aesthetic reflecting the technical nature of the forum

#### Visual Characteristics

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
    
    <!-- Terminal green color scheme -->
    <key>listTextColor</key>
    <string>#57ff57</string>
    
    <key>backgroundColor</key>
    <string>#000000</string>
    
    <key>postsViewCSS</key>
    <string>posts-view-yospos.less</string>
</dict>
```

#### CSS Implementation (posts-view-yospos.less)

```less
@import "base.less";

// Terminal aesthetic
body {
    background-color: #000000;
    color: #57ff57;
    font-family: 'Monaco', 'Courier New', monospace;
}

post {
    background-color: #000000;
    color: #57ff57;
    border: 1px solid #57ff57;
    border-radius: 0;
    
    &.seen {
        color: #33cc33;
        border-color: #33cc33;
    }
}

// Matrix-style text effects
.username {
    color: #57ff57;
    text-shadow: 0 0 3px #57ff57;
    font-weight: bold;
}

// Blinking cursor for terminal feel
.postdate:after {
    content: "_";
    animation: blink 1s infinite;
}

@keyframes blink {
    0%, 50% { opacity: 1; }
    51%, 100% { opacity: 0; }
}

// Code syntax highlighting
.bbc-code {
    background-color: #001100;
    border: 1px solid #57ff57;
    color: #77ff77;
}

// Terminal-style links
.postbody a {
    color: #5ac8fa;
    text-decoration: underline;
    
    &:visited {
        color: #af52de;
    }
}
```

#### Cultural Context

- **Programming focus**: Monospace fonts and terminal styling reflect coding culture
- **"Screenshot" reference**: Theme name refers to best practice of posting code as images
- **Green-on-black**: Classic terminal color scheme familiar to developers

### FYAD (F*** You and Die)

**Forum ID**: 26, 154, 666 - Controversial discussion and general mayhem
**Theme Philosophy**: Aggressive, attention-grabbing aesthetic matching the forum's confrontational culture

#### Visual Characteristics

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
    
    <!-- Hot pink/aggressive color scheme -->
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

#### CSS Implementation (posts-view-fyad.less)

```less
@import "base.less";

// Aggressive pink gradient background
body {
    background: linear-gradient(135deg, #ff69b4, #ff1493, #dc143c);
    animation: rainbow 3s infinite;
}

@keyframes rainbow {
    0% { filter: hue-rotate(0deg); }
    100% { filter: hue-rotate(360deg); }
}

post {
    background-color: rgba(255, 255, 255, 0.95);
    border: 3px solid #ff1493;
    border-radius: 8px;
    box-shadow: 0 0 10px rgba(255, 20, 147, 0.5);
    
    &.seen {
        background-color: rgba(255, 105, 180, 0.3);
        border-color: #ff69b4;
    }
}

// Attention-grabbing username styling
.username {
    color: #ff0066;
    font-weight: 900;
    text-transform: uppercase;
    text-shadow: 2px 2px 0 rgba(0, 0, 0, 0.3);
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.05); }
    100% { transform: scale(1); }
}

// Emphasized text styling
.postbody {
    strong {
        color: #ff0066;
        text-transform: uppercase;
        font-weight: 900;
    }
    
    em {
        color: #ff3399;
        font-style: italic;
        text-shadow: 1px 1px 0 rgba(0, 0, 0, 0.2);
    }
}

// Warning/alert styling for controversial content
.bbc-quote {
    background: linear-gradient(45deg, #ffe4e1, #ffb6c1);
    border-left: 5px solid #ff1493;
    padding: 10px;
    font-style: italic;
}
```

#### Cultural Context

- **Confrontational nature**: Bold colors and aggressive styling match forum personality
- **Hot pink branding**: Color scheme associated with FYAD culture
- **Visual intensity**: High-contrast design reflects heated discussions

### BYOB (Bring Your Own Book)

**Forum ID**: 268, 196 - Creative writing and literature discussion
**Theme Philosophy**: Relaxed, bookish aesthetic encouraging thoughtful discussion

#### Visual Characteristics

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
    
    <!-- Calming blue theme -->
    <key>postsViewCSS</key>
    <string>posts-view-byob.less</string>
    
    <!-- Typography focused on readability -->
    <key>listFont</key>
    <dict>
        <key>fontName</key>
        <string>ChalkboardSE-Regular</string>
        <key>fontSize</key>
        <real>16</real>
    </dict>
</dict>
```

#### CSS Implementation (posts-view-byob.less)

```less
@import "base.less";

// Warm, book-like background
body {
    background: linear-gradient(to bottom, #f5f5dc, #faf0e6);
    background-image: 
        radial-gradient(circle at 20% 20%, rgba(255, 255, 255, 0.1) 0%, transparent 50%),
        radial-gradient(circle at 80% 80%, rgba(139, 69, 19, 0.05) 0%, transparent 50%);
}

post {
    background-color: #ffffff;
    border: 1px solid #ddbf7f;
    border-radius: 6px;
    margin: 8px 0;
    padding: 12px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    
    &.seen {
        background-color: #f9f7f4;
        border-color: #d4af8c;
    }
}

// Book-inspired typography
.username {
    color: #8b4513;
    font-family: 'Georgia', serif;
    font-weight: bold;
    border-bottom: 1px solid #ddbf7f;
    padding-bottom: 2px;
}

.postbody {
    font-family: 'Georgia', 'Times New Roman', serif;
    line-height: 1.6;
    color: #2c2416;
    
    // Book-style paragraphs
    p {
        margin: 0.8em 0;
        text-indent: 1.2em;
    }
    
    // Chapter/section headings
    h3, h4 {
        color: #8b4513;
        font-family: 'Georgia', serif;
        border-bottom: 2px solid #ddbf7f;
        padding-bottom: 4px;
    }
}

// Quote styling like book excerpts
.bbc-quote {
    background: linear-gradient(to right, #f5f5dc, #ffffff);
    border-left: 4px solid #cd853f;
    font-style: italic;
    padding: 12px 16px;
    margin: 12px 0;
    position: relative;
    
    &:before {
        content: '"';
        font-size: 4em;
        color: #ddbf7f;
        position: absolute;
        top: -10px;
        left: 8px;
        line-height: 1;
    }
}

// Code blocks styled as handwritten notes
.bbc-code {
    background: #f9f7f4;
    border: 1px dashed #8b4513;
    font-family: 'Courier New', monospace;
    color: #8b4513;
    padding: 8px;
    margin: 8px 0;
}
```

#### Cultural Context

- **Literary focus**: Typography and styling emphasize readability and book aesthetic
- **Calm atmosphere**: Muted colors encourage thoughtful discussion
- **Handwritten feel**: Some elements styled to feel like margin notes

### Gas Chamber

**Forum ID**: 25 - Debate and controversial topics
**Theme Philosophy**: Stark, serious aesthetic reflecting serious discussions

#### Visual Characteristics

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

#### CSS Implementation (posts-view-gas-chamber.less)

```less
@import "base.less";

// Harsh, institutional styling
body {
    background: linear-gradient(to bottom, #3c4043, #2d3032);
    color: #e8eaed;
}

post {
    background-color: #1f1f1f;
    border: 1px solid #68cc24;
    color: #e8eaed;
    
    &.seen {
        background-color: #2a2a2a;
        border-color: #5ab420;
    }
}

.username {
    color: #68cc24;
    font-weight: bold;
    text-transform: uppercase;
}

// Harsh styling for serious topics
.postbody {
    strong {
        color: #ff6b6b;
        font-weight: 900;
    }
    
    em {
        color: #ffd93d;
        font-style: italic;
    }
}

.bbc-quote {
    background-color: #2a2a2a;
    border-left: 3px solid #68cc24;
    color: #cccccc;
}
```

## Retro/Novelty Themes

### Macinyos (Classic Mac OS)

**Forum Context**: Often used in YOSPOS for retro computing discussions
**Theme Philosophy**: Authentic Mac OS System 7 recreation

#### Visual Characteristics

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
    
    <key>postsViewCSS</key>
    <string>posts-view-macinyos.less</string>
    
    <key>loadingViewType</key>
    <string>macinyos</string>
</dict>
```

#### CSS Implementation (posts-view-macinyos.less)

```less
@import "base.less";

// Classic Mac desktop pattern
body {
    background: #c0c0c0 url('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAGUlEQVR4XmNgoCL4TyQcNZgoMJoYbTSaKDAAAFXxAf8FCstJAAAAAElFTkSuQmCC') repeat;
    font-family: 'Chicago', 'Monaco', monospace;
    font-size: 12px;
}

post {
    background-color: #ffffff;
    border: 2px outset #c0c0c0;
    margin: 4px;
    padding: 4px;
    
    &.seen {
        border: 2px inset #c0c0c0;
        background-color: #f0f0f0;
    }
}

// Classic Mac window title bar
.post-header {
    background: linear-gradient(to bottom, #ffffff 0%, #e0e0e0 50%, #c0c0c0 100%);
    border-bottom: 1px solid #808080;
    padding: 2px 4px;
    margin: -4px -4px 4px -4px;
}

.username {
    font-family: 'Chicago', monospace;
    font-size: 12px;
    font-weight: bold;
    color: #000000;
}

// Classic Mac button styling
.action-button {
    background: #c0c0c0;
    border: 1px outset #c0c0c0;
    border-radius: 0;
    font-family: 'Chicago', monospace;
    font-size: 10px;
    padding: 2px 8px;
    
    &:active {
        border: 1px inset #c0c0c0;
    }
}

// System 7 style scrollbars
::-webkit-scrollbar {
    width: 16px;
    background: #c0c0c0;
}

::-webkit-scrollbar-thumb {
    background: #808080;
    border: 1px outset #c0c0c0;
}

::-webkit-scrollbar-corner {
    background: #c0c0c0;
}
```

### Winpos95 (Windows 95)

**Theme Philosophy**: Nostalgic Windows 95 interface recreation

```less
@import "base.less";

// Windows 95 desktop
body {
    background: #008080;
    font-family: 'MS Sans Serif', sans-serif;
    font-size: 11px;
}

post {
    background-color: #c0c0c0;
    border: 2px outset #c0c0c0;
    
    &.seen {
        border: 2px inset #c0c0c0;
    }
}

// Win95 title bar
.post-header {
    background: linear-gradient(to right, #0000ff, #008080);
    color: #ffffff;
    font-weight: bold;
    padding: 2px;
    margin: -2px -2px 2px -2px;
}

.username {
    color: #ffffff;
    font-weight: bold;
}

// Win95 button styling
.action-button {
    background: #c0c0c0;
    border: 1px outset #c0c0c0;
    font-family: 'MS Sans Serif', sans-serif;
    font-size: 11px;
    
    &:active {
        border: 1px inset #c0c0c0;
    }
}
```

## Theme Testing and Validation

### Forum Context Testing

```swift
func testForumThemeApplication() {
    // Test YOSPOS theme auto-application
    let yosposThread = AwfulThread()
    yosposThread.forum?.forumID = "219"
    
    let postsVC = PostsPageViewController(thread: yosposThread)
    XCTAssertEqual(postsVC.theme.name, "yospos")
    
    // Test FYAD theme auto-application
    let fyadThread = AwfulThread()
    fyadThread.forum?.forumID = "26"
    
    let fyadPostsVC = PostsPageViewController(thread: fyadThread)
    XCTAssertEqual(fyadPostsVC.theme.name, "fyad")
}
```

### CSS Validation Testing

```swift
func testForumThemeCSS() {
    let themes = ["yospos", "fyad", "byob", "gas-chamber", "macinyos", "winpos95"]
    
    for themeName in themes {
        let theme = Theme.theme(named: themeName)!
        let css = theme["postsViewCSS"]
        
        XCTAssertNotNil(css, "Theme \(themeName) should have valid CSS")
        XCTAssertFalse(css!.isEmpty, "CSS should not be empty for \(themeName)")
    }
}
```

### Visual Regression Testing

Automated screenshot comparison ensures themes render consistently:

```swift
func testForumThemeVisualConsistency() {
    let themes = Theme.allThemes
    
    for theme in themes {
        let screenshot = captureThemeScreenshot(theme)
        let referenceImage = loadReferenceImage(for: theme.name)
        
        XCTAssertEqual(screenshot, referenceImage, 
                      "Theme \(theme.name) visual output should match reference")
    }
}
```

## Custom Forum Theme Creation

### Adding New Forum Themes

1. **Identify forum culture**: Understand the community's personality and discussion style
2. **Design color palette**: Choose colors that reflect the forum's character
3. **Create CSS file**: Implement custom styling in a new `.less` file
4. **Update Themes.plist**: Add theme definition with forum association
5. **Test thoroughly**: Verify theme works across different content types

### Theme Guidelines

- **Readability first**: Ensure text remains legible under all conditions
- **Cultural sensitivity**: Respect forum communities and avoid offensive styling
- **Performance awareness**: Minimize complex CSS that could slow rendering
- **Accessibility compliance**: Maintain sufficient color contrast ratios
- **Mobile compatibility**: Ensure themes work well on all screen sizes

Forum-specific themes are a key differentiator for Awful.app, creating unique experiences that celebrate the diverse culture of Something Awful's many communities while maintaining excellent usability and performance.