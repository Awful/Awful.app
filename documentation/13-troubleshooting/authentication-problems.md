# Authentication Problems

## Overview

This document covers login issues, session management problems, and authentication debugging in Awful.app.

## Authentication Architecture

### Authentication Flow
1. **User Login**: Username/password submission
2. **Cookie Management**: Session cookies storage
3. **Session Validation**: Verify active session
4. **Auto-refresh**: Maintain session validity
5. **Logout**: Clear session and cookies

### Key Components
- `ForumsClient` - Main authentication handler
- `HTTPCookieStorage` - Session cookie management
- `LoginViewController` - User interface
- `AuthenticationManager` - Session state management

## Common Authentication Issues

### Login Failures
**Problem**: Cannot log into Something Awful account
**Error Messages**:
- "Invalid username or password"
- "Your account has been suspended"
- "Too many login attempts"
- "Connection failed"

**Debugging Steps**:
1. Verify credentials:
   ```swift
   func validateCredentials(username: String, password: String) {
       print("Login attempt for user: \(username)")
       print("Password length: \(password.count)")
       
       // Check for common issues
       if username.isEmpty {
           print("❌ Empty username")
           return
       }
       
       if password.isEmpty {
           print("❌ Empty password")
           return
       }
       
       if username.contains(" ") {
           print("⚠️ Username contains spaces")
       }
       
       // Test login
       performLogin(username: username, password: password)
   }
   ```

2. Check account status:
   ```swift
   func checkAccountStatus(username: String) {
       // Try accessing user profile directly
       let profileURL = URL(string: "https://forums.somethingawful.com/member.php?action=getinfo&username=\(username)")!
       
       URLSession.shared.dataTask(with: profileURL) { data, response, error in
           if let httpResponse = response as? HTTPURLResponse {
               switch httpResponse.statusCode {
               case 200:
                   print("✅ Account exists and is accessible")
               case 404:
                   print("❌ Account not found")
               case 403:
                   print("❌ Account may be banned or suspended")
               default:
                   print("⚠️ Unexpected status: \(httpResponse.statusCode)")
               }
           }
       }.resume()
   }
   ```

3. Debug login request:
   ```swift
   func debugLogin(username: String, password: String) {
       let loginURL = URL(string: "https://forums.somethingawful.com/account.php")!
       var request = URLRequest(url: loginURL)
       request.httpMethod = "POST"
       
       let bodyParameters = [
           "action": "login",
           "username": username,
           "password": password
       ]
       
       request.httpBody = bodyParameters
           .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
           .joined(separator: "&")
           .data(using: .utf8)
       
       request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
       
       print("🔐 Login request URL: \(request.url?.absoluteString ?? "")")
       print("🔐 Request headers: \(request.allHTTPHeaderFields ?? [:])")
       
       URLSession.shared.dataTask(with: request) { data, response, error in
           self.analyzeLoginResponse(data: data, response: response, error: error)
       }.resume()
   }
   ```

### Session Management Issues
**Problem**: Session expires frequently or doesn't persist
**Common Causes**:
- Cookies not being saved
- Session timeout too short
- Cookie domain/path issues
- Multiple concurrent sessions

**Solutions**:
1. Debug cookie storage:
   ```swift
   func debugCookieStorage() {
       let cookieStorage = HTTPCookieStorage.shared
       let saURL = URL(string: "https://forums.somethingawful.com")!
       
       guard let cookies = cookieStorage.cookies(for: saURL) else {
           print("❌ No cookies found for SA")
           return
       }
       
       print("🍪 Found \(cookies.count) cookies:")
       for cookie in cookies {
           print("  \(cookie.name): \(cookie.value)")
           print("    Domain: \(cookie.domain)")
           print("    Path: \(cookie.path)")
           print("    Secure: \(cookie.isSecure)")
           print("    HttpOnly: \(cookie.isHTTPOnly)")
           print("    Expires: \(cookie.expiresDate?.description ?? "Session")")
           print("    ---")
       }
   }
   ```

2. Monitor session validity:
   ```swift
   class SessionMonitor {
       private var timer: Timer?
       
       func startMonitoring() {
           timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
               self.checkSessionValidity()
           }
       }
       
       func checkSessionValidity() {
           guard isLoggedIn() else {
               print("❌ Session invalid - not logged in")
               handleSessionExpiration()
               return
           }
           
           // Test with a simple authenticated request
           testAuthenticatedRequest { isValid in
               if !isValid {
                   print("❌ Session invalid - authentication failed")
                   self.handleSessionExpiration()
               } else {
                   print("✅ Session valid")
               }
           }
       }
       
       private func testAuthenticatedRequest(completion: @escaping (Bool) -> Void) {
           let testURL = URL(string: "https://forums.somethingawful.com/usercp.php")!
           
           URLSession.shared.dataTask(with: testURL) { data, response, error in
               if let httpResponse = response as? HTTPURLResponse {
                   let isValid = httpResponse.statusCode == 200
                   DispatchQueue.main.async {
                       completion(isValid)
                   }
               } else {
                   DispatchQueue.main.async {
                       completion(false)
                   }
               }
           }.resume()
       }
   }
   ```

3. Implement session refresh:
   ```swift
   func refreshSession() {
       print("🔄 Refreshing session...")
       
       // Get current credentials from keychain
       guard let credentials = getStoredCredentials() else {
           print("❌ No stored credentials for refresh")
           showLoginScreen()
           return
       }
       
       // Perform silent login
       performLogin(username: credentials.username, password: credentials.password) { success in
           if success {
               print("✅ Session refreshed successfully")
           } else {
               print("❌ Session refresh failed")
               self.showLoginScreen()
           }
       }
   }
   ```

### Two-Factor Authentication
**Problem**: 2FA-enabled accounts can't log in
**Solutions**:
1. Detect 2FA requirement:
   ```swift
   func analyzeLoginResponse(data: Data?, response: URLResponse?, error: Error?) {
       guard let data = data,
             let html = String(data: data, encoding: .utf8) else {
           return
       }
       
       // Check for 2FA indicators
       if html.contains("two-factor") || html.contains("verification code") {
           print("🔐 Two-factor authentication required")
           show2FAPrompt()
       } else if html.contains("login successful") || html.contains("usercp") {
           print("✅ Login successful")
           handleSuccessfulLogin()
       } else if html.contains("invalid") || html.contains("error") {
           print("❌ Login failed")
           handleLoginError()
       }
   }
   ```

2. Handle 2FA flow:
   ```swift
   func handle2FA(username: String, password: String, code: String) {
       let loginURL = URL(string: "https://forums.somethingawful.com/account.php")!
       var request = URLRequest(url: loginURL)
       request.httpMethod = "POST"
       
       let bodyParameters = [
           "action": "login",
           "username": username,
           "password": password,
           "code": code  // 2FA code
       ]
       
       // Continue with 2FA login...
   }
   ```

### Cookie Problems
**Problem**: Authentication cookies not working properly
**Common Issues**:
- Cookies not being set
- Wrong domain/path
- Cookie expiration
- Secure flag issues

**Debugging**:
1. Inspect cookie details:
   ```swift
   func inspectAuthenticationCookies() {
       let cookieStorage = HTTPCookieStorage.shared
       let saURL = URL(string: "https://forums.somethingawful.com")!
       
       guard let cookies = cookieStorage.cookies(for: saURL) else {
           print("❌ No cookies found")
           return
       }
       
       let authCookies = ["bbuserid", "bbpassword", "sessionhash"]
       
       for cookieName in authCookies {
           if let cookie = cookies.first(where: { $0.name == cookieName }) {
               print("✅ \(cookieName): \(cookie.value)")
               
               // Check expiration
               if let expirationDate = cookie.expiresDate {
                   if expirationDate < Date() {
                       print("  ⚠️ Cookie expired: \(expirationDate)")
                   } else {
                       print("  ✅ Cookie valid until: \(expirationDate)")
                   }
               } else {
                   print("  ℹ️ Session cookie (no expiration)")
               }
           } else {
               print("❌ Missing cookie: \(cookieName)")
           }
       }
   }
   ```

2. Manual cookie management:
   ```swift
   func setCookie(name: String, value: String, domain: String, path: String) {
       let properties: [HTTPCookiePropertyKey: Any] = [
           .name: name,
           .value: value,
           .domain: domain,
           .path: path,
           .secure: true,
           .httpOnly: true
       ]
       
       if let cookie = HTTPCookie(properties: properties) {
           HTTPCookieStorage.shared.setCookie(cookie)
           print("✅ Set cookie: \(name)")
       } else {
           print("❌ Failed to create cookie: \(name)")
       }
   }
   ```

## Advanced Authentication Issues

### Account Bans and Suspensions
**Problem**: Account is banned or suspended
**Detection**:
```swift
func detectAccountBan(responseHTML: String) -> AccountStatus {
    if responseHTML.contains("banned") || responseHTML.contains("suspended") {
        if responseHTML.contains("temporary") {
            return .temporarilySuspended
        } else {
            return .permanentlyBanned
        }
    } else if responseHTML.contains("probation") {
        return .onProbation
    } else {
        return .active
    }
}

enum AccountStatus {
    case active
    case onProbation
    case temporarilySuspended
    case permanentlyBanned
}
```

### IP Blocking and Rate Limiting
**Problem**: Too many requests or IP blocked
**Solutions**:
1. Implement rate limiting:
   ```swift
   class RateLimiter {
       private var requestTimes = [Date]()
       private let maxRequests = 10
       private let timeWindow: TimeInterval = 60 // 1 minute
       
       func canMakeRequest() -> Bool {
           let now = Date()
           let cutoff = now.addingTimeInterval(-timeWindow)
           
           // Remove old requests
           requestTimes = requestTimes.filter { $0 > cutoff }
           
           return requestTimes.count < maxRequests
       }
       
       func recordRequest() {
           requestTimes.append(Date())
       }
   }
   ```

2. Handle rate limiting responses:
   ```swift
   func handleRateLimit(response: HTTPURLResponse) {
       if response.statusCode == 429 {
           let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
           let delay = Int(retryAfter ?? "60") ?? 60
           
           print("⏳ Rate limited. Retry after \(delay) seconds")
           
           DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
               self.retryAuthentication()
           }
       }
   }
   ```

### Network-Specific Issues
**Problem**: Authentication fails on certain networks
**Common Causes**:
- Corporate firewalls
- Proxy servers
- VPN issues
- Network restrictions

**Solutions**:
1. Test network connectivity:
   ```swift
   func testNetworkConnectivity() {
       let testURLs = [
           "https://forums.somethingawful.com",
           "https://www.google.com",
           "https://httpbin.org/ip"
       ]
       
       for urlString in testURLs {
           guard let url = URL(string: urlString) else { continue }
           
           URLSession.shared.dataTask(with: url) { data, response, error in
               if let httpResponse = response as? HTTPURLResponse {
                   print("✅ \(urlString): \(httpResponse.statusCode)")
               } else {
                   print("❌ \(urlString): \(error?.localizedDescription ?? "Unknown error")")
               }
           }.resume()
       }
   }
   ```

2. Detect proxy usage:
   ```swift
   func detectProxy() {
       let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
       
       if let settings = proxySettings {
           if let httpProxy = settings["HTTPProxy"] as? String,
              let httpPort = settings["HTTPPort"] as? Int {
               print("🌐 HTTP Proxy detected: \(httpProxy):\(httpPort)")
           }
           
           if let httpsProxy = settings["HTTPSProxy"] as? String,
              let httpsPort = settings["HTTPSPort"] as? Int {
               print("🔒 HTTPS Proxy detected: \(httpsProxy):\(httpsPort)")
           }
       }
   }
   ```

## Testing Authentication

### Unit Testing Login Flow
```swift
class AuthenticationTests: XCTestCase {
    func testValidLogin() {
        let expectation = XCTestExpectation(description: "Login")
        
        // Use test credentials
        let username = ProcessInfo.processInfo.environment["TEST_USERNAME"] ?? ""
        let password = ProcessInfo.processInfo.environment["TEST_PASSWORD"] ?? ""
        
        ForumsClient.shared.login(username: username, password: password) { result in
            switch result {
            case .success:
                XCTAssert(ForumsClient.shared.isLoggedIn)
            case .failure(let error):
                XCTFail("Login failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testInvalidCredentials() {
        let expectation = XCTestExpectation(description: "Invalid login")
        
        ForumsClient.shared.login(username: "invalid", password: "invalid") { result in
            switch result {
            case .success:
                XCTFail("Login should have failed")
            case .failure:
                XCTAssertFalse(ForumsClient.shared.isLoggedIn)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
}
```

### Integration Testing
```swift
func testSessionPersistence() {
    // Login
    login()
    
    // Restart app simulation
    ForumsClient.shared.reset()
    
    // Check if session persists
    XCTAssert(ForumsClient.shared.hasValidSession())
}
```

## Security Considerations

### Credential Storage
**Problem**: Secure storage of login credentials
**Solutions**:
1. Use Keychain for credential storage:
   ```swift
   class CredentialManager {
       private let service = "com.robotsandpencils.Awful"
       
       func store(username: String, password: String) {
           let usernameData = username.data(using: .utf8)!
           let passwordData = password.data(using: .utf8)!
           
           // Store username
           var usernameQuery: [String: Any] = [
               kSecClass as String: kSecClassGenericPassword,
               kSecAttrService as String: service,
               kSecAttrAccount as String: "username",
               kSecValueData as String: usernameData
           ]
           
           SecItemDelete(usernameQuery as CFDictionary)
           SecItemAdd(usernameQuery as CFDictionary, nil)
           
           // Store password
           var passwordQuery: [String: Any] = [
               kSecClass as String: kSecClassGenericPassword,
               kSecAttrService as String: service,
               kSecAttrAccount as String: "password",
               kSecValueData as String: passwordData
           ]
           
           SecItemDelete(passwordQuery as CFDictionary)
           SecItemAdd(passwordQuery as CFDictionary, nil)
       }
       
       func retrieve() -> (username: String, password: String)? {
           // Retrieve username and password from Keychain
           // Implementation details...
           return nil
       }
   }
   ```

### Session Security
```swift
func validateSessionSecurity() {
    let cookies = HTTPCookieStorage.shared.cookies(for: URL(string: "https://forums.somethingawful.com")!)
    
    for cookie in cookies ?? [] {
        // Check security flags
        if !cookie.isSecure {
            print("⚠️ Cookie \(cookie.name) is not secure")
        }
        
        if !cookie.isHTTPOnly {
            print("⚠️ Cookie \(cookie.name) is not HTTP-only")
        }
        
        // Check expiration
        if let expiration = cookie.expiresDate,
           expiration.timeIntervalSinceNow < 3600 { // Less than 1 hour
            print("⚠️ Cookie \(cookie.name) expires soon")
        }
    }
}
```

## Recovery Strategies

### Automatic Recovery
```swift
class AuthenticationRecoveryManager {
    func attemptRecovery() {
        // Try session refresh first
        if let credentials = getStoredCredentials() {
            refreshSession(credentials: credentials) { success in
                if !success {
                    // Clear invalid session
                    self.clearSession()
                    // Prompt for re-login
                    self.showLoginPrompt()
                }
            }
        } else {
            // No stored credentials
            showLoginPrompt()
        }
    }
    
    func clearSession() {
        // Clear all authentication cookies
        let cookieStorage = HTTPCookieStorage.shared
        if let cookies = cookieStorage.cookies {
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
            }
        }
        
        // Clear stored credentials
        clearStoredCredentials()
        
        // Reset authentication state
        ForumsClient.shared.reset()
    }
}
```

### Error Handling
```swift
enum AuthenticationError: Error, LocalizedError {
    case invalidCredentials
    case accountSuspended
    case networkError(Error)
    case twoFactorRequired
    case rateLimited
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .accountSuspended:
            return "Your account has been suspended"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .twoFactorRequired:
            return "Two-factor authentication required"
        case .rateLimited:
            return "Too many requests. Please try again later"
        case .serverError:
            return "Server error. Please try again"
        }
    }
}
```

## Best Practices

### Authentication Guidelines
1. **Secure Storage**: Always use Keychain for credentials
2. **Session Management**: Implement proper session lifecycle
3. **Error Handling**: Provide clear error messages
4. **Security**: Follow security best practices
5. **Testing**: Comprehensive authentication testing

### User Experience
1. **Clear Feedback**: Show authentication status clearly
2. **Error Recovery**: Provide helpful error messages
3. **Offline Handling**: Handle offline scenarios gracefully
4. **Performance**: Minimize authentication delays
5. **Accessibility**: Ensure login screens are accessible