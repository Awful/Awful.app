# URL Schemes and Deep Linking

Awful.app provides comprehensive URL scheme support for deep linking into specific parts of the application. This enables integration with other apps, Safari, and system features like Handoff.

## Overview

The app supports multiple URL schemes for different scenarios:
- `awful://` - Primary custom scheme for deep linking
- `awfulhttp://` and `awfulhttps://` - Safari extension schemes
- Standard `http://` and `https://` - Forum URL handling

## URL Scheme Registration

### Info.plist Configuration

The app registers URL schemes in Info.plist:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.awfulapp.Awful</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>awful</string>
            <string>awfulhttp</string>
            <string>awfulhttps</string>
        </array>
    </dict>
</array>
```

### Queried Schemes

The app can query and open other apps:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>brave</string>
    <string>firefox</string>
    <string>googlechrome</string>
    <string>microsoft-edge-http</string>
    <string>twitter</string>
    <string>vimeo</string>
    <string>vlc</string>
    <string>youtube</string>
</array>
```

## Route System Architecture

### AwfulRoute Enumeration

The `AwfulRoute` enum defines all supported deep link destinations:

```swift
enum AwfulRoute {
    case bookmarks
    case forum(id: String)
    case forumList
    case lepersColony
    case message(id: String)
    case messagesList
    case post(id: String, UpdateSeen)
    case profile(userID: String)
    case rapSheet(userID: String)
    case settings
    case threadPage(threadID: String, page: ThreadPage, UpdateSeen)
    case threadPageSingleUser(threadID: String, userID: String, page: ThreadPage, UpdateSeen)
}
```

### AwfulURLRouter

The router translates URLs into navigation actions:

```swift
struct AwfulURLRouter {
    private let managedObjectContext: NSManagedObjectContext
    private let rootViewController: UIViewController
    
    @discardableResult
    func route(_ route: AwfulRoute) -> Bool {
        // Implementation handles navigation logic
    }
}
```

## URL Parsing

### Awful Scheme URLs

Custom `awful://` URLs use a hierarchical structure:

#### Format
```
awful://host/path?parameters
```

#### Supported Hosts

**Forums**: `awful://forums/[forumID]`
- `awful://forums/` - Forum list
- `awful://forums/123` - Specific forum

**Threads**: `awful://threads/threadID/pages/pageNumber?userid=userID&noseen=1`
- `awful://threads/123` - First page of thread
- `awful://threads/123/pages/last` - Last page
- `awful://threads/123/pages/unread` - Next unread post
- `awful://threads/123/pages/5` - Specific page

**Posts**: `awful://posts/postID?noseen=1`
- `awful://posts/456` - Jump to specific post

**Users**: `awful://users/userID`
- `awful://users/789` - User profile

**Ban List**: `awful://banlist/[userID]`
- `awful://banlist/` - Leper's Colony
- `awful://banlist/789` - User's rap sheet

**Messages**: `awful://messages/[messageID]`
- `awful://messages/` - Private message list
- `awful://messages/123` - Specific message

**Settings**: `awful://settings/`

**Bookmarks**: `awful://bookmarks/`

### HTTP(S) URL Handling

The app can handle forum URLs directly:

#### Forum URLs
```
https://forums.somethingawful.com/forumdisplay.php?forumid=123
```

#### Thread URLs
```
https://forums.somethingawful.com/showthread.php?threadid=456&pagenumber=2
```

#### Post URLs
```
https://forums.somethingawful.com/showthread.php?goto=post&postid=789
```

#### Profile URLs
```
https://forums.somethingawful.com/member.php?userid=123
```

### Safari Extension Schemes

Safari can convert forum URLs using `awfulhttp://` or `awfulhttps://`:

```
awfulhttps://forums.somethingawful.com/showthread.php?threadid=123
```

This allows bookmarklet-style integration with Safari.

## URL Parameters

### Common Parameters

**noseen**: Controls read state tracking
- `noseen=1` - Don't mark as read
- `noseen=0` or omitted - Mark as read

**userid**: Filter by specific user
- Used in thread URLs to show only one user's posts

**pagenumber**: Specific page number
- Used in thread pagination

### Special Page Values

**Thread pages** support special values:
- `last` - Jump to last page
- `unread` - Jump to next unread post
- Numbers - Specific page (1-based)

## Navigation Integration

### Route Handling

The router integrates with the app's navigation structure:

