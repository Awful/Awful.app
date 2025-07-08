# Handoff Integration

Awful.app supports iOS Handoff (Continuity) to allow seamless browsing continuation across Apple devices. Users can start reading a thread on one device and continue on another.

## Overview

Handoff integration allows users to:
- Continue reading threads across devices
- Switch between iPhone, iPad, and Mac
- Resume at the exact page and position
- Access content via web fallback when app isn't installed

## Architecture

### NSUserActivity Integration

The app uses `NSUserActivity` to track and share browsing state:

```swift
extension NSUserActivity {
    var route: AwfulRoute? {
        get { /* Parse activity into route */ }
        set { /* Convert route to activity */ }
    }
}
```

### Activity Types

Three main activity types are supported:

```swift
enum ActivityType {
    static let browsingPosts = "com.awfulapp.Awful.activity.browsing-posts"
    static let listingThreads = "com.awfulapp.Awful.activity.listing-threads" 
    static let readingMessage = "com.awfulapp.Awful.activity.reading-message"
}
```

## Activity Configuration

### Info.plist Registration

Activity types must be declared in Info.plist:

```xml
<key>NSUserActivityTypes</key>
<array>
    <string>com.awfulapp.Awful.activity.browsing-posts</string>
    <string>com.awfulapp.Awful.activity.listing-threads</string>
    <string>com.awfulapp.Awful.activity.reading-message</string>
</array>
```

### Activity Properties

Each activity includes metadata for proper restoration:

```swift
// Core properties
activity.title = "Reading Thread"
activity.isEligibleForHandoff = true
activity.isEligibleForSearch = false
activity.webpageURL = route.httpURL

// User info for state restoration
activity.addUserInfoEntries(from: [
    Keys.threadID: threadID,
    Keys.page: pageNumber,
    Keys.version: handoffUserInfoVersion
])
```

## Activity Types Implementation

### Browsing Posts

Tracks thread reading activities:

```swift
case Handoff.ActivityType.browsingPosts:
    guard let threadID = userInfo[Keys.threadID] as? String else { return nil }
    
    let pageNumber = userInfo[Keys.page] as? Int
    let page = pageNumber.map { ThreadPage.specific($0) } ?? .nextUnread
    
    if let userID = userInfo[Keys.filteredThreadUserID] as? String {
        return .threadPageSingleUser(threadID: threadID, 
                                   userID: userID, 
                                   page: page, 
                                   .noseen)
    } else {
        return .threadPage(threadID: threadID, page: page, .noseen)
    }
```

### Listing Threads

Tracks forum browsing activities:

```swift
case Handoff.ActivityType.listingThreads:
    if userInfo[Keys.bookmarks] != nil {
        return .bookmarks
    } else if let forumID = userInfo[Keys.forumID] as? String {
        return .forum(id: forumID)
    } else {
        return nil
    }
```

### Reading Messages

Tracks private message activities:

```swift
case Handoff.ActivityType.readingMessage:
    guard let messageID = userInfo[Keys.messageID] as? String else { return nil }
    return .message(id: messageID)
```

## State Management

### Activity Creation

Activities are created when users navigate:

```swift
// In view controllers
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    let activity = NSUserActivity(activityType: Handoff.ActivityType.browsingPosts)
    activity.route = .threadPage(threadID: thread.threadID, 
                               page: .specific(currentPage), 
                               .noseen)
    
    userActivity = activity
    activity.becomeCurrent()
}
```

### Activity Updates

Activities are updated as users navigate:

```swift
func updateUserActivity(for page: Int) {
    guard let activity = userActivity else { return }
    
    activity.addUserInfoEntries(from: [
        Keys.page: page,
        Keys.threadID: thread.threadID
    ])
    
    activity.needsSave = true
}
```

### Activity Invalidation

Activities are invalidated when appropriate:

```swift
override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    userActivity?.invalidate()
}
```

## Web Fallback

### Webpage URL Generation

Each activity includes a web fallback URL:

```swift
extension AwfulRoute {
    var httpURL: URL {
        var components = URLComponents()
        
        switch self {
        case let .threadPage(threadID: threadID, page: page, updateSeen):
            components.path = "showthread.php"
            components.queryItems = [
                URLQueryItem(name: "threadid", value: threadID),
                URLQueryItem(name: "perpage", value: "40"),
                page.queryItem,
                URLQueryItem(name: "noseen", value: updateSeen.queryValue)
            ]
        // ... other cases
        }
        
        return components.url(relativeTo: baseURL)!
    }
}
```

### Cross-Platform Support

Web URLs work across platforms:
- iOS devices with app installed open in app
- iOS devices without app open in Safari
- macOS opens in default browser
- Other platforms access web version

## User Info Keys

