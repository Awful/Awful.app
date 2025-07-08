# Authentication System

## Overview

Awful.app uses a cookie-based authentication system with Something Awful Forums. The presence of the authentication cookie determines whether the user is logged in. This system is **critical** and must be preserved exactly during any migration.

## Architecture

```
LoginViewController → ForumsClient.logIn() → Network Request
                                              ↓
                                         Cookie Storage
                                              ↓
                                      Authentication State
```

## Login Process

### LoginViewController Implementation

**Location**: `App/View Controllers/LoginViewController.swift`

**State Machine**:
```swift
enum State {
    case awaitingUsername
    case awaitingPassword  
    case canAttemptLogin
    case attemptingLogin
    case failedLogin
}
```

**Login Flow**:
1. User enters username and password
2. UI validates form completion
3. Calls `ForumsClient.shared.logIn(username:password:)`
4. Shows loading indicator during authentication
5. Handles success/failure responses

**Critical Implementation Details**:
```swift
// Key method in LoginViewController
private func attemptLogin() {
    state = .attemptingLogin
    
    Task {
        do {
            try await ForumsClient.shared.logIn(
                username: usernameTextField.text!,
                password: passwordTextField.text!
            )
            // Success handling...
        } catch {
            // Error handling...
        }
    }
}
```

### ForumsClient Authentication

**Location**: `AwfulCore/Sources/AwfulCore/Networking/ForumsClient.swift:104-229`

**Login Method**:
```swift
func logIn(username: String, password: String) async throws {
    let request = URLRequest(
        url: baseURL.appendingPathComponent("account.php"),
        cachePolicy: .reloadIgnoringLocalCacheData
    )
    
    // POST request with form data
    // Handles response and extracts user information
    // Updates Settings with user data
}
```

**Authentication Endpoint**: `https://forums.somethingawful.com/account.php?json=1`

## Cookie Management

### Cookie Storage

**System**: Uses `HTTPCookieStorage.shared` (system cookie storage)
**Primary Cookie**: `bbuserid` - identifies authenticated user
**No Keychain**: Authentication cookies are NOT stored in Keychain

**Cookie Access Pattern**:
```swift
private var loginCookie: HTTPCookie? {
    baseURL
        .flatMap { urlSession?.configuration.httpCookieStorage?.cookies(for: $0) }?
        .first { $0.name == "bbuserid" }
}
```

### Authentication State

**Primary Check**:
```swift
var isLoggedIn: Bool {
    return loginCookie != nil
}
```

**Cookie Expiry Tracking**:
```swift
var loginCookieExpiryDate: Date? {
    return loginCookie?.expiresDate
}
```

## Session Management

### User Information Storage

**Location**: `AwfulSettings/Sources/AwfulSettings/Settings.swift`

**Stored in UserDefaults** (not Keychain):
- `Settings.userID`: Logged-in user's ID
- `Settings.username`: Logged-in user's username
- `Settings.canSendPrivateMessages`: User capability flag

### Remote Logout Detection

**Mechanism**: ForumsClient monitors login state before/after network requests

**Implementation**:
```swift
// In ForumsClient request handling
let wasLoggedInBeforeRequest = isLoggedIn
// ... perform request ...
let isLoggedInAfterRequest = isLoggedIn

if wasLoggedInBeforeRequest && !isLoggedInAfterRequest {
    didRemotelyLogOut?()
}
```

**Response**: Automatically triggers `AppDelegate.logOut()`

### Session Expiry Warnings

**Location**: `App/Main/AppDelegate.swift`

**Logic**: Warns user when cookie expires within 7 days
```swift
if let expiryDate = ForumsClient.shared.loginCookieExpiryDate,
   expiryDate.timeIntervalSinceNow < (7 * 24 * 60 * 60) {
    // Show expiry warning
}
```

## Logout Process

### Complete Data Clearing

**Location**: `App/Main/AppDelegate.swift:188-213`

**Logout Steps**:
1. **Clear ALL Cookies**: `HTTPCookieStorage.shared.removeCookies(since: .distantPast)`
2. **Reset UserDefaults**: `UserDefaults.standard.removeAllObjectsInMainBundleDomain()`
3. **Clear URL Cache**: `URLCache.shared.removeAllCachedResponses()`
4. **Clear Image Cache**: Reset Nuke image cache
5. **Reset Core Data**: Delete and recreate entire data store
6. **Show Login Screen**: Return to authentication state

**Critical Implementation**:
```swift
func logOut() {
    // Step 1: Clear cookies
    HTTPCookieStorage.shared.removeCookies(since: .distantPast)
    
    // Step 2: Clear UserDefaults
    UserDefaults.standard.removeAllObjectsInMainBundleDomain()
    
    // Step 3: Clear caches
    URLCache.shared.removeAllCachedResponses()
    ImagePipeline.shared.cache.removeAll()
    
    // Step 4: Reset Core Data
    resetDataStore()
    
    // Step 5: Show login screen
    showLoginScreen()
}
```

## Security Characteristics

### Strengths
- **Complete Logout**: Thoroughly clears all authentication data
- **Remote Logout Detection**: Handles server-side session invalidation
- **Session Monitoring**: Tracks cookie expiry dates
- **HTTPS Only**: All authentication over secure transport

### Areas for Enhancement
- **No Keychain Usage**: Cookies stored in system storage, not Keychain
- **UserDefaults Storage**: User info in UserDefaults vs. secure storage
- **No Biometric Auth**: No Touch ID/Face ID integration
- **No Token Refresh**: Relies on cookie expiry

## Migration Considerations

### Must Preserve
1. **Cookie-based authentication** - cannot change to token-based
2. **System cookie storage** - Something Awful expects standard cookies
3. **Complete logout behavior** - security requirement
4. **Remote logout detection** - handles edge cases
5. **UserDefaults storage pattern** - changing could break existing installations

### Can Enhance
1. **Add biometric authentication** for app unlock
2. **Improve error handling** with modern Swift patterns
3. **Add login analytics** (while preserving privacy)
4. **Better session warnings** with SwiftUI alerts

### SwiftUI Migration Strategy

**Phase 1**: Wrap existing LoginViewController in UIViewControllerRepresentable
**Phase 2**: Create SwiftUI login form that calls same ForumsClient methods
**Phase 3**: Modernize error handling and state management

**Critical**: Never change the underlying authentication mechanism or cookie handling

## Testing Authentication

### Manual Testing Scenarios
1. **Fresh Install**: First-time login flow
2. **Session Expiry**: Handle expired cookies
3. **Network Errors**: Login failures and retries
4. **Remote Logout**: Server-initiated session termination
5. **Complete Logout**: Verify all data cleared
6. **State Restoration**: App launch with/without valid session

### Automated Testing
```swift
// Test login state detection
func testLoginStateDetection() {
    // Clear cookies
    XCTAssertFalse(ForumsClient.shared.isLoggedIn)
    
    // Add mock cookie
    // Assert logged in state
}
```

## Debugging Authentication

### Debug Flags
```swift
// Enable in development
UserDefaults.standard.set(true, forKey: "AwfulDebugAuth")
```

### Key Log Points
- Login attempt start/finish
- Cookie creation/deletion
- Session state changes
- Remote logout detection

### Common Issues
- **Cookies not persisting**: Check app group configuration
- **Login loops**: Verify cookie domain settings
- **Session expires immediately**: Check server time vs device time

## Files to Monitor During Migration

**Core Files**:
- `AwfulCore/Sources/AwfulCore/Networking/ForumsClient.swift`
- `App/View Controllers/LoginViewController.swift`
- `App/Main/AppDelegate.swift`
- `AwfulSettings/Sources/AwfulSettings/Settings.swift`

**Any changes to these files must preserve authentication behavior exactly.**