```swift
// Example: Showing a specific thread
case let .threadPage(threadID: threadID, page: page, updateSeen):
    let thread = AwfulThread.objectForKey(threadKey, in: managedObjectContext)
    let postsVC = PostsPageViewController(thread: thread)
    postsVC.loadPage(page, updatingCache: true, updatingLastReadPost: updateLastRead)
    return showPostsViewController(postsVC)
```

### Split View Handling

The router adapts to different interface configurations:
- Single pane (iPhone)
- Split view (iPad)
- Tab bar navigation
- Modal presentations

### Loading States

For missing content, the router provides loading feedback:

```swift
let overlay = MRProgressOverlayView.showOverlayAdded(to: rootView, 
                                                   title: "Locating Post", 
                                                   mode: .indeterminate, 
                                                   animated: true)
```

## External Integration

### Safari Bookmarklet

Users can create bookmarklets to open forum pages in Awful:

```javascript
javascript:location.href='awful' + location.href;
```

### Other Apps

Apps can deep link into Awful using URL schemes:

```swift
// Swift
let url = URL(string: "awful://threads/123")!
UIApplication.shared.open(url)

// Objective-C
NSURL *url = [NSURL URLWithString:@"awful://threads/123"];
[[UIApplication sharedApplication] openURL:url];
```

## Pasteboard Integration

### Automatic URL Detection

The app checks pasteboard contents when becoming active:

```swift
// In AppDelegate or SceneDelegate
func applicationDidBecomeActive(_ application: UIApplication) {
    openCopiedURLController.checkForCopiedURL()
}
```

### User Confirmation

When an Awful-compatible URL is detected:
1. User is prompted to open the URL
2. URL is parsed and validated
3. Navigation occurs if user confirms

## Error Handling

### Parse Errors

The URL parser handles various error conditions:

```swift
enum ParseError: Error {
    case hostNotSupported
    case invalidPage
    case invalidPath(reason: String)
    case missingForumID
    case missingThreadID
    case missingUserID
    case pathNotSupported
    case schemeUnknown
    case unimplementedAwfulSchemeHost
}
```

### Recovery Strategies

- Invalid URLs show error alerts
- Missing content triggers network requests
- Malformed parameters use sensible defaults
- Unsupported schemes are ignored gracefully

## Testing

### URL Testing

Test various URL formats:

```swift
func testURLParsing() {
    // Test basic thread URL
    let url = URL(string: "awful://threads/123")!
    let route = try! AwfulRoute(url)
    XCTAssertEqual(route, .threadPage(threadID: "123", page: .first, .noseen))
    
    // Test complex thread URL
    let complexURL = URL(string: "awful://threads/123/pages/5?userid=456&noseen=1")!
    let complexRoute = try! AwfulRoute(complexURL)
    XCTAssertEqual(complexRoute, .threadPageSingleUser(threadID: "123", 
                                                       userID: "456", 
                                                       page: .specific(5), 
                                                       .noseen))
}
```

### Integration Testing

Test the complete flow:
1. URL construction
2. URL parsing
3. Route execution
4. Navigation completion

## Best Practices

### URL Construction

When creating URLs programmatically:
- Use URL components for proper encoding
- Validate required parameters
- Handle optional parameters gracefully
- Test edge cases

### Route Design

Design routes to be:
- Human-readable when possible
- Consistent in structure
- Extensible for future features
- Compatible with web URLs

### Error Messages

Provide helpful error messages:
- Explain what went wrong
- Suggest corrective actions
- Include relevant context
- Log details for debugging

## Future Enhancements

### Planned Features
- More granular post navigation
- Search query deep linking
- User preference URLs
- Compose pre-population

### URL Structure Evolution
- Versioned URL schemes
- Backward compatibility
- Migration strategies
- Deprecation handling

## Debugging

### URL Testing Tools

Use various tools to test URL handling:
- Safari bookmarklets
- Terminal `open` command
- Simulator custom URL schemes
- Network request interception

### Common Issues

**URLs not opening app:**
- Check scheme registration
- Verify app installation
- Test with simple URLs first

**Navigation failures:**
- Check route parsing
- Verify data availability
- Test with sample data

**Parameter handling:**
- URL encode special characters
- Test with edge case values
- Validate parameter combinations

## References

- [Apple URL Scheme Documentation](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Universal Links Guide](https://developer.apple.com/ios/universal-links/)
- [NSURLComponents Reference](https://developer.apple.com/documentation/foundation/nsurlcomponents)