### Standardized Keys

User info uses consistent key names:

```swift
private enum Keys {
    static let bookmarks = "bookmarks"
    static let filteredThreadUserID = "filteredUserID"
    static let forumID = "forumID" 
    static let messageID = "messageID"
    static let page = "page"
    static let postID = "postID"
    static let threadID = "threadID"
    static let version = "version"
}
```

### Version Management

Activities include version information for future compatibility:

```swift
private let handoffUserInfoVersion = 1

// In activity creation
activity.addUserInfoEntries(from: [
    Keys.version: handoffUserInfoVersion
])
```

## Integration Points

### App Delegate

Handle incoming Handoff activities:

```swift
func application(_ application: UIApplication, 
                continue userActivity: NSUserActivity, 
                restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    
    guard let route = userActivity.route else { return false }
    
    // Route to appropriate screen
    return urlRouter.route(route)
}
```

### Scene Delegate (iOS 13+)

Handle activities in scene-based apps:

```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let route = userActivity.route else { return }
    urlRouter.route(route)
}
```

### View Controllers

Manage activity lifecycle:

```swift
class PostsPageViewController: UIViewController {
    override func updateUserActivityState(_ activity: NSUserActivity) {
        super.updateUserActivityState(activity)
        
        activity.addUserInfoEntries(from: [
            Keys.threadID: thread.threadID,
            Keys.page: currentPage,
            Keys.postID: visiblePost?.postID
        ])
    }
}
```

## Performance Considerations

### Activity Timing

Balance activity updates with performance:
- Update activities on significant navigation
- Avoid excessive updates during scrolling
- Batch updates when possible
- Invalidate when appropriate

### Data Size

Keep user info lightweight:
- Use IDs instead of full objects
- Minimize custom data
- Rely on web fallback for complex state

### Network Impact

Activities should not require network requests:
- Store sufficient local state
- Use cached data when possible
- Handle missing data gracefully

## Privacy and Security

### User Consent

Handoff respects user privacy settings:
- Honors system Handoff preferences
- No explicit consent required
- Users can disable per-app

### Data Transmission

Activity data is transmitted securely:
- Encrypted between devices
- Limited to same iCloud account
- Temporary storage only

### Sensitive Information

Avoid including sensitive data:
- No passwords or tokens
- Public identifiers only
- Web-safe information

## Testing

### Multi-Device Testing

Test Handoff functionality:
1. Set up multiple devices with same iCloud account
2. Enable Handoff in System Preferences/Settings
3. Navigate in app on one device
4. Check for activity on other devices
5. Verify restoration behavior

### Activity Validation

Test activity creation and parsing:

```swift
func testHandoffActivity() {
    let route = AwfulRoute.threadPage(threadID: "123", page: .specific(5), .noseen)
    
    let activity = NSUserActivity(activityType: Handoff.ActivityType.browsingPosts)
    activity.route = route
    
    let parsedRoute = activity.route
    XCTAssertEqual(parsedRoute, route)
}
```

### Web Fallback Testing

Verify web URLs work correctly:
- Test in Safari on iOS
- Test in browsers on other platforms
- Verify parameter handling
- Check URL encoding

## Debugging

### Activity Monitoring

Debug activities using system tools:
- Xcode console logging
- iOS Settings > Developer > Handoff debugging
- macOS Console app filtering

### Common Issues

**Activities not appearing:**
- Check iCloud account consistency
- Verify Handoff settings
- Test with simple activities

**Restoration failures:**
- Validate user info structure
- Check for required keys
- Test web fallback URLs

**Performance problems:**
- Monitor update frequency
- Profile activity creation
- Check for memory leaks

## Best Practices

### Activity Design

Create meaningful activities:
- Use descriptive titles
- Provide useful context
- Support graceful fallbacks
- Keep state minimal

### State Management

Manage activity lifecycle properly:
- Create activities early
- Update incrementally
- Invalidate when done
- Handle restoration gracefully

### User Experience

Optimize for user benefit:
- Preserve meaningful context
- Restore to useful locations
- Handle missing data well
- Provide clear navigation

## Future Enhancements

### Enhanced Context

Potential improvements:
- Scroll position preservation
- Reading progress tracking
- Cross-device preferences
- Enhanced metadata

### Platform Expansion

Extended platform support:
- macOS app integration
- Apple Watch activities
- CarPlay support
- Apple TV integration

## References

- [Apple Handoff Documentation](https://developer.apple.com/documentation/foundation/nsuseractivity)
- [iOS Human Interface Guidelines - Handoff](https://developer.apple.com/design/human-interface-guidelines/handoff)
- [NSUserActivity Class Reference](https://developer.apple.com/documentation/foundation/nsuseractivity)