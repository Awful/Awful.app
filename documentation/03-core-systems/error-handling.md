# Error Handling

## Overview

The error handling system provides robust error management, recovery strategies, and user-friendly error reporting throughout the Awful app. This system must be comprehensive and maintainable during the SwiftUI migration.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Error Handling System                     │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Error Types     │  │  Error Recovery │  │ User Presentation│ │
│  │                 │  │                 │  │                 │  │
│  │ • Network       │  │ • Retry Logic   │  │ • Alerts        │  │
│  │ • Parsing       │  │ • Fallbacks     │  │ • Banners       │  │
│  │ • Auth          │  │ • Graceful      │  │ • Toast         │  │
│  │ • Validation    │  │   Degradation   │  │ • Logging       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Error Context   │  │  Monitoring     │  │  Debug Support  │  │
│  │                 │  │                 │  │                 │  │
│  │ • Stack Traces  │  │ • Analytics     │  │ • Detailed Logs │  │
│  │ • User Actions  │  │ • Crash Reports │  │ • State Capture │  │
│  │ • System State  │  │ • Metrics       │  │ • Reproduction  │  │
│  │ • Context Data  │  │ • Trends        │  │ • Debug Tools   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Error Type Definitions

### Core Error Types
```swift
// MARK: - Base Error Protocol

protocol AwfulError: Error, LocalizedError, CustomStringConvertible {
    var errorCategory: ErrorCategory { get }
    var errorCode: String { get }
    var underlyingError: Error? { get }
    var userInfo: [String: Any] { get }
    var isRecoverable: Bool { get }
    var recoverySuggestion: String? { get }
}

enum ErrorCategory: String, CaseIterable {
    case network = "network"
    case authentication = "authentication"
    case parsing = "parsing"
    case coreData = "core_data"
    case validation = "validation"
    case userInterface = "ui"
    case system = "system"
    case unknown = "unknown"
}

// MARK: - Network Errors

enum NetworkError: AwfulError {
    case noConnection
    case timeout
    case invalidURL(String)
    case invalidResponse(statusCode: Int)
    case serverError(statusCode: Int, message: String?)
    case rateLimited(retryAfter: TimeInterval?)
    case authenticationRequired
    case authenticationFailed(Error)
    case parseError(Error)
    case underlying(Error)
    
    var errorCategory: ErrorCategory { return .network }
    
    var errorCode: String {
        switch self {
        case .noConnection: return "network_no_connection"
        case .timeout: return "network_timeout"
        case .invalidURL: return "network_invalid_url"
        case .invalidResponse: return "network_invalid_response"
        case .serverError: return "network_server_error"
        case .rateLimited: return "network_rate_limited"
        case .authenticationRequired: return "network_auth_required"
        case .authenticationFailed: return "network_auth_failed"
        case .parseError: return "network_parse_error"
        case .underlying: return "network_underlying"
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .authenticationFailed(let error), .parseError(let error), .underlying(let error):
            return error
        default:
            return nil
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = ["category": errorCategory.rawValue, "code": errorCode]
        
        switch self {
        case .invalidURL(let url):
            info["url"] = url
        case .invalidResponse(let statusCode), .serverError(let statusCode, _):
            info["statusCode"] = statusCode
        case .serverError(_, let message):
            if let message = message {
                info["serverMessage"] = message
            }
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                info["retryAfter"] = retryAfter
            }
        default:
            break
        }
        
        return info
    }
    
    var isRecoverable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError, .rateLimited:
            return true
        case .invalidURL, .invalidResponse, .authenticationFailed:
            return false
        case .authenticationRequired, .parseError, .underlying:
            return true
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse(let statusCode):
            return "Invalid response (status: \(statusCode))"
        case .serverError(let statusCode, let message):
            return message ?? "Server error (status: \(statusCode))"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Please try again in \(Int(retryAfter)) seconds"
            } else {
                return "Rate limited. Please try again later"
            }
        case .authenticationRequired:
            return "Authentication required"
        case .authenticationFailed:
            return "Authentication failed"
        case .parseError:
            return "Failed to parse server response"
        case .underlying(let error):
            return error.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Check your internet connection and try again"
        case .timeout, .serverError:
            return "Please try again in a few moments"
        case .rateLimited:
            return "Wait a moment before making another request"
        case .authenticationRequired, .authenticationFailed:
            return "Please log in again"
        case .parseError:
            return "This may be a temporary server issue"
        default:
            return nil
        }
    }
    
    var description: String {
        return errorDescription ?? "Unknown network error"
    }
}
```

### Authentication Errors
```swift
enum AuthenticationError: AwfulError {
    case invalidCredentials
    case accountBanned(reason: String?)
    case sessionExpired
    case twoFactorRequired
    case twoFactorInvalid
    case accountLocked(unlockDate: Date?)
    case serverMaintenance
    
    var errorCategory: ErrorCategory { return .authentication }
    
    var errorCode: String {
        switch self {
        case .invalidCredentials: return "auth_invalid_credentials"
        case .accountBanned: return "auth_account_banned"
        case .sessionExpired: return "auth_session_expired"
        case .twoFactorRequired: return "auth_2fa_required"
        case .twoFactorInvalid: return "auth_2fa_invalid"
        case .accountLocked: return "auth_account_locked"
        case .serverMaintenance: return "auth_server_maintenance"
        }
    }
    
    var underlyingError: Error? { return nil }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = ["category": errorCategory.rawValue, "code": errorCode]
        
        switch self {
        case .accountBanned(let reason):
            if let reason = reason {
                info["banReason"] = reason
            }
        case .accountLocked(let unlockDate):
            if let unlockDate = unlockDate {
                info["unlockDate"] = unlockDate
            }
        default:
            break
        }
        
        return info
    }
    
    var isRecoverable: Bool {
        switch self {
        case .invalidCredentials, .twoFactorInvalid:
            return true
        case .accountBanned, .accountLocked:
            return false
        case .sessionExpired, .twoFactorRequired, .serverMaintenance:
            return true
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .accountBanned(let reason):
            return reason ?? "Your account has been banned"
        case .sessionExpired:
            return "Your session has expired"
        case .twoFactorRequired:
            return "Two-factor authentication required"
        case .twoFactorInvalid:
            return "Invalid two-factor authentication code"
        case .accountLocked(let unlockDate):
            if let unlockDate = unlockDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return "Account locked until \(formatter.string(from: unlockDate))"
            } else {
                return "Account is temporarily locked"
            }
        case .serverMaintenance:
            return "Server is under maintenance"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Please check your username and password"
        case .sessionExpired:
            return "Please log in again"
        case .twoFactorRequired:
            return "Enter your two-factor authentication code"
        case .twoFactorInvalid:
            return "Please check your two-factor authentication code"
        case .serverMaintenance:
            return "Please try again later"
        default:
            return nil
        }
    }
    
    var description: String {
        return errorDescription ?? "Authentication error"
    }
}
```

### Core Data Errors
```swift
enum CoreDataError: AwfulError {
    case storeLoadFailed(Error)
    case saveFailed(Error)
    case fetchFailed(Error)
    case migrationFailed(Error)
    case validationFailed(String)
    case mergeConflict
    case diskFull
    case permissionDenied
    
    var errorCategory: ErrorCategory { return .coreData }
    
    var errorCode: String {
        switch self {
        case .storeLoadFailed: return "coredata_store_load_failed"
        case .saveFailed: return "coredata_save_failed"
        case .fetchFailed: return "coredata_fetch_failed"
        case .migrationFailed: return "coredata_migration_failed"
        case .validationFailed: return "coredata_validation_failed"
        case .mergeConflict: return "coredata_merge_conflict"
        case .diskFull: return "coredata_disk_full"
        case .permissionDenied: return "coredata_permission_denied"
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .storeLoadFailed(let error), .saveFailed(let error), 
             .fetchFailed(let error), .migrationFailed(let error):
            return error
        default:
            return nil
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = ["category": errorCategory.rawValue, "code": errorCode]
        
        switch self {
        case .validationFailed(let details):
            info["validationDetails"] = details
        default:
            break
        }
        
        return info
    }
    
    var isRecoverable: Bool {
        switch self {
        case .storeLoadFailed, .migrationFailed, .diskFull, .permissionDenied:
            return false
        case .saveFailed, .fetchFailed, .validationFailed, .mergeConflict:
            return true
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .storeLoadFailed:
            return "Failed to load data store"
        case .saveFailed:
            return "Failed to save data"
        case .fetchFailed:
            return "Failed to fetch data"
        case .migrationFailed:
            return "Failed to migrate data"
        case .validationFailed(let details):
            return "Data validation failed: \(details)"
        case .mergeConflict:
            return "Data conflict detected"
        case .diskFull:
            return "Not enough storage space"
        case .permissionDenied:
            return "Permission denied to access data"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .fetchFailed:
            return "Please try again"
        case .mergeConflict:
            return "Your data will be refreshed"
        case .diskFull:
            return "Free up storage space and try again"
        case .permissionDenied:
            return "Check app permissions in Settings"
        default:
            return "Please restart the app"
        }
    }
    
    var description: String {
        return errorDescription ?? "Core Data error"
    }
}
```

## Error Handler

### Central Error Management
```swift
class ErrorHandler {
    static let shared = ErrorHandler()
    
    private let logger = AwfulLogger.shared
    private var errorCallbacks: [String: (AwfulError) -> Void] = [:]
    
    private init() {}
    
    // MARK: - Error Processing
    
    func handle(_ error: Error, context: ErrorContext? = nil) {
        let awfulError = processError(error, context: context)
        
        // Log the error
        logError(awfulError, context: context)
        
        // Record analytics
        recordErrorAnalytics(awfulError, context: context)
        
        // Trigger callbacks
        notifyErrorCallbacks(awfulError)
        
        // Attempt recovery if possible
        attemptRecovery(awfulError, context: context)
    }
    
    private func processError(_ error: Error, context: ErrorContext?) -> AwfulError {
        // Convert standard errors to AwfulErrors
        if let awfulError = error as? AwfulError {
            return awfulError
        }
        
        // Convert known system errors
        if let urlError = error as? URLError {
            return convertURLError(urlError)
        }
        
        if let coreDataError = error as? NSError, coreDataError.domain == NSCocoaErrorDomain {
            return convertCoreDataError(coreDataError)
        }
        
        // Wrap unknown errors
        return UnknownError(underlyingError: error, context: context)
    }
    
    private func convertURLError(_ urlError: URLError) -> NetworkError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .badURL:
            return .invalidURL(urlError.failingURL?.absoluteString ?? "")
        case .badServerResponse:
            return .invalidResponse(statusCode: 0)
        case .userAuthenticationRequired:
            return .authenticationRequired
        default:
            return .underlying(urlError)
        }
    }
    
    private func convertCoreDataError(_ nsError: NSError) -> CoreDataError {
        switch nsError.code {
        case NSPersistentStoreIncompatibleVersionHashError:
            return .migrationFailed(nsError)
        case NSValidationMissingMandatoryPropertyError, NSValidationStringTooShortError:
            return .validationFailed(nsError.localizedDescription)
        case NSManagedObjectMergeError:
            return .mergeConflict
        default:
            return .saveFailed(nsError)
        }
    }
    
    // MARK: - Error Recovery
    
    private func attemptRecovery(_ error: AwfulError, context: ErrorContext?) {
        guard error.isRecoverable else { return }
        
        switch error.errorCategory {
        case .network:
            attemptNetworkRecovery(error as? NetworkError, context: context)
        case .authentication:
            attemptAuthenticationRecovery(error as? AuthenticationError, context: context)
        case .coreData:
            attemptCoreDataRecovery(error as? CoreDataError, context: context)
        default:
            break
        }
    }
    
    private func attemptNetworkRecovery(_ error: NetworkError?, context: ErrorContext?) {
        guard let error = error else { return }
        
        switch error {
        case .authenticationRequired, .authenticationFailed:
            // Trigger re-authentication
            NotificationCenter.default.post(name: .authenticationRequired, object: nil)
            
        case .rateLimited(let retryAfter):
            // Schedule retry
            let delay = retryAfter ?? 60.0
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                context?.retryAction?()
            }
            
        case .noConnection, .timeout, .serverError:
            // Offer manual retry
            break
            
        default:
            break
        }
    }
    
    private func attemptAuthenticationRecovery(_ error: AuthenticationError?, context: ErrorContext?) {
        guard let error = error else { return }
        
        switch error {
        case .sessionExpired:
            // Clear stored credentials and request login
            UserDefaults.standard.removeObject(forKey: "authCookies")
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            
        case .twoFactorRequired:
            // Show 2FA input
            NotificationCenter.default.post(name: .twoFactorRequired, object: nil)
            
        default:
            break
        }
    }
    
    private func attemptCoreDataRecovery(_ error: CoreDataError?, context: ErrorContext?) {
        guard let error = error else { return }
        
        switch error {
        case .mergeConflict:
            // Refresh data from persistent store
            PersistenceController.shared.viewContext.refreshAllObjects()
            
        case .saveFailed:
            // Rollback and retry
            PersistenceController.shared.viewContext.rollback()
            context?.retryAction?()
            
        default:
            break
        }
    }
}
```

### Error Context
```swift
struct ErrorContext {
    let sourceFunction: String
    let sourceFile: String
    let sourceLine: Int
    let userAction: String?
    let additionalInfo: [String: Any]
    let retryAction: (() -> Void)?
    
    init(
        sourceFunction: String = #function,
        sourceFile: String = #file,
        sourceLine: Int = #line,
        userAction: String? = nil,
        additionalInfo: [String: Any] = [:],
        retryAction: (() -> Void)? = nil
    ) {
        self.sourceFunction = sourceFunction
        self.sourceFile = sourceFile
        self.sourceLine = sourceLine
        self.userAction = userAction
        self.additionalInfo = additionalInfo
        self.retryAction = retryAction
    }
}
```

## User Presentation

### Error Alert System
```swift
class ErrorPresenter {
    static let shared = ErrorPresenter()
    
    private init() {}
    
    // MARK: - Alert Presentation
    
    func presentError(_ error: AwfulError, in viewController: UIViewController) {
        let alertController = createErrorAlert(for: error)
        viewController.present(alertController, animated: true)
    }
    
    private func createErrorAlert(for error: AwfulError) -> UIAlertController {
        let title = getErrorTitle(for: error)
        let message = error.errorDescription ?? "An unknown error occurred"
        
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        // Add OK button
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Add retry button if recoverable
        if error.isRecoverable, let suggestion = error.recoverySuggestion {
            alertController.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                // Trigger retry logic
                NotificationCenter.default.post(
                    name: .errorRetryRequested,
                    object: error
                )
            })
        }
        
        // Add settings button for certain errors
        if shouldShowSettingsButton(for: error) {
            alertController.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                self.openSettings()
            })
        }
        
        return alertController
    }
    
    private func getErrorTitle(for error: AwfulError) -> String {
        switch error.errorCategory {
        case .network:
            return "Network Error"
        case .authentication:
            return "Authentication Error"
        case .coreData:
            return "Data Error"
        case .parsing:
            return "Content Error"
        case .validation:
            return "Validation Error"
        case .userInterface:
            return "Interface Error"
        case .system:
            return "System Error"
        case .unknown:
            return "Error"
        }
    }
    
    private func shouldShowSettingsButton(for error: AwfulError) -> Bool {
        switch error {
        case let coreDataError as CoreDataError:
            return coreDataError == .permissionDenied
        case let networkError as NetworkError:
            return networkError == .noConnection
        default:
            return false
        }
    }
    
    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        UIApplication.shared.open(settingsURL)
    }
}
```

### SwiftUI Error Presentation
```swift
// MARK: - SwiftUI Error Handling

struct ErrorBanner: View {
    let error: AwfulError
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(getErrorTitle(for: error))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let description = error.errorDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            HStack {
                if error.isRecoverable, onRetry != nil {
                    Button("Retry") {
                        onRetry?()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Button("Dismiss") {
                    onDismiss()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
        .shadow(radius: 2)
    }
    
    private var iconName: String {
        switch error.errorCategory {
        case .network:
            return "wifi.exclamationmark"
        case .authentication:
            return "person.circle.fill.badge.xmark"
        case .coreData:
            return "externaldrive.fill.badge.xmark"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch error.errorCategory {
        case .network:
            return .orange
        case .authentication:
            return .red
        case .coreData:
            return .purple
        default:
            return .yellow
        }
    }
    
    private func getErrorTitle(for error: AwfulError) -> String {
        // Same logic as UIKit version
        return ErrorPresenter.shared.getErrorTitle(for: error)
    }
}

// Usage in SwiftUI
struct ContentView: View {
    @State private var currentError: AwfulError?
    @State private var showErrorBanner = false
    
    var body: some View {
        NavigationView {
            // Main content
        }
        .overlay(
            VStack {
                if showErrorBanner, let error = currentError {
                    ErrorBanner(
                        error: error,
                        onDismiss: {
                            withAnimation {
                                showErrorBanner = false
                                currentError = nil
                            }
                        },
                        onRetry: error.isRecoverable ? {
                            // Retry logic
                        } : nil
                    )
                    .transition(.move(edge: .top))
                }
                Spacer()
            },
            alignment: .top
        )
    }
}
```

## Logging and Analytics

### Error Logging
```swift
extension ErrorHandler {
    private func logError(_ error: AwfulError, context: ErrorContext?) {
        var logMessage = "Error: \(error.errorCode) - \(error.description)"
        
        if let context = context {
            logMessage += "\nSource: \(context.sourceFunction) (\(context.sourceFile):\(context.sourceLine))"
            
            if let userAction = context.userAction {
                logMessage += "\nUser Action: \(userAction)"
            }
            
            if !context.additionalInfo.isEmpty {
                logMessage += "\nAdditional Info: \(context.additionalInfo)"
            }
        }
        
        if let underlyingError = error.underlyingError {
            logMessage += "\nUnderlying Error: \(underlyingError)"
        }
        
        logger.log(logMessage, level: .error)
    }
    
    private func recordErrorAnalytics(_ error: AwfulError, context: ErrorContext?) {
        let properties: [String: Any] = [
            "error_category": error.errorCategory.rawValue,
            "error_code": error.errorCode,
            "is_recoverable": error.isRecoverable,
            "user_info": error.userInfo
        ]
        
        // Record to analytics service
        AnalyticsManager.shared.track("error_occurred", properties: properties)
    }
}
```

## Testing

### Error Testing Utilities
```swift
class ErrorTestUtilities {
    static func createMockNetworkError() -> NetworkError {
        return .serverError(statusCode: 500, message: "Internal Server Error")
    }
    
    static func createMockAuthError() -> AuthenticationError {
        return .invalidCredentials
    }
    
    static func createMockCoreDataError() -> CoreDataError {
        let nsError = NSError(domain: NSCocoaErrorDomain, code: NSValidationMissingMandatoryPropertyError, userInfo: nil)
        return .validationFailed("Missing required property")
    }
    
    static func simulateErrorHandling(_ error: AwfulError) {
        let context = ErrorContext(
            userAction: "Test Action",
            additionalInfo: ["test": true]
        )
        
        ErrorHandler.shared.handle(error, context: context)
    }
}

// Test example
class ErrorHandlingTests: XCTestCase {
    func testNetworkErrorHandling() {
        let error = ErrorTestUtilities.createMockNetworkError()
        
        XCTAssertEqual(error.errorCategory, .network)
        XCTAssertTrue(error.isRecoverable)
        XCTAssertNotNil(error.errorDescription)
    }
    
    func testErrorRecovery() {
        let error = NetworkError.authenticationRequired
        let expectation = XCTestExpectation(description: "Recovery notification")
        
        NotificationCenter.default.addObserver(
            forName: .authenticationRequired,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        ErrorHandler.shared.handle(error)
        
        wait(for: [expectation], timeout: 1.0)
    }
}
```

## Best Practices

1. **Comprehensive Error Types**: Define specific error types for each domain
2. **Context Preservation**: Always include relevant context information
3. **User-Friendly Messages**: Provide clear, actionable error messages
4. **Recovery Strategies**: Implement automatic recovery where possible
5. **Logging**: Log all errors with sufficient detail for debugging
6. **Analytics**: Track error patterns to identify systemic issues
7. **Testing**: Test error scenarios thoroughly
8. **Graceful Degradation**: Maintain app functionality when possible