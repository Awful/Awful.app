# Thread Reading Flow

## Overview

The thread reading experience is the core functionality of Awful.app, allowing users to view and interact with forum posts. This flow includes unique pagination, post rendering, and navigation patterns that must be preserved during the SwiftUI migration.

## Core Components

### PostsPageViewController
- **Purpose**: Displays individual thread posts with HTML rendering
- **Key Features**:
  - Web view integration for rich post content
  - Custom pagination controls
  - Post metadata display
  - Quote and reply functionality
  - Image loading and caching

### Post Rendering System
- **HTML/CSS Integration**: Custom stylesheets for post formatting
- **Theme Integration**: Dynamic styling based on current theme
- **Image Handling**: Nuke-based image loading with caching
- **GIF Support**: FLAnimatedImage for animated content

## Navigation Patterns

### Page-Based Navigation
1. **Thread Entry**: User selects thread from forum list
2. **Initial Load**: First page of posts loads automatically
3. **Page Navigation**: Users can jump between pages
4. **Post Navigation**: Direct jumping to specific posts

### Navigation Controls
- **Page Picker**: Jump to specific page number
- **Next/Previous**: Sequential page navigation
- **First/Last**: Jump to thread beginning/end
- **Bookmark**: Mark current reading position

## Post Display Features

### Content Rendering
- **HTML Posts**: Rich formatting with CSS styling
- **Embedded Media**: Images, GIFs, and videos
- **Quote Blocks**: Nested quote formatting
- **Code Blocks**: Syntax highlighting for code
- **Smilie Integration**: Custom emoticons

### Post Metadata
- **Author Information**: Username, avatar, join date
- **Post Details**: Post number, timestamp, edit history
- **User Status**: Online/offline indicators
- **User Badges**: Moderator, admin, subscriber status

## Unique Behaviors

### Pagination System
- **Discrete Pages**: 40 posts per page (SA standard)
- **Page Preservation**: Remember reading position
- **Jump to Post**: Direct linking to specific posts
- **Infinite Scroll**: Optional continuous scrolling

### Reading Position
- **Last Read Tracking**: Mark and return to last read post
- **Scroll Position**: Preserve position within page
- **Cross-Device Sync**: Reading position across devices
- **Bookmark System**: Manual reading position markers

## User Interactions

### Post Actions
- **Quote**: Select text to quote in replies
- **Copy**: Copy post content to clipboard
- **Share**: Share individual posts
- **Report**: Flag inappropriate content
- **User Actions**: View profile, send PM, etc.

### Navigation Gestures
- **Swipe Navigation**: Swipe between pages
- **Pull to Refresh**: Reload current page
- **Long Press**: Context menus for posts
- **Tap to Jump**: Quick navigation controls

## Performance Considerations

### Loading Strategy
- **Progressive Loading**: Load pages on demand
- **Background Prefetch**: Preload adjacent pages
- **Cache Management**: Efficient HTML/image caching
- **Memory Management**: Limit loaded page count

### Rendering Optimization
- **Lazy Loading**: Defer heavy content rendering
- **Image Optimization**: Compressed image delivery
- **WebView Reuse**: Efficient web view management
- **CSS Optimization**: Minimized stylesheet loading

## Accessibility Features

### VoiceOver Support
- **Post Navigation**: Logical reading order
- **Content Description**: Accessible post content
- **Action Accessibility**: Clear action descriptions
- **Navigation Hints**: Helpful navigation guidance

### Visual Accessibility
- **Dynamic Type**: Respect system font sizing
- **High Contrast**: Support for accessibility themes
- **Color Indicators**: Non-color dependent status
- **Focus Management**: Keyboard navigation support

## Migration Considerations

### SwiftUI Conversion
1. **Replace UIWebView**: Use WKWebView in UIViewRepresentable
2. **Navigation Updates**: Use NavigationView/NavigationStack
3. **State Management**: Convert to @StateObject/@ObservableObject
4. **Gesture Handling**: Update to SwiftUI gesture system

### Behavioral Preservation
- Maintain exact pagination behavior
- Preserve reading position tracking
- Keep performance characteristics
- Maintain accessibility support

## Implementation Details

### Key Files
- `PostsPageViewController.swift`
- `PostsView.swift` (web view container)
- `PostsPageRenderer.swift` (HTML rendering)
- `PostsPageSettings.swift` (display preferences)

### Dependencies
- **WKWebView**: HTML content rendering
- **Nuke**: Image loading and caching
- **Stencil**: Template rendering
- **FLAnimatedImage**: GIF support
- **Core Data**: Post persistence

## Testing Scenarios

### Basic Reading
1. Open thread and verify first page loads
2. Navigate between pages
3. Test reading position preservation
4. Verify post rendering accuracy

### Performance Testing
- Large thread handling (1000+ posts)
- Image-heavy thread performance
- Memory usage during navigation
- Background loading efficiency

### Edge Cases
- Network interruption during loading
- Malformed HTML content
- Missing image handling
- Empty thread scenarios

## Known Issues

### Current Limitations
- WebView memory usage with large threads
- Occasional CSS rendering inconsistencies
- Image loading timeout handling
- Background refresh timing

### Migration Risks
- WebView integration complexity
- Performance regression potential
- Accessibility feature compatibility
- Custom gesture behavior preservation