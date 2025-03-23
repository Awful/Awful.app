import Foundation

/// Protocol defining the common interface for Imgur authentication
public protocol ImgurAuthProvider {
    /// Returns the current bearer token for authenticated requests, if available
    var bearerToken: String? { get }
    
    /// Returns true if the user is authenticated
    var isAuthenticated: Bool { get }
    
    /// Clears authentication credentials
    func logout()
    
    /// Returns the client ID to use for API requests
    var clientID: String { get }
}

/// Constants related to Imgur API responses
public enum ImgurAuthError: Error {
    /// Rate limit exceeded (429 Too Many Requests)
    case rateLimited
    
    /// Authentication failed
    case authenticationFailed
    
    /// User cancelled authentication
    case userCancelled
    
    /// Invalid client ID
    case invalidClientID
    
    /// Generic error
    case other(String)
}

/// Helper for parsing Imgur OAuth responses
@available(iOS 13.0, macOS 10.15, *)
public struct ImgurOAuthResponse {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: TimeInterval
    
    /// Parse an OAuth callback URL fragment into a structured response
    public static func parse(from fragment: String) -> ImgurOAuthResponse? {
        let fragmentComponents = fragment
            .components(separatedBy: "&")
            .map { $0.components(separatedBy: "=") }
            .filter { $0.count == 2 }
            .reduce(into: [String: String]()) { result, pair in
                result[pair[0]] = pair[1]
            }
        
        if let accessToken = fragmentComponents["access_token"],
           let expiresInString = fragmentComponents["expires_in"],
           let expiresIn = TimeInterval(expiresInString),
           let refreshToken = fragmentComponents["refresh_token"] {
            return ImgurOAuthResponse(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresIn: expiresIn
            )
        }
        
        return nil
    }
    
    /// Check if a URL indicates an error response
    public static func checkForError(in url: URL) -> ImgurAuthError? {
        if url.absoluteString.contains("error=") {
            // Extract error information
            if let fragment = url.fragment, fragment.contains("error=") {
                let fragmentParts = fragment.components(separatedBy: "&")
                var errorMessage = "Unknown error"
                
                for part in fragmentParts {
                    if part.hasPrefix("error=") {
                        errorMessage = part.replacingOccurrences(of: "error=", with: "")
                        errorMessage = errorMessage.removingPercentEncoding ?? errorMessage
                    }
                }
                
                // Map error messages to specific error types
                if errorMessage.contains("429") || errorMessage.contains("Too Many Requests") {
                    return .rateLimited
                } else if errorMessage.contains("cancel") || errorMessage.contains("cancelled") {
                    return .userCancelled
                } else if errorMessage.contains("invalid_client") {
                    return .invalidClientID
                }
                
                return .other(errorMessage)
            }
            
            // Check query parameters for errors
            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                for item in queryItems where item.name == "error" {
                    let errorMessage = item.value ?? "Unknown error"
                    
                    if errorMessage.contains("429") || errorMessage.contains("Too Many Requests") {
                        return .rateLimited
                    } else if errorMessage.contains("cancel") || errorMessage.contains("cancelled") {
                        return .userCancelled
                    } else if errorMessage.contains("invalid_client") {
                        return .invalidClientID
                    }
                    
                    return .other(errorMessage)
                }
            }
        }
        
        return nil
    }
} 