# App Groups Integration

Awful.app uses App Groups to enable data sharing between the main application and the Smilie Keyboard extension. This allows synchronized state and preferences across both components.

## Overview

App Groups provide a shared container that allows:
- Data sharing between main app and keyboard extension
- Synchronized user preferences
- Shared state management
- Consistent user experience across components

## App Group Configuration

### Identifier

The app uses a single App Group identifier:
```
group.com.awfulapp.SmilieKeyboard
```

### Capabilities Setup

#### Developer Portal Configuration
1. Create App Group in Apple Developer Portal
2. Add App Group to both app and extension identifiers
3. Generate new provisioning profiles if needed

#### Project Configuration
Both the main app and keyboard extension must have App Groups capability enabled with the same identifier.

### Entitlements

#### Local.entitlements Structure
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

#### Build Configuration
```xcconfig
# Local.xcconfig
CODE_SIGN_ENTITLEMENTS = ${CODE_SIGN_ENTITLEMENTS_${TARGET_NAME}}
CODE_SIGN_ENTITLEMENTS_Awful = ../Local.entitlements
CODE_SIGN_ENTITLEMENTS_SmilieKeyboard = ../Local.entitlements
```

## Shared Data Access

### UserDefaults Suite

The primary mechanism for sharing data is through UserDefaults with a suite name:

```objc
// SmilieAppContainer.m
static NSString * const AppGroupIdentifier = @"group.com.awfulapp.SmilieKeyboard";

static NSUserDefaults * SharedDefaults(void)
{
    return [[NSUserDefaults alloc] initWithSuiteName:AppGroupIdentifier];
}
```

### Container Directory

App Groups also provide a shared file container:

```swift
let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.awfulapp.SmilieKeyboard"
)
```

## Shared State Management

### App Activity Status

Track whether the main app is currently active:

```objc
static NSString * const AwfulAppIsActiveKey = @"SmilieAwfulAppIsActive";

BOOL SmilieKeyboardIsAwfulAppActive(void)
{
    return [SharedDefaults() boolForKey:AwfulAppIsActiveKey];
}

void SmilieKeyboardSetIsAwfulAppActive(BOOL isActive)
{
    [SharedDefaults() setBool:isActive forKey:AwfulAppIsActiveKey];
}
```

### Selected Smilie List

Synchronize the currently selected smilie category:

```objc
static NSString * const SelectedSmilieListKey = @"SmilieSelectedSmilieList";

SmilieList SmilieKeyboardSelectedSmilieList(void)
{
    return [SharedDefaults() integerForKey:SelectedSmilieListKey];
}

void SmilieKeyboardSetSelectedSmilieList(SmilieList smilieList)
{
    [SharedDefaults() setInteger:smilieList forKey:SelectedSmilieListKey];
}
```

### Scroll Position Preservation

Maintain scroll positions across app launches:

```objc
static NSString * ScrollFractionKey(SmilieList smilieList)
{
    return [NSString stringWithFormat:@"SmilieScrollFraction%@", @(smilieList)];
}

float SmilieKeyboardScrollFractionForSmilieList(SmilieList smilieList)
{
    return [SharedDefaults() floatForKey:ScrollFractionKey(smilieList)];
}

void SmilieKeyboardSetScrollFractionForSmilieList(SmilieList smilieList, float scrollFraction)
{
    [SharedDefaults() setFloat:scrollFraction forKey:ScrollFractionKey(smilieList)];
}
```

## Data Synchronization

### Main App Responsibilities

The main app manages:
- Setting app activity status
- Updating shared preferences
- Maintaining smilie data currency
- Cleanup of expired shared data

```swift
// In AppDelegate or SceneDelegate
func applicationDidBecomeActive(_ application: UIApplication) {
    SmilieKeyboardSetIsAwfulAppActive(true)
    // Update other shared state as needed
}

func applicationWillResignActive(_ application: UIApplication) {
    SmilieKeyboardSetIsAwfulAppActive(false)
}
```

### Extension Responsibilities

The keyboard extension:
- Reads shared state
- Updates position and selection data
- Respects main app activity status
- Handles graceful degradation

```objc
// In KeyboardViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Check if main app is active
    BOOL appIsActive = SmilieKeyboardIsAwfulAppActive();
    
    // Restore previous state
    SmilieList selectedList = SmilieKeyboardSelectedSmilieList();
    float scrollFraction = SmilieKeyboardScrollFractionForSmilieList(selectedList);
    
    // Configure UI accordingly
}
```

## Shared Data Types

### Primitive Types

UserDefaults supports standard types directly:
- `BOOL` for flags and status
- `NSInteger` for enumerations and counts
- `float`/`double` for positions and measurements
- `NSString` for identifiers and text

### Complex Types

For complex data, use property lists or archiving:

```swift
// Store dictionary
let sharedDefaults = UserDefaults(suiteName: "group.com.awfulapp.SmilieKeyboard")
sharedDefaults?.set(complexData, forKey: "ComplexDataKey")

// Retrieve dictionary
let retrievedData = sharedDefaults?.dictionary(forKey: "ComplexDataKey")
```

### Core Data Considerations

If using Core Data with App Groups:
- Store database in shared container
- Coordinate access between app and extension
- Handle concurrent access properly
- Consider performance implications

## File Sharing

### Shared Container Access

Access the shared file container:

```swift
guard let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.awfulapp.SmilieKeyboard"
) else {
    fatalError("App Group container not available")
}

let sharedDocumentsURL = containerURL.appendingPathComponent("Documents")
```

### File Coordination

Use NSFileCoordinator for safe file access:

```swift
let coordinator = NSFileCoordinator()
var error: NSError?

coordinator.coordinate(writingItemAt: fileURL, options: [], error: &error) { (url) in
    // Perform file operations
}
```

## Security Considerations

### Sandbox Isolation

App Groups maintain security boundaries:
- Only apps in the same group can access shared data
- Data is isolated from other apps
- Standard iOS sandboxing still applies

### Data Validation

Validate shared data to prevent corruption:

```objc
SmilieList SmilieKeyboardSelectedSmilieList(void)
{
    NSInteger rawValue = [SharedDefaults() integerForKey:SelectedSmilieListKey];
    
    // Validate enum value
    if (rawValue < 0 || rawValue >= SmilieListCount) {
        return SmilieListStandard; // Default fallback
    }
    
    return (SmilieList)rawValue;
}
```

### Privacy Implications

Consider privacy when sharing data:
- Don't share sensitive user information
- Use identifiers rather than personal data
- Implement data retention policies
- Respect user privacy preferences

## Performance Considerations

### Read Performance

UserDefaults reads are generally fast:
- Values are cached in memory
- Suitable for frequent access
- Minimal overhead for primitive types

### Write Performance

Optimize write operations:
- Batch related updates
- Avoid excessive write frequency
- Consider background queues for heavy operations

### Memory Usage

Manage memory efficiently:
- Don't store large objects in UserDefaults
- Use file container for binary data
- Clean up unused shared data

## Debugging App Groups

### Verification Steps

1. **Check Entitlements**: Verify both targets have correct App Group
2. **Test Container Access**: Ensure shared container is accessible
3. **Validate Identifiers**: Confirm App Group identifier matches across targets
4. **Check Provisioning**: Verify provisioning profiles include App Group

### Common Issues

**Shared container not accessible:**
- Verify App Group configuration in Developer Portal
- Check entitlements file inclusion in build
- Ensure provisioning profiles are up to date

**Data not syncing:**
- Confirm both targets use same App Group identifier
- Check UserDefaults suite name spelling
- Verify write operations complete successfully

**Extension not loading:**
- Check extension entitlements
- Verify App Group permissions
- Test with simple shared data first

### Development Tools

Use Xcode and system tools for debugging:
- Xcode Console for logging
- Device logs for extension issues
- Simulator for basic testing
- Instruments for performance analysis

## Testing

### Unit Testing

Test shared data access:

```swift
func testSharedUserDefaults() {
    let sharedDefaults = UserDefaults(suiteName: "group.com.awfulapp.SmilieKeyboard")
    
    // Test write
    sharedDefaults?.set(true, forKey: "TestKey")
    
    // Test read
    let value = sharedDefaults?.bool(forKey: "TestKey")
    XCTAssertTrue(value == true)
    
    // Cleanup
    sharedDefaults?.removeObject(forKey: "TestKey")
}
```

### Integration Testing

Test app-extension communication:
1. Launch main app
2. Set shared state
3. Switch to keyboard extension
4. Verify state is accessible
5. Update state in extension
6. Return to main app and verify changes

### Device Testing

App Groups require device testing:
- Cannot be fully tested in Simulator
- Requires proper provisioning
- Test with actual extension host apps

## Migration Strategies

### Adding App Groups

When adding App Groups to existing app:
1. Migrate existing data to shared container
2. Update code to use shared UserDefaults
3. Maintain backward compatibility during transition
4. Provide fallbacks for missing shared data

### Changing Identifiers

If App Group identifier changes:
1. Migrate data from old to new container
2. Update all targets simultaneously
3. Handle cases where migration fails
4. Provide user notification if needed

## Future Considerations

### iOS Updates

Monitor iOS changes affecting App Groups:
- New security requirements
- Performance improvements
- API changes
- Migration requirements

### Feature Expansion

Consider future shared data needs:
- Additional extension types
- More complex data structures
- Enhanced synchronization
- Background processing

## References

- [App Groups Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
- [UserDefaults Suite Names](https://developer.apple.com/documentation/foundation/userdefaults/1416603-init)
- [App Extension Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/)
- [File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/)