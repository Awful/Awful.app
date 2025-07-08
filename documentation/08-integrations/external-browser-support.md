# External Browser Support

Awful.app provides comprehensive support for opening links in various external browsers, giving users the flexibility to use their preferred browser for web content.

## Overview

The app supports multiple browsers through:
- Custom UIActivity implementations
- URL scheme detection and handling
- Dynamic browser availability checking
- Fallback strategies for unsupported browsers

## Supported Browsers

### Primary Browsers

The app includes built-in support for:

#### Safari
- **URL Scheme**: `http://` / `https://` (system default)
- **Implementation**: `SafariActivity`
- **Always Available**: System browser

#### Google Chrome
- **URL Scheme**: `googlechrome://`
- **Implementation**: `ChromeActivity` (via ARChromeActivity)
- **Detection**: `googlechrome://` scheme query

#### Mozilla Firefox
- **URL Scheme**: `firefox://`
- **Implementation**: Custom activity
- **Detection**: `firefox://` scheme query

#### Microsoft Edge
- **URL Scheme**: `microsoft-edge-http://`
- **Implementation**: Custom activity
- **Detection**: `microsoft-edge-http://` scheme query

#### Brave Browser
- **URL Scheme**: `brave://`
- **Implementation**: Custom activity
- **Detection**: `brave://` scheme query

### URL Scheme Registration

All supported browsers are declared in Info.plist:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>brave</string>
    <string>firefox</string>
    <string>googlechrome</string>
    <string>http</string>
    <string>https</string>
    <string>microsoft-edge-http</string>
</array>
```

## Implementation Architecture

### Browser Detection

The app dynamically detects available browsers:

```swift
enum SupportedBrowser: String, CaseIterable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case firefox = "Firefox"
    case edge = "Microsoft Edge"
    case brave = "Brave"
    
    var urlScheme: String {
        switch self {
        case .safari:
            return "http"
        case .chrome:
            return "googlechrome"
        case .firefox:
            return "firefox"
        case .edge:
            return "microsoft-edge-http"
        case .brave:
            return "brave"
        }
    }
    
    var isInstalled: Bool {
        let testURL = URL(string: "\(urlScheme)://")!
        return UIApplication.shared.canOpenURL(testURL)
    }
}
```

### Chrome Integration

Chrome support uses the ARChromeActivity library:

```swift
// ChromeActivity.swift
import ARChromeActivity

final class ChromeActivity: ARChromeActivity {
    override var activityTitle: String? {
        return "Open in Chrome"
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        // Check if Chrome is installed
        guard SupportedBrowser.chrome.isInstalled else { return false }
        
        // Verify we have valid URLs
        return activityItems.contains { item in
            guard let url = item as? URL else { return false }
            return url.scheme == "http" || url.scheme == "https"
        }
    }
}
```

### URL Conversion

Different browsers require different URL formats:

```swift
extension URL {
    func browserURL(for browser: SupportedBrowser) -> URL {
        switch browser {
        case .safari:
            return self
            
        case .chrome:
            // Convert http(s):// to googlechrome://
            var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
            components.scheme = scheme == "https" ? "googlechromes" : "googlechrome"
            return components.url ?? self
            
        case .firefox:
            // Convert to firefox://open-url?url=
            var components = URLComponents()
            components.scheme = "firefox"
            components.host = "open-url"
            components.queryItems = [URLQueryItem(name: "url", value: absoluteString)]
            return components.url ?? self
            
        case .edge:
            // Convert to microsoft-edge-http(s)://
            var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
            components.scheme = "microsoft-edge-\(scheme!)"
            return components.url ?? self
            
        case .brave:
            // Convert to brave://open-url?url=
            var components = URLComponents()
            components.scheme = "brave"
            components.host = "open-url"
            components.queryItems = [URLQueryItem(name: "url", value: absoluteString)]
            return components.url ?? self
        }
    }
}
```

## Activity Integration

### Custom Activity Classes

Each browser has a corresponding UIActivity:

```swift
class FirefoxActivity: UIActivity {
    private var url: URL?
    
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("FirefoxActivity")
    }
    
    override var activityTitle: String? {
        return "Open in Firefox"
    }
    
    override var activityImage: UIImage? {
        return UIImage(named: "firefox-activity-icon")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        guard SupportedBrowser.firefox.isInstalled else { return false }
        
        return activityItems.contains { item in
            guard let url = item as? URL else { return false }
            return url.scheme == "http" || url.scheme == "https"
        }
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        url = activityItems.compactMap { $0 as? URL }.first
    }
    
    override func perform() {
        guard let url = url else {
            activityDidFinish(false)
            return
        }
        
        let firefoxURL = url.browserURL(for: .firefox)
        
        UIApplication.shared.open(firefoxURL) { success in
            DispatchQueue.main.async {
                self.activityDidFinish(success)
            }
        }
    }
}
```

### Dynamic Activity Lists

Activity lists adapt to installed browsers:

```swift
class BrowserActivityProvider {
    static func availableActivities() -> [UIActivity] {
        var activities: [UIActivity] = []
        
        // Safari is always available
        activities.append(SafariActivity())
        
        // Add browser-specific activities based on availability
        if SupportedBrowser.chrome.isInstalled {
            activities.append(ChromeActivity())
        }
        
        if SupportedBrowser.firefox.isInstalled {
            activities.append(FirefoxActivity())
        }
        
        if SupportedBrowser.edge.isInstalled {
            activities.append(EdgeActivity())
        }
        
        if SupportedBrowser.brave.isInstalled {
            activities.append(BraveActivity())
        }
        
        return activities
    }
}
```

## User Interface Integration

### Share Sheets

Browser activities appear in standard share sheets:

```swift
func presentBrowserOptions(for url: URL, from view: UIView) {
    let activityVC = UIActivityViewController(
        activityItems: [url],
        applicationActivities: BrowserActivityProvider.availableActivities()
    )
    
    // Exclude system activities that conflict
    activityVC.excludedActivityTypes = [
        .openInIBooks,
        .addToReadingList
    ]
    
    // iPad popover configuration
    if let popover = activityVC.popoverPresentationController {
        popover.sourceView = view
        popover.sourceRect = view.bounds
    }
    
    present(activityVC, animated: true)
}
```

### Context Menus

Long press context menus include browser options:

```swift
func contextMenuConfiguration(for url: URL) -> UIContextMenuConfiguration {
    return UIContextMenuConfiguration(
        identifier: nil,
        previewProvider: nil
    ) { _ in
        let browserActions = BrowserActivityProvider.availableActivities()
            .map { activity in
                UIAction(
                    title: activity.activityTitle ?? "Open",
                    image: activity.activityImage
                ) { _ in
                    activity.prepare(withActivityItems: [url])
                    activity.perform()
                }
            }
        
        return UIMenu(title: "Open in Browser", children: browserActions)
    }
}
```

## Default Browser Support

### User Preferences

The app can store user browser preferences:

```swift
@FoilDefaultStorage(Settings.preferredBrowser) 
private var preferredBrowser: String?

enum PreferredBrowser: String, CaseIterable {
    case system = "System"
    case safari = "Safari"
    case chrome = "Chrome"
    case firefox = "Firefox"
    case edge = "Edge"
    case brave = "Brave"
}
```

### Smart Defaults

Automatically choose appropriate browser:

```swift
func openURL(_ url: URL) {
    let preferredBrowser = userPreferredBrowser()
    
    if preferredBrowser.isInstalled {
        openInBrowser(url, browser: preferredBrowser)
    } else {
        // Fallback to Safari
        openInBrowser(url, browser: .safari)
    }
}
```

## Error Handling

### Fallback Strategies

Handle cases where preferred browser fails:

```swift
func openInBrowser(_ url: URL, browser: SupportedBrowser) {
    let browserURL = url.browserURL(for: browser)
    
    UIApplication.shared.open(browserURL) { success in
        if !success && browser != .safari {
            // Fallback to Safari
            DispatchQueue.main.async {
                self.openInBrowser(url, browser: .safari)
            }
        }
    }
}
```

### Validation

Validate URLs before attempting to open:

```swift
func validateURL(_ url: URL) -> Bool {
    guard let scheme = url.scheme else { return false }
    
    // Only handle HTTP(S) URLs
    guard scheme == "http" || scheme == "https" else { return false }
    
    // Verify host is present
    guard url.host != nil else { return false }
    
    return true
}
```

## Performance Considerations

### Availability Caching

Cache browser availability to avoid repeated checks:

```swift
class BrowserAvailabilityCache {
    private static var cache: [SupportedBrowser: Bool] = [:]
    private static var lastUpdate: Date?
    
    static func isInstalled(_ browser: SupportedBrowser) -> Bool {
        let now = Date()
        
        // Refresh cache every 60 seconds
        if let lastUpdate = lastUpdate, 
           now.timeIntervalSince(lastUpdate) < 60 {
            return cache[browser] ?? false
        }
        
        // Update cache
        let isInstalled = browser.isInstalled
        cache[browser] = isInstalled
        self.lastUpdate = now
        
        return isInstalled
    }
}
```

### Lazy Activity Creation

Create activities only when needed:

```swift
class LazyBrowserActivityProvider {
    private static var activities: [UIActivity]?
    
    static func availableActivities() -> [UIActivity] {
        if let cached = activities {
            return cached
        }
        
        let newActivities = BrowserActivityProvider.availableActivities()
        activities = newActivities
        return newActivities
    }
    
    static func invalidateCache() {
        activities = nil
    }
}
```

## Testing

### Unit Testing

Test browser detection and URL conversion:

```swift
func testBrowserDetection() {
    // Test Safari (always available)
    XCTAssertTrue(SupportedBrowser.safari.isInstalled)
    
    // Test URL conversion
    let originalURL = URL(string: "https://example.com")!
    let chromeURL = originalURL.browserURL(for: .chrome)
    XCTAssertEqual(chromeURL.scheme, "googlechromes")
}

func testActivityCreation() {
    let activities = BrowserActivityProvider.availableActivities()
    
    // Safari should always be present
    XCTAssertTrue(activities.contains { $0 is SafariActivity })
    
    // Test activity capabilities
    let url = URL(string: "https://example.com")!
    activities.forEach { activity in
        if activity.canPerform(withActivityItems: [url]) {
            activity.prepare(withActivityItems: [url])
            // Test that preparation succeeds
        }
    }
}
```

### Integration Testing

Test with actual browser apps:

```swift
func testBrowserIntegration() {
    let url = URL(string: "https://example.com")!
    
    // Test each available browser
    for browser in SupportedBrowser.allCases where browser.isInstalled {
        let browserURL = url.browserURL(for: browser)
        XCTAssertTrue(UIApplication.shared.canOpenURL(browserURL))
    }
}
```

## User Experience

### Visual Design

Ensure consistent visual presentation:
- Use official browser icons
- Maintain consistent sizing
- Support dark/light mode variations
- Provide high-resolution assets

### Accessibility

Support accessibility features:
- Descriptive activity titles
- VoiceOver compatibility
- Dynamic Type support
- High contrast variations

### Localization

Localize browser activity titles:

```swift
override var activityTitle: String? {
    return NSLocalizedString("Open in Chrome", 
                           tableName: "BrowserActivities",
                           comment: "Action title for opening URL in Chrome")
}
```

## Future Enhancements

### Planned Features
- DuckDuckGo browser support
- Opera browser support
- User-configurable browser preferences
- Browser usage analytics

### iOS Integration
- iOS 14+ default browser support
- Shortcuts app integration
- Widget support for quick browser access

## Troubleshooting

### Common Issues

**Browser not detected:**
- Verify URL scheme in Info.plist
- Check browser installation
- Test on actual device

**URLs not opening:**
- Validate URL conversion logic
- Check browser-specific URL formats
- Test with simple URLs first

**Activities not appearing:**
- Verify browser detection logic
- Check activity registration
- Test `canPerform` implementation

### Debugging

Enable detailed logging:

```swift
func debugBrowserSupport() {
    for browser in SupportedBrowser.allCases {
        print("Browser: \(browser.rawValue)")
        print("  Scheme: \(browser.urlScheme)")
        print("  Installed: \(browser.isInstalled)")
        
        let testURL = URL(string: "https://example.com")!
        let browserURL = testURL.browserURL(for: browser)
        print("  Test URL: \(browserURL)")
        print("  Can open: \(UIApplication.shared.canOpenURL(browserURL))")
        print()
    }
}
```

## References

- [LSApplicationQueriesSchemes Documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationqueriesschemes)
- [UIApplication.canOpenURL Reference](https://developer.apple.com/documentation/uikit/uiapplication/1622952-canopenurl)
- [ARChromeActivity Library](https://github.com/alexruperez/ARChromeActivity)
- [Browser URL Scheme Documentation](https://developer.chrome.com/docs/multidevice/ios/links/)