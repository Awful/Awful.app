# Share Extension and Activity Integration

Awful.app integrates with iOS's share system through custom UIActivity classes and UIActivityViewController usage. This enables users to share content from the app and open links in their preferred browsers.

## Overview

The app provides custom sharing activities for:
- Opening URLs in Safari
- Opening URLs in Chrome
- Copying URLs to clipboard
- Copying images to clipboard
- Standard iOS sharing activities

## Architecture

### Custom Activity Classes

The app includes several custom UIActivity implementations:

#### SafariActivity
- **Location**: `App/Misc/SafariActivity.swift`
- **Purpose**: Opens URLs in Safari
- **Icon**: Custom Safari icon from bundle

#### ChromeActivity
- **Location**: `App/Misc/ChromeActivity.swift`
- **Purpose**: Opens URLs in Google Chrome
- **Dependency**: ARChromeActivity vendor component

#### Copy Activities
- **CopyURLActivity**: Copies URLs to pasteboard
- **CopyImageActivity**: Copies images to pasteboard

### Activity Bundles

Custom activities use resource bundles for icons and localization:

#### TUSafariActivity Bundle
- **Location**: `Vendor/TUSafariActivity/TUSafariActivity.bundle/`
- **Contents**: Safari icons for different device types and scales
- **Localization**: Localizable.strings for activity titles

#### ARChromeActivity Bundle
- **Location**: `Vendor/ARChromeActivity/ARChromeActivity.xcassets/`
- **Contents**: Chrome activity icons and metadata

## Activity Implementation

### SafariActivity Implementation

```swift
final class SafariActivity: UIActivity {
    private var url: URL?

    override var activityType: UIActivity.ActivityType? {
        .init("SafariActivity")
    }

    override var activityTitle: String? {
        NSLocalizedString("Open in Safari", 
                         tableName: "TUSafariActivity", 
                         bundle: bundle, 
                         value: "Open in Safari", 
                         comment: "")
    }

    override var activityImage: UIImage? {
        UIImage(named: "safari", in: bundle, compatibleWith: nil)
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return activityItems.lazy
            .compactMap { $0 as? URL }
            .contains { UIApplication.shared.canOpenURL($0) }
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        url = activityItems.lazy.compactMap { $0 as? URL }.first
    }

    override func perform() {
        if let url = url {
            UIApplication.shared.open(url)
        }
    }
}
```

### Chrome Integration

Chrome integration checks for app availability:

```swift
// Check if Chrome is installed
let chromeURL = URL(string: "googlechrome://")!
if UIApplication.shared.canOpenURL(chromeURL) {
    // Convert HTTP(S) URLs to Chrome scheme
    let chromeSchemeURL = url.chromeSchemeURL
    UIApplication.shared.open(chromeSchemeURL)
}
```

### Copy Activities

Simple activities for copying content:

```swift
class CopyURLActivity: UIActivity {
    override func perform() {
        if let url = activityItems?.first as? URL {
            UIPasteboard.general.url = url
        }
        activityDidFinish(true)
    }
}
```

## Integration Points

### Posts View Controller

The posts view controller provides rich sharing options:

```swift
class PostsPageViewController: UIViewController {
    
    func presentShareSheet(for url: URL, from view: UIView) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: [
                SafariActivity(),
                ChromeActivity(),
                CopyURLActivity()
            ]
        )
        
        // iPad popover configuration
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(activityVC, animated: true)
    }
}
```

### Profile View Controller

Profile sharing includes user information:

```swift
func shareProfile() {
    let profileURL = user.profileURL
    let shareText = "Check out \(user.username)'s profile"
    
    let activityVC = UIActivityViewController(
        activityItems: [shareText, profileURL],
        applicationActivities: customActivities
    )
    
    present(activityVC, animated: true)
}
```

### Image View Controller

Image sharing supports both URLs and image data:

```swift
func shareImage() {
    var activityItems: [Any] = []
    
    if let image = currentImage {
        activityItems.append(image)
    }
    
    if let imageURL = imageURL {
        activityItems.append(imageURL)
    }
    
    let activityVC = UIActivityViewController(
        activityItems: activityItems,
        applicationActivities: [
            SafariActivity(),
            CopyImageActivity()
        ]
    )
    
    present(activityVC, animated: true)
}
```

## URL Menu Presenter

### Contextual Sharing

The `URLMenuPresenter` provides contextual sharing for links:

```swift
class URLMenuPresenter {
    
    func presentMenu(for url: URL, from view: UIView) {
        let activities = [
            SafariActivity(),
            ChromeActivity(),
            CopyURLActivity()
        ]
        
        // Create action sheet for iPhone
        if UIDevice.current.userInterfaceIdiom == .phone {
            presentActionSheet(for: url, activities: activities, from: view)
        } else {
            // Use activity view controller for iPad
            presentActivityViewController(for: url, activities: activities, from: view)
        }
    }
}
```

### Long Press Handling

Long press gestures trigger contextual menus:

```swift
@objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began else { return }
    
    let point = gesture.location(in: webView)
    
    webView.evaluateJavaScript("document.elementFromPoint(\(point.x), \(point.y)).href") { result, error in
        guard let urlString = result as? String,
              let url = URL(string: urlString) else { return }
        
        self.urlMenuPresenter.presentMenu(for: url, from: self.view)
    }
}
```

## Browser Detection

### Available Browsers

The app detects available browsers through URL scheme queries:

```swift
enum BrowserApp: CaseIterable {
    case safari
    case chrome
    case firefox
    case edge
    case brave
    
    var urlScheme: String {
        switch self {
        case .safari: return "http"
        case .chrome: return "googlechrome"
        case .firefox: return "firefox"
        case .edge: return "microsoft-edge-http"
        case .brave: return "brave"
        }
    }
    
    var isAvailable: Bool {
        let url = URL(string: "\(urlScheme)://")!
        return UIApplication.shared.canOpenURL(url)
    }
}
```

### Dynamic Activity Lists

Activity lists adapt to available browsers:

```swift
func availableActivities() -> [UIActivity] {
    var activities: [UIActivity] = []
    
    activities.append(SafariActivity())
    
    if BrowserApp.chrome.isAvailable {
        activities.append(ChromeActivity())
    }
    
    if BrowserApp.firefox.isAvailable {
        activities.append(FirefoxActivity())
    }
    
    activities.append(CopyURLActivity())
    
    return activities
}
```

## Customization

### Activity Ordering

Control activity presentation order:

```swift
let activityVC = UIActivityViewController(
    activityItems: [url],
    applicationActivities: customActivities
)

// Exclude unwanted system activities
activityVC.excludedActivityTypes = [
    .addToReadingList,
    .assignToContact,
    .saveToCameraRoll
]
```

### Custom Icons

Provide high-quality icons for all screen densities:
- 1x: 43x43 points
- 2x: 86x86 points
- 3x: 129x129 points

### Localization

Support multiple languages in activity bundles:

```
TUSafariActivity.bundle/
├── en.lproj/
│   └── Localizable.strings
├── es.lproj/
│   └── Localizable.strings
└── fr.lproj/
    └── Localizable.strings
```

## Error Handling

### URL Validation

Validate URLs before sharing:

```swift
override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
    guard let url = activityItems.compactMap({ $0 as? URL }).first else {
        return false
    }
    
    // Check URL validity
    guard url.scheme == "http" || url.scheme == "https" else {
        return false
    }
    
    // Check if target app can open URL
    return UIApplication.shared.canOpenURL(url)
}
```

### Graceful Failures

Handle failures gracefully:

```swift
override func perform() {
    guard let url = self.url else {
        activityDidFinish(false)
        return
    }
    
    UIApplication.shared.open(url) { success in
        DispatchQueue.main.async {
            self.activityDidFinish(success)
        }
    }
}
```

## Testing

### Activity Testing

Test custom activities in isolation:

```swift
func testSafariActivityCanPerform() {
    let activity = SafariActivity()
    let url = URL(string: "https://example.com")!
    
    let canPerform = activity.canPerform(withActivityItems: [url])
    XCTAssertTrue(canPerform)
}

func testChromeActivityWithoutChrome() {
    // Mock Chrome as unavailable
    let activity = ChromeActivity()
    let url = URL(string: "https://example.com")!
    
    // Should fallback gracefully
    let canPerform = activity.canPerform(withActivityItems: [url])
    // Test appropriate behavior
}
```

### Integration Testing

Test complete sharing flows:

```swift
func testShareSheetPresentation() {
    let viewController = PostsPageViewController()
    let url = URL(string: "https://example.com")!
    
    // Present share sheet
    viewController.presentShareSheet(for: url, from: viewController.view)
    
    // Verify activity view controller is presented
    XCTAssertTrue(viewController.presentedViewController is UIActivityViewController)
}
```

## Performance Considerations

### Icon Loading

Optimize icon loading:
- Use appropriate image formats
- Cache loaded icons
- Provide all required scales
- Use vector formats when possible

### Activity Creation

Create activities efficiently:
- Reuse activity instances when possible
- Lazy load expensive resources
- Minimize initialization overhead

## Accessibility

### VoiceOver Support

Ensure activities work with VoiceOver:
- Provide descriptive activity titles
- Use clear, concise language
- Test with VoiceOver enabled

### Dynamic Type

Support Dynamic Type in custom activities:
- Use system fonts when possible
- Test with larger text sizes
- Ensure icon visibility

## Future Enhancements

### Planned Features
- Additional browser support
- Custom share extensions
- Enhanced image sharing
- Social media integration

### iOS Feature Adoption
- iOS 15+ SharePlay support
- Shortcuts integration
- Siri suggestions
- App Clips sharing

## Troubleshooting

### Common Issues

**Activities not appearing:**
- Check activity registration
- Verify `canPerform` implementation
- Test with valid activity items

**Browser apps not opening:**
- Verify URL scheme queries in Info.plist
- Test with actual device (not simulator)
- Check URL format conversion

**Icons not displaying:**
- Check bundle resource inclusion
- Verify image naming conventions
- Test on different screen densities

### Debugging Tips

1. Log activity item types and values
2. Test `canPerform` with various inputs
3. Verify URL scheme availability
4. Check bundle resource loading
5. Test on multiple devices and iOS versions

## References

- [UIActivity Class Reference](https://developer.apple.com/documentation/uikit/uiactivity)
- [UIActivityViewController Guide](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller)
- [Custom Activity Implementation Guide](https://developer.apple.com/documentation/uikit/uiactivity/1622018-activitytype)