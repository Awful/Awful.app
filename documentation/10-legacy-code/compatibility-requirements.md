# Compatibility Requirements

## Overview

This document defines compatibility requirements and constraints for Awful.app legacy code modernization, ensuring that critical functionality is preserved and user experience remains consistent during the transition to modern Swift and iOS patterns.

## Critical Compatibility Areas

### Data Persistence Compatibility

#### Core Data Schema Stability
- **Requirement**: Maintain backward compatibility with existing databases
- **Scope**: All Core Data entities and relationships
- **Impact**: User data must remain accessible across updates
- **Risk Level**: Critical (data loss unacceptable)

**Protected Entities:**
```swift
// Core Data entities that MUST remain compatible
@objc(Forum)
class Forum: NSManagedObject {
    @NSManaged var forumID: String
    @NSManaged var name: String
    @NSManaged var threads: Set<Thread>
    // Schema changes require careful migration
}

@objc(Thread)
class Thread: NSManagedObject {
    @NSManaged var threadID: String
    @NSManaged var title: String
    @NSManaged var posts: Set<Post>
    // Existing relationships must be preserved
}

@objc(Post)
class Post: NSManagedObject {
    @NSManaged var postID: String
    @NSManaged var content: String
    @NSManaged var author: User
    // Content format must remain compatible
}
```

#### Database Migration Strategy
```swift
// Safe migration patterns
class CoreDataMigrationManager {
    static func performMigration(from sourceModel: NSManagedObjectModel, 
                                to targetModel: NSManagedObjectModel) throws {
        let mapping = try NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: targetModel
        )
        
        let migrationManager = NSMigrationManager(
            sourceModel: sourceModel,
            destinationModel: targetModel
        )
        
        try migrationManager.migrateStore(
            from: sourceURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mapping,
            toDestinationURL: destinationURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )
    }
}
```

### User Settings Compatibility

#### Settings Keys Preservation
- **Requirement**: All existing user preferences must be preserved
- **Scope**: UserDefaults keys, App Group settings
- **Impact**: User customizations maintained across updates
- **Risk Level**: High (user experience disruption)

**Protected Settings:**
```swift
// Settings that MUST maintain compatibility
enum LegacySettingsKeys {
    static let username = "AwfulUsername"
    static let selectedTheme = "AwfulTheme"
    static let fontSize = "AwfulFontSize"
    static let enableDarkMode = "AwfulDarkMode"
    static let smilieKeyboardEnabled = "AwfulSmilieKeyboard"
    // These keys must never change
}

// Migration helper for safe settings updates
class SettingsMigrationHelper {
    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        
        // Migrate old boolean to new enum if needed
        if let oldValue = defaults.object(forKey: "OldKey") as? Bool {
            let newValue = oldValue ? "enabled" : "disabled"
            defaults.set(newValue, forKey: "NewKey")
            defaults.removeObject(forKey: "OldKey")
        }
    }
}
```

#### Theme System Compatibility
- **Requirement**: Existing themes must continue to work
- **Scope**: Theme files, CSS overrides, forum-specific themes
- **Impact**: Visual consistency maintained
- **Risk Level**: Medium (visual changes acceptable with notice)

### Authentication Compatibility

#### Cookie-Based Authentication
- **Requirement**: Maintain Something Awful cookie authentication
- **Scope**: Login system, session management
- **Impact**: Users don't need to re-authenticate
- **Risk Level**: Critical (breaks core functionality)

```swift
// Authentication compatibility layer
class AuthenticationManager {
    // MUST preserve existing cookie format
    private let cookieStorageKey = "AwfulAuthCookies"
    
    func preserveLegacyCookies() {
        // Migrate existing cookies to new format if needed
        guard let legacyCookies = loadLegacyCookies() else { return }
        
        for cookie in legacyCookies {
            // Validate cookie is still valid
            if isCookieValid(cookie) {
                // Preserve in new format
                storeInNewFormat(cookie)
            }
        }
    }
    
    // MUST maintain exact cookie behavior
    func authenticateWithCookies(_ cookies: [HTTPCookie]) {
        // Preserve existing authentication flow
    }
}
```

#### Session Management
```swift
// Session management that preserves behavior
class SessionManager {
    // MUST maintain session lifecycle
    func validateSession() async throws -> Bool {
        // Preserve existing session validation logic
        return try await legacySessionValidation()
    }
    
    func refreshSession() async throws {
        // Maintain compatibility with SA refresh mechanism
    }
}
```

### Network Layer Compatibility

#### API Endpoint Compatibility
- **Requirement**: Maintain exact HTTP requests to Something Awful
- **Scope**: All forum scraping, posting, authentication
- **Impact**: Forum functionality continues to work
- **Risk Level**: Critical (breaks core functionality)

```swift
// Network requests that MUST remain unchanged
class ForumsNetworkLayer {
    // MUST preserve exact request format
    func authenticateUser(username: String, password: String) async throws {
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        
        // MUST maintain exact form data format
        let formData = "action=login&username=\(username)&password=\(password)"
        request.httpBody = formData.data(using: .utf8)
        
        // MUST preserve exact headers
        request.setValue("application/x-www-form-urlencoded", 
                        forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        // MUST handle response exactly as before
    }
    
    // MUST preserve HTML scraping compatibility
    func parseThreadList(html: String) throws -> [Thread] {
        // HTML parsing logic must extract same data
        return try legacyHTMLParser.parseThreads(html)
    }
}
```

#### User-Agent Requirements
- **Requirement**: Maintain specific User-Agent string
- **Scope**: All HTTP requests
- **Impact**: Server compatibility
- **Risk Level**: Medium (server may block different agents)

```swift
// User-Agent that MUST be preserved
class UserAgentManager {
    static let requiredUserAgent = "Awful 7.x (iOS; rv:12345)"
    
    // MUST maintain exact format
    static func configureSession(_ session: URLSession) {
        session.configuration.httpAdditionalHeaders = [
            "User-Agent": requiredUserAgent
        ]
    }
}
```

### URL Scheme Compatibility

#### Deep Link Compatibility
- **Requirement**: Existing URL schemes must continue to work
- **Scope**: awful://, custom sharing URLs
- **Impact**: External integrations continue to work
- **Risk Level**: Medium (breaks integrations)

```swift
// URL schemes that MUST be preserved
enum CompatibleURLSchemes {
    case thread(id: String)
    case forum(id: String)
    case user(id: String)
    case post(id: String)
    
    // MUST maintain exact URL format
    var url: URL {
        switch self {
        case .thread(let id):
            return URL(string: "awful://thread/\(id)")!
        case .forum(let id):
            return URL(string: "awful://forum/\(id)")!
        case .user(let id):
            return URL(string: "awful://user/\(id)")!
        case .post(let id):
            return URL(string: "awful://post/\(id)")!
        }
    }
    
    // MUST handle exactly as before
    static func handle(_ url: URL) -> Bool {
        return LegacyURLHandler.handle(url)
    }
}
```

## iOS Version Compatibility

### Minimum iOS Version Support

#### Current Requirements
- **iOS 15.0**: Current minimum supported version
- **Transition Plan**: Gradual adoption of newer APIs
- **Timeline**: Maintain iOS 15 support through 2024
- **Future**: Move to iOS 16.1+ in 2025

#### API Usage Guidelines
```swift
// Safe API usage patterns
extension UIView {
    func safelyApplyModernAPI() {
        if #available(iOS 16.0, *) {
            // Use modern API
            self.backgroundColor = .systemBackground
        } else {
            // Fallback to compatible API
            self.backgroundColor = .systemBackground
        }
    }
}

// Feature availability checks
class FeatureAvailability {
    static var supportsContextMenus: Bool {
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13
    }
    
    static var supportsAsyncImage: Bool {
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15
    }
}
```

### Hardware Compatibility

#### Device Support
- **iPhone**: iPhone 8 and later
- **iPad**: iPad (6th generation) and later
- **Memory**: Minimum 3GB RAM
- **Storage**: Function with limited storage

```swift
// Device capability detection
class DeviceCapabilities {
    static var isLowMemoryDevice: Bool {
        return ProcessInfo.processInfo.physicalMemory < 3_000_000_000
    }
    
    static var supportsMetalPerformanceShaders: Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
    
    // Adjust behavior based on capabilities
    static func configureForDevice() {
        if isLowMemoryDevice {
            // Reduce memory usage
            ImageCache.shared.memoryCapacity = 50_000_000
        }
    }
}
```

## App Store Compatibility

### Review Guidelines Compliance

#### Privacy Requirements
- **Privacy Manifest**: PrivacyInfo.xcprivacy compliance
- **Data Collection**: Transparent data usage
- **Permissions**: Minimal permission requests
- **Third-party SDKs**: Approved SDK usage only

```xml
<!-- Required privacy manifest -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <!-- Minimal data collection -->
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <!-- Required API usage declarations -->
    </array>
</dict>
</plist>
```

#### API Usage Compliance
- **Deprecated APIs**: Must remove UIWebView
- **Background Processing**: Follow background app refresh guidelines
- **Network Usage**: Efficient network usage patterns
- **Storage**: Appropriate data storage locations

### App Extension Compatibility

#### Keyboard Extension Requirements
- **Functionality**: Smilie keyboard must work across iOS versions
- **App Group**: Shared data between app and extension
- **Memory Limits**: Stay within extension memory limits
- **Network Access**: Handle network restrictions properly

```swift
// Extension compatibility layer
class KeyboardExtensionManager {
    // MUST maintain app group communication
    static let appGroupIdentifier = "group.com.awful.app"
    
    static func shareDataWithMainApp<T: Codable>(_ data: T, key: String) {
        guard let sharedContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return }
        
        let fileURL = sharedContainer.appendingPathComponent("\(key).json")
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            try jsonData.write(to: fileURL)
        } catch {
            // Handle error appropriately
        }
    }
}
```

## Testing Compatibility Requirements

### Automated Testing

#### Backward Compatibility Tests
```swift
// Tests that MUST pass for compatibility
class CompatibilityTests: XCTestCase {
    func testSettingsMigration() {
        // Test old settings still work
        let oldDefaults = ["AwfulUsername": "testuser"]
        UserDefaults.standard.setValuesForKeys(oldDefaults)
        
        SettingsManager.migrateIfNeeded()
        
        XCTAssertEqual(SettingsManager.username, "testuser")
    }
    
    func testURLSchemeCompatibility() {
        // Test old URL schemes still work
        let url = URL(string: "awful://thread/12345")!
        XCTAssertTrue(URLRouter.canHandle(url))
        
        let route = URLRouter.route(for: url)
        XCTAssertEqual(route, .thread(id: "12345"))
    }
    
    func testDataModelCompatibility() throws {
        // Test Core Data model can read old data
        let legacyStore = try loadLegacyDataStore()
        let context = legacyStore.newBackgroundContext()
        
        let request = NSFetchRequest<Thread>(entityName: "Thread")
        let threads = try context.fetch(request)
        
        XCTAssertTrue(threads.count > 0)
        XCTAssertNotNil(threads.first?.threadID)
    }
}
```

#### Regression Testing
```swift
// Regression tests for critical functionality
class RegressionTests: XCTestCase {
    func testAuthenticationFlow() async throws {
        // MUST maintain exact authentication behavior
        let authenticated = try await AuthenticationManager.shared.authenticate(
            username: "testuser",
            password: "testpass"
        )
        XCTAssertTrue(authenticated)
    }
    
    func testPostSubmission() async throws {
        // MUST maintain posting functionality
        let success = try await ForumsClient.shared.submitPost(
            content: "Test post",
            threadID: "12345"
        )
        XCTAssertTrue(success)
    }
}
```

### Manual Testing Checklist

#### Critical User Flows
- [ ] User can log in with existing credentials
- [ ] Existing bookmarks and settings are preserved
- [ ] Forum navigation works identically
- [ ] Post reading and writing functions normally
- [ ] Smilie keyboard works in all contexts
- [ ] Theme switching preserves visual consistency
- [ ] Deep links from external apps work
- [ ] Share sheet integration functions normally

#### Edge Cases
- [ ] Works with very old user data
- [ ] Handles network connectivity issues
- [ ] Functions on minimum supported iOS version
- [ ] Works on minimum supported hardware
- [ ] Handles low memory conditions gracefully
- [ ] Functions with restricted network access

## Documentation Requirements

### Compatibility Documentation

#### API Compatibility Guide
```swift
// Document breaking changes and migration paths
/**
 * API Compatibility Notes
 * 
 * BREAKING CHANGES in v8.0:
 * - ForumsClient.shared is now async
 * - Old: ForumsClient.shared.loadThreads(completion:)
 * - New: try await ForumsClient.shared.loadThreads()
 * 
 * DEPRECATED in v8.0:
 * - MessageViewController (Objective-C)
 * - Use: MessageView (SwiftUI) or ModernMessageViewController (Swift)
 * 
 * BACKWARD COMPATIBLE:
 * - All URL schemes
 * - Core Data model
 * - User settings keys
 * - Authentication cookies
 */
```

#### Migration Guide
```markdown
# Migration Guide for Awful.app v8.0

## Data Migration
- All user data automatically migrated
- Settings preserved with same keys
- Themes maintain visual consistency

## API Changes
- Network operations now use async/await
- Core Data operations moved to background contexts
- Error handling uses Swift Result type

## Developer Notes
- Objective-C bridge headers still available
- Legacy API compatibility layer provided
- Gradual migration path documented
```

### User Communication

#### Release Notes Template
```markdown
# What's New in Awful v8.0

## Improvements
- Faster, more responsive interface
- Better memory usage and battery life
- Modern iOS feature support

## Technical Updates
- Modernized codebase for better performance
- Enhanced security and privacy
- Improved accessibility support

## Compatibility
- All your settings and data are preserved
- Works on iOS 15.0 and later
- Existing bookmarks and themes maintained
```

## Rollback Strategy

### Version Rollback Capability

#### Data Compatibility
```swift
// Ensure data can be downgraded if needed
class DataRollbackManager {
    static func prepareForRollback() {
        // Create backup of current data state
        let backup = DataBackupManager.createBackup()
        backup.tag = "pre-v8.0-migration"
        backup.save()
    }
    
    static func rollbackToVersion(_ version: String) throws {
        guard let backup = DataBackupManager.findBackup(tag: "pre-\(version)-migration") else {
            throw RollbackError.backupNotFound
        }
        
        try backup.restore()
    }
}
```

#### Feature Flags
```swift
// Feature flags for gradual rollout
class FeatureFlags {
    static var useModernMessageView: Bool {
        return RemoteConfig.shared.boolValue(for: "modern_message_view")
    }
    
    static var useSwiftUISettingsView: Bool {
        return RemoteConfig.shared.boolValue(for: "swiftui_settings")
    }
    
    // Allow fallback to legacy implementation
    static func fallbackToLegacy(feature: String) {
        RemoteConfig.shared.setValue(false, for: feature)
    }
}
```

## Monitoring and Validation

### Compatibility Metrics

#### Key Performance Indicators
- **Data Migration Success Rate**: Target 99.9%
- **Settings Preservation Rate**: Target 100%
- **Authentication Success Rate**: Target 99.5%
- **Deep Link Success Rate**: Target 95%
- **Crash Rate**: Must not exceed previous version

#### Monitoring Implementation
```swift
// Monitor compatibility issues
class CompatibilityMonitor {
    static func trackMigrationSuccess(component: String, success: Bool) {
        Analytics.track("migration_result", properties: [
            "component": component,
            "success": success,
            "app_version": Bundle.main.appVersion,
            "ios_version": UIDevice.current.systemVersion
        ])
    }
    
    static func reportCompatibilityIssue(issue: String, context: [String: Any]) {
        CrashReporter.recordError(CompatibilityError(
            description: issue,
            context: context
        ))
    }
}
```

### User Feedback Collection

#### Compatibility Issue Reporting
```swift
// Built-in feedback for compatibility issues
class CompatibilityFeedback {
    static func showFeedbackPrompt(issue: String) {
        let alert = UIAlertController(
            title: "Compatibility Issue",
            message: "We detected a potential issue: \(issue). Please let us know if you experience problems.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Report Issue", style: .default) { _ in
            self.openFeedbackForm(issue: issue)
        })
        
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        
        UIApplication.shared.topViewController?.present(alert, animated: true)
    }
}
```

## Success Criteria

### Compatibility Success Metrics

#### Technical Metrics
- [ ] 100% of existing user data successfully migrated
- [ ] 100% of user settings preserved
- [ ] 99.9% authentication success rate maintained
- [ ] All URL schemes continue to work
- [ ] No increase in crash rate
- [ ] Performance maintained or improved

#### User Experience Metrics
- [ ] No user complaints about lost data
- [ ] Minimal support requests for compatibility issues
- [ ] App Store rating maintained or improved
- [ ] User retention rate maintained
- [ ] Feature usage patterns unchanged

#### Process Metrics
- [ ] All compatibility tests passing
- [ ] Code review approval for breaking changes
- [ ] Documentation complete and accurate
- [ ] Rollback procedures tested and ready
- [ ] Monitoring systems operational

## Conclusion

Maintaining compatibility during Awful.app's modernization is critical for user trust and app stability. By carefully preserving data formats, API behaviors, and user experiences while incrementally introducing modern patterns, we can successfully evolve the codebase without disrupting the user base.

The key is comprehensive testing, careful planning, and having robust rollback mechanisms in place. With proper attention to compatibility requirements, the modernization effort will improve the app while maintaining the reliability users expect.