# Universal Links

Awful.app supports Universal Links to provide seamless deep linking from web content into the native app experience. This allows forum links to open directly in the app when available.

## Overview

Universal Links enable:
- Seamless web-to-app transitions
- Deep linking without custom URL schemes
- Fallback to web when app isn't installed
- Improved user experience for forum links

## Configuration

### Associated Domains

The app declares associated domains in its entitlements:

```xml
<!-- This would be in production entitlements -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:forums.somethingawful.com</string>
    <string>applinks:archives.somethingawful.com</string>
</array>
```

### Apple App Site Association (AASA)

The forum domains must host an AASA file at `/.well-known/apple-app-site-association`:

```json
{
    "applinks": {
        "details": [
            {
                "appIDs": ["TEAMID.com.awfulapp.Awful"],
                "components": [
                    {
                        "comment": "Forum display pages",
                        "/": "/forumdisplay.php",
                        "?": {
                            "forumid": "?*"
                        }
                    },
                    {
                        "comment": "Thread pages",
                        "/": "/showthread.php",
                        "?": {
                            "threadid": "?*"
                        }
                    },
                    {
                        "comment": "Post links",
                        "/": "/showthread.php",
                        "?": {
                            "goto": "post",
                            "postid": "?*"
                        }
                    },
                    {
                        "comment": "User profiles",
                        "/": "/member.php",
                        "?": {
                            "action": "getinfo",
                            "userid": "?*"
                        }
                    },
                    {
                        "comment": "Ban list and rap sheets",
                        "/": "/banlist.php"
                    }
                ]
            }
        ]
    }
}
```

## Implementation

### App Delegate Integration

Handle incoming Universal Links in the app delegate:

#### iOS 13+ (Scene-based)
```swift
// SceneDelegate.swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else {
        return
    }
    
    handleUniversalLink(url)
}

func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    handleUniversalLink(url)
}
```

#### iOS 12 and Earlier
```swift
// AppDelegate.swift
func application(_ application: UIApplication, 
                continue userActivity: NSUserActivity, 
                restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else {
        return false
    }
    
    return handleUniversalLink(url)
}
```

### URL Processing

Universal Links are processed through the same routing system as custom schemes:

```swift
func handleUniversalLink(_ url: URL) -> Bool {
    do {
        let route = try AwfulRoute(url)
        return urlRouter.route(route)
    } catch {
        print("Failed to parse Universal Link: \(url)")
        
        // Fallback: open in Safari
        UIApplication.shared.open(url)
        return false
    }
}
```

### Route Parsing

The existing `AwfulRoute` system handles both custom schemes and Universal Links:

```swift
extension AwfulRoute {
    init(_ url: URL) throws {
        switch (url.scheme ?? "").caseInsensitive {
        case "awful":
            self = try AwfulRoute.parse(awful: url)
            
        case "awfulhttp", "awfulhttps", "http", "https":
            self = try AwfulRoute.parse(http: url)
            
        default:
            throw ParseError.schemeUnknown
        }
    }
}
```

## Supported URL Patterns

### Forum Display Pages

**Pattern**: `https://forums.somethingawful.com/forumdisplay.php?forumid=123`
**Route**: `.forum(id: "123")`

### Thread Pages

**Pattern**: `https://forums.somethingawful.com/showthread.php?threadid=456&pagenumber=2`
**Route**: `.threadPage(threadID: "456", page: .specific(2), .noseen)`

### Specific Posts

**Pattern**: `https://forums.somethingawful.com/showthread.php?goto=post&postid=789`
**Route**: `.post(id: "789", .noseen)`

### User Profiles

**Pattern**: `https://forums.somethingawful.com/member.php?action=getinfo&userid=123`
**Route**: `.profile(userID: "123")`

### Ban List

**Pattern**: `https://forums.somethingawful.com/banlist.php`
**Route**: `.lepersColony`

**Pattern**: `https://forums.somethingawful.com/banlist.php?userid=123`
**Route**: `.rapSheet(userID: "123")`

## AASA File Considerations

### Path Matching

The AASA file uses path components to match URLs:

```json
{
    "comment": "Match specific paths with parameters",
    "/": "/showthread.php",
    "?": {
        "threadid": "?*",
        "pagenumber": "?*"
    }
}
```

### Exclusions

Exclude certain paths that shouldn't open in the app:

```json
{
    "comment": "Exclude admin and login pages",
    "/": "/admin/*",
    "exclude": true
}
```

### Wildcards

Use wildcards for flexible matching:

```json
{
    "comment": "Match all forum URLs",
    "/": "/forumdisplay.php*"
}
```

## Testing Universal Links

### Development Testing

Test Universal Links during development:

1. **Simulator Testing**:
   - Use Safari in Simulator
   - Paste forum URLs in address bar
   - Verify app opens instead of Safari

2. **Device Testing**:
   - Send URLs via Messages or Mail
   - Tap links to test opening behavior
   - Verify fallback to Safari when app not installed

3. **AASA Validation**:
   - Use Apple's AASA validator
   - Test from different domains
   - Verify JSON syntax and structure

### Debug Information

Enable Universal Links debugging:

```swift
func debugUniversalLink(_ url: URL) {
    print("Universal Link received: \(url)")
    print("Host: \(url.host ?? "none")")
    print("Path: \(url.path)")
    print("Query: \(url.query ?? "none")")
    
    do {
        let route = try AwfulRoute(url)
        print("Parsed route: \(route)")
    } catch {
        print("Parse error: \(error)")
    }
}
```

### AASA File Debugging

Validate AASA file configuration:

```bash
# Check AASA file accessibility
curl -I https://forums.somethingawful.com/.well-known/apple-app-site-association

# Download and validate AASA content
curl https://forums.somethingawful.com/.well-known/apple-app-site-association | jq
```

## Error Handling

### Parsing Failures

Handle malformed or unsupported URLs gracefully:

```swift
func handleUniversalLink(_ url: URL) -> Bool {
    do {
        let route = try AwfulRoute(url)
        return urlRouter.route(route)
    } catch AwfulRoute.ParseError.hostNotSupported {
        // Unknown host, let Safari handle it
        return false
    } catch AwfulRoute.ParseError.pathNotSupported {
        // Unsupported path, fallback to Safari
        UIApplication.shared.open(url)
        return false
    } catch {
        // Other parsing errors
        print("Universal Link parsing failed: \(error)")
        return false
    }
}
```

### Network Failures

Handle cases where content isn't available:

```swift
func routeToContent(_ route: AwfulRoute) {
    switch route {
    case .threadPage(let threadID, let page, _):
        // Check if thread exists locally
        if threadExists(threadID) {
            navigateToThread(threadID, page: page)
        } else {
            // Show loading and fetch from network
            showLoadingAndFetch(threadID: threadID, page: page)
        }
    }
}
```

## User Experience

### Seamless Transitions

Provide smooth transitions from web to app:

```swift
func navigateToRoute(_ route: AwfulRoute) {
    // Animate transition if coming from Universal Link
    let animated = isComingFromUniversalLink
    
    switch route {
    case .threadPage(let threadID, let page, _):
        let postsVC = PostsPageViewController(thread: thread)
        postsVC.loadPage(page, animated: animated)
        showPostsViewController(postsVC, animated: animated)
    }
}
```

### Loading States

Show appropriate loading states for deep links:

```swift
func handleDeepLink(to threadID: String, page: ThreadPage) {
    // Show immediate feedback
    let loadingVC = LoadingViewController(message: "Opening Thread...")
    present(loadingVC, animated: true)
    
    // Fetch content
    Task {
        do {
            let thread = try await forumsClient.fetchThread(threadID)
            let postsVC = PostsPageViewController(thread: thread)
            postsVC.loadPage(page)
            
            await MainActor.run {
                loadingVC.dismiss(animated: true) {
                    self.showPostsViewController(postsVC)
                }
            }
        } catch {
            await MainActor.run {
                loadingVC.showError(error)
            }
        }
    }
}
```

## Security Considerations

### Domain Verification

Universal Links provide security benefits:
- Domain ownership verification by Apple
- No scheme hijacking possible
- Secure association between domain and app

### Content Validation

Validate incoming links for security:

```swift
func validateUniversalLink(_ url: URL) -> Bool {
    // Verify expected domains
    guard let host = url.host,
          ["forums.somethingawful.com", "archives.somethingawful.com"].contains(host) else {
        return false
    }
    
    // Verify HTTPS
    guard url.scheme == "https" else {
        return false
    }
    
    // Additional validation as needed
    return true
}
```

## Analytics and Monitoring

### Link Analytics

Track Universal Link usage:

```swift
func trackUniversalLink(_ url: URL, route: AwfulRoute) {
    // Track successful Universal Link opens
    Analytics.track("universal_link_opened", parameters: [
        "url": url.absoluteString,
        "route_type": String(describing: route)
    ])
}
```

### Performance Monitoring

Monitor Universal Link performance:

```swift
func measureUniversalLinkPerformance(_ url: URL) -> TimeInterval {
    let startTime = Date()
    
    handleUniversalLink(url)
    
    let endTime = Date()
    return endTime.timeIntervalSince(startTime)
}
```

## Migration from Custom Schemes

### Gradual Migration

Support both Universal Links and custom schemes during transition:

```swift
func handleIncomingURL(_ url: URL) -> Bool {
    // Try Universal Link first
    if url.scheme == "https" || url.scheme == "http" {
        return handleUniversalLink(url)
    }
    
    // Fallback to custom scheme
    if url.scheme == "awful" {
        return handleCustomScheme(url)
    }
    
    return false
}
```

### Backward Compatibility

Maintain support for existing custom scheme bookmarks:

```swift
// Convert custom scheme URLs to Universal Links
extension URL {
    var universalLinkEquivalent: URL? {
        guard scheme == "awful" else { return nil }
        
        // Convert awful:// URLs to https:// equivalents
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        components?.host = "forums.somethingawful.com"
        
        return components?.url
    }
}
```

## Future Enhancements

### Enhanced Deep Linking

Potential improvements:
- More granular URL patterns
- Query parameter preservation
- Search query deep linking
- User preference URLs

### Performance Optimization

Optimization opportunities:
- Preload content for common links
- Cache route parsing results
- Background content prefetching

## Troubleshooting

### Common Issues

**Universal Links not working:**
- Verify AASA file is accessible
- Check associated domains in entitlements
- Test with fresh app install
- Validate JSON syntax in AASA file

**Links opening in Safari instead of app:**
- Check AASA file URL patterns
- Verify app is installed
- Test with different link sources
- Check for iOS version compatibility

**AASA file not loading:**
- Verify HTTPS configuration
- Check server headers
- Test file accessibility
- Validate domain ownership

### Debugging Commands

```bash
# Test AASA file
curl -H "User-Agent: AASA-Bot" https://forums.somethingawful.com/.well-known/apple-app-site-association

# Validate JSON
cat apple-app-site-association | python -m json.tool

# Test Universal Link
xcrun simctl openurl booted "https://forums.somethingawful.com/showthread.php?threadid=123"
```

## References

- [Universal Links Documentation](https://developer.apple.com/ios/universal-links/)
- [Apple App Site Association Guide](https://developer.apple.com/documentation/bundleresources/applinks)
- [Universal Links Best Practices](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
- [AASA File Validation](https://search.developer.apple.com/appsearch-validation-tool/)