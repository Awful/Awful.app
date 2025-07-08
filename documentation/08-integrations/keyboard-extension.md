# Keyboard Extension

Awful.app includes a custom keyboard extension that provides quick access to forum smilies while typing in any app. The extension shares data with the main app through App Groups.

## Overview

The Smilie Keyboard extension allows users to:
- Insert forum smilies in any text field across iOS
- Browse different smilie categories
- Maintain scroll position and selection state
- Sync with the main app's smilie data

## Architecture

### Extension Structure

The keyboard extension consists of several components:

#### Target Configuration
- **Target Name**: `SmilieKeyboard`
- **Location**: `Smilies Extra/Keyboard/`
- **Bundle ID**: `com.awfulapp.Awful.SmilieKeyboard`
- **Extension Point**: `com.apple.keyboard-service`

#### Core Files
- `KeyboardViewController.h/m` - Main extension view controller
- `NeedsFullAccessView.h/m/xib` - Full access permission UI
- `Info.plist` - Extension configuration
- `Keyboard.entitlements` - App Group entitlements

### Shared Framework Integration

The extension uses the Smilies framework for data access:

```objc
@import Smilies;

// Shared data store access
SmilieDataStore *dataStore = [SmilieDataStore sharedDataStore];
```

## App Groups Configuration

### Setup Requirements

App Groups enable data sharing between the main app and extension:

#### 1. Developer Portal Configuration
- Create App Group: `group.com.awfulapp.SmilieKeyboard`
- Add to both app and extension capabilities

#### 2. Local Entitlements
Create `Local.entitlements` from sample:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.awfulapp.SmilieKeyboard</string>
    </array>
</dict>
</plist>
```

#### 3. Build Configuration
Update `Local.xcconfig`:

```xcconfig
CODE_SIGN_ENTITLEMENTS = ${CODE_SIGN_ENTITLEMENTS_${TARGET_NAME}}
CODE_SIGN_ENTITLEMENTS_Awful = ../Local.entitlements
CODE_SIGN_ENTITLEMENTS_SmilieKeyboard = ../Local.entitlements
DEVELOPMENT_TEAM = YOUR_TEAM_ID_HERE
```

## Data Sharing

### Shared Container

The App Group provides a shared container for data:

```objc
// App Group identifier
static NSString * const AppGroupIdentifier = @"group.com.awfulapp.SmilieKeyboard";

// Shared UserDefaults
static NSUserDefaults * SharedDefaults(void)
{
    return [[NSUserDefaults alloc] initWithSuiteName:AppGroupIdentifier];
}
```

### Shared State Management

Several pieces of state are synchronized:

#### App Activity Status
```objc
static NSString * const AwfulAppIsActiveKey = @"SmilieAwfulAppIsActive";

BOOL SmilieKeyboardIsAwfulAppActive(void) {
    return [SharedDefaults() boolForKey:AwfulAppIsActiveKey];
}

void SmilieKeyboardSetIsAwfulAppActive(BOOL isActive) {
    [SharedDefaults() setBool:isActive forKey:AwfulAppIsActiveKey];
}
```

#### Selected Smilie List
```objc
static NSString * const SelectedSmilieListKey = @"SmilieSelectedSmilieList";

SmilieList SmilieKeyboardSelectedSmilieList(void) {
    return [SharedDefaults() integerForKey:SelectedSmilieListKey];
}

void SmilieKeyboardSetSelectedSmilieList(SmilieList smilieList) {
    [SharedDefaults() setInteger:smilieList forKey:SelectedSmilieListKey];
}
```

#### Scroll Position
```objc
static NSString * ScrollFractionKey(SmilieList smilieList) {
    return [NSString stringWithFormat:@"SmilieScrollFraction%@", @(smilieList)];
}

float SmilieKeyboardScrollFractionForSmilieList(SmilieList smilieList) {
    return [SharedDefaults() floatForKey:ScrollFractionKey(smilieList)];
}
```

## Extension Implementation

### Main View Controller

The `KeyboardViewController` manages the extension interface:

```objc
@interface KeyboardViewController : UIInputViewController
@property (nonatomic) UIView *nextKeyboardButton;
@property (nonatomic) SmilieKeyboardView *smilieKeyboard;
@end
```

### Full Access Requirements

The extension requires full access for shared container access:

```xml
<key>NSExtensionAttributes</key>
<dict>
    <key>RequestsOpenAccess</key>
    <true/>
</dict>
```

### Permission UI

When full access isn't granted, a special view is shown:

```objc
// NeedsFullAccessView displays instructions
// for enabling full access in Settings
```

## Smilie Data Integration

### Data Store Access

The extension accesses the same smilie data as the main app:

```objc
SmilieDataStore *dataStore = [SmilieDataStore sharedDataStore];
NSArray *smilies = [dataStore smiliesForList:currentList];
```

### Smilie Categories

Different smilie lists are available:
- Standard smilies
- Custom/additional smilies
- Recently used smilies

### Image Loading

Smilie images are loaded from shared bundle resources:

```objc
UIImage *smilieImage = [UIImage imageNamed:smilie.imageName 
                                  inBundle:smilieBundle 
             compatibleWithTraitCollection:nil];
```

## User Interface

### Layout Components

The keyboard extension provides:
- Collection view of smilies
- Category selector
- Next keyboard button (system requirement)
- Full access prompt when needed

### Responsive Design

The interface adapts to:
- Different device sizes (iPhone/iPad)
- Portrait/landscape orientations
- Various keyboard heights
- Accessibility settings

### Interaction Patterns

- Tap to insert smilie
- Swipe to change categories
- Long press for smilie details
- Haptic feedback integration

## Integration with Main App

### Data Synchronization

The main app updates shared data when:
- Smilie data is refreshed
- User preferences change
- App becomes active/inactive

### State Persistence

Extension state is preserved across:
- App switching
- Keyboard dismissal/presentation
- Device rotation
- Memory pressure scenarios

## Performance Considerations

### Memory Management

The extension operates under strict memory limits:
- Efficient image caching
- Lazy loading of smilie data
- Proper view controller lifecycle
- Background state handling

### Launch Time

Quick extension startup through:
- Minimal initialization
- Cached data access
- Deferred non-critical operations

### Resource Usage

Optimized for:
- Low CPU usage
- Minimal network requests
- Efficient drawing operations
- Battery conservation

## Debugging and Testing

### Extension Debugging

Debug the extension in Xcode:
1. Set SmilieKeyboard as active scheme
2. Choose host app (Settings, Messages, etc.)
3. Set breakpoints in extension code
4. Test keyboard functionality

### Common Issues

**Extension doesn't appear:**
- Check App Group configuration
- Verify entitlements setup
- Ensure full access is enabled

**Data not syncing:**
- Verify shared container access
- Check UserDefaults suite name
- Test App Group permissions

**Performance problems:**
- Profile memory usage
- Check for main thread blocking
- Optimize image loading

### Testing Scenarios

Test the extension with:
- Different host applications
- Various text input types
- Device orientation changes
- Memory pressure situations
- Network connectivity issues

## Security and Privacy

### Data Access

The extension has access to:
- Shared smilie data only
- No access to typed content (by design)
- No network access (relies on main app)

### Privacy Considerations

- No user input is stored or transmitted
- Smilie selection data is local only
- App Group data is sandboxed

### Permission Model

Full access is required for:
- Shared container access
- App Group communication
- Proper functionality

## Deployment

### Distribution

The extension is distributed with the main app:
- No separate App Store listing
- Installed automatically with main app
- Enabled through iOS Settings

### Updates

Extension updates through:
- Main app updates
- Automatic synchronization
- No user action required

## Future Enhancements

### Planned Features
- Search functionality
- Favorite smilies
- Recent usage tracking
- Custom smilie support

### Technical Improvements
- SwiftUI migration
- Improved accessibility
- Better performance metrics
- Enhanced debugging tools

## Troubleshooting

### User Issues

**Keyboard not available:**
1. Check Settings > General > Keyboard > Keyboards
2. Add "Smilie Keyboard" if missing
3. Enable "Allow Full Access"
4. Restart device if needed

**Smilies not loading:**
1. Open main Awful app
2. Allow smilie data to sync
3. Return to keyboard extension
4. Check network connectivity

### Developer Issues

**Build failures:**
- Verify App Group configuration
- Check entitlements file paths
- Ensure development team is set

**Runtime errors:**
- Check shared container permissions
- Verify bundle identifier matching
- Test App Group functionality

## References

- [App Extension Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/)
- [App Groups Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
- [Custom Keyboard Guide](https://developer.apple.com/documentation/uikit/keyboards_and_input)