# Networking Layer

## Overview

The networking layer handles all communication with Something Awful's forums, including authentication, HTML scraping, and data parsing. This document covers the current implementation and planned improvements.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Networking Layer                           │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  ForumsClient   │  │  URLSession     │  │  HTML Parsing   │  │
│  │                 │  │                 │  │                 │  │
│  │ • Authentication│  │ • Request       │  │ • HTMLReader    │  │
│  │ • API Methods   │  │ • Response      │  │ • Scraping      │  │
│  │ • Session Mgmt  │  │ • Cookies       │  │ • Validation    │  │
│  │ • Error Handling│  │ • Caching       │  │ • Parsing       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Data Models    │  │  Serialization  │  │  Caching Layer  │  │
│  │                 │  │                 │  │                 │  │
│  │ • Forum         │  │ • JSON          │  │ • Response Cache│  │
│  │ • Thread        │  │ • HTML          │  │ • Image Cache   │  │
│  │ • Post          │  │ • Form Data     │  │ • Offline Data  │  │
│  │ • User          │  │ • Multipart     │  │ • TTL Policies  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## ForumsClient

### Core Implementation
```swift
public class ForumsClient {
    public static let shared = ForumsClient()
    
    private let session: URLSession
    private let baseURL = URL(string: "https://forums.somethingawful.com")!
    private var authenticationCookies: [HTTPCookie] = []
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookiePolicy = .always
        configuration.requestCachePolicy = .reloadIgnoringCacheData
        configuration.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        
        self.session = URLSession(configuration: configuration)
    }
}
```

### Authentication
```swift
extension ForumsClient {
    public func authenticate(username: String, password: String) async throws -> Bool {
        let loginURL = baseURL.appendingPathComponent("account.php")
        
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let formData = [
            "action": "login",
            "username": username,
            "password": password
        ]
        
        request.httpBody = formData.formEncoded
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Check for authentication cookies
        if let cookies = HTTPCookieStorage.shared.cookies(for: loginURL) {
            authenticationCookies = cookies.filter { $0.name.contains("session") }
        }
        
        // Validate login success
        let html = String(data: data, encoding: .utf8) ?? ""
        let isAuthenticated = !html.contains("Invalid username or password")
        
        if isAuthenticated {
            UserDefaults.standard.set(username, forKey: "username")
            storeAuthenticationCookies()
        }
        
        return isAuthenticated
    }
    
    private func storeAuthenticationCookies() {
        let cookieData = try? NSKeyedArchiver.archivedData(withRootObject: authenticationCookies, requiringSecureCoding: false)
        UserDefaults.standard.set(cookieData, forKey: "authCookies")
    }
    
    private func loadAuthenticationCookies() {
        guard let cookieData = UserDefaults.standard.data(forKey: "authCookies"),
              let cookies = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(cookieData) as? [HTTPCookie] else {
            return
        }
        
        authenticationCookies = cookies
        
        for cookie in cookies {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }
}
```

### API Methods
```swift
extension ForumsClient {
    // Load forum list
    public func loadForums() async throws -> [Forum] {
        let url = baseURL.appendingPathComponent("index.php")
        let (data, _) = try await session.data(from: url)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidData
        }
        
        return try parseForums(from: html)
    }
    
    // Load threads for a forum
    public func loadThreads(for forum: Forum, page: Int = 1) async throws -> [Thread] {
        var components = URLComponents(url: baseURL.appendingPathComponent("forumdisplay.php"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "forumid", value: String(forum.id)),
            URLQueryItem(name: "pagenumber", value: String(page))
        ]
        
        let (data, _) = try await session.data(from: components.url!)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidData
        }
        
        return try parseThreads(from: html, forum: forum)
    }
    
    // Load posts for a thread
    public func loadPosts(for thread: Thread, page: Int = 1) async throws -> [Post] {
        var components = URLComponents(url: baseURL.appendingPathComponent("showthread.php"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "threadid", value: String(thread.id)),
            URLQueryItem(name: "pagenumber", value: String(page))
        ]
        
        let (data, _) = try await session.data(from: components.url!)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidData
        }
        
        return try parsePosts(from: html, thread: thread)
    }
    
    // Post a reply
    public func postReply(to thread: Thread, content: String) async throws -> Post {
        // First, get the form token
        let formToken = try await getFormToken(for: thread)
        
        let replyURL = baseURL.appendingPathComponent("newreply.php")
        
        var request = URLRequest(url: replyURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let formData = [
            "action": "postreply",
            "threadid": String(thread.id),
            "formkey": formToken,
            "message": content,
            "parseurl": "yes"
        ]
        
        request.httpBody = formData.formEncoded
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.postFailed
        }
        
        // Parse the response to get the new post
        let html = String(data: data, encoding: .utf8) ?? ""
        return try parseNewPost(from: html, thread: thread)
    }
    
    private func getFormToken(for thread: Thread) async throws -> String {
        let url = baseURL.appendingPathComponent("newreply.php")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "threadid", value: String(thread.id))]
        
        let (data, _) = try await session.data(from: components.url!)
        let html = String(data: data, encoding: .utf8) ?? ""
        
        return try parseFormToken(from: html)
    }
}
```

## HTML Parsing

### HTMLReader Integration
```swift
import HTMLReader

extension ForumsClient {
    private func parseForums(from html: String) throws -> [Forum] {
        let document = HTMLDocument(string: html)
        
        guard let forumTable = document.firstNode(matchingSelector: "table.forumlist") else {
            throw NetworkError.parsingError("Forum table not found")
        }
        
        let forumRows = forumTable.nodes(matchingSelector: "tr.forum")
        
        return forumRows.compactMap { row in
            guard let titleLink = row.firstNode(matchingSelector: "a.forum"),
                  let title = titleLink.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let href = titleLink["href"],
                  let forumId = extractForumId(from: href) else {
                return nil
            }
            
            let forum = Forum(context: persistentContainer.viewContext)
            forum.id = Int32(forumId)
            forum.title = title
            forum.lastModified = Date()
            
            // Parse additional forum metadata
            if let descriptionNode = row.firstNode(matchingSelector: ".description") {
                forum.description = descriptionNode.textContent?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            return forum
        }
    }
    
    private func parseThreads(from html: String, forum: Forum) throws -> [Thread] {
        let document = HTMLDocument(string: html)
        
        guard let threadTable = document.firstNode(matchingSelector: "table.threadlist") else {
            throw NetworkError.parsingError("Thread table not found")
        }
        
        let threadRows = threadTable.nodes(matchingSelector: "tr.thread")
        
        return threadRows.compactMap { row in
            guard let titleLink = row.firstNode(matchingSelector: "a.thread_title"),
                  let title = titleLink.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let href = titleLink["href"],
                  let threadId = extractThreadId(from: href) else {
                return nil
            }
            
            let thread = Thread(context: persistentContainer.viewContext)
            thread.id = Int32(threadId)
            thread.title = title
            thread.forum = forum
            thread.lastModified = Date()
            
            // Parse thread metadata
            parseThreadMetadata(from: row, into: thread)
            
            return thread
        }
    }
    
    private func parseThreadMetadata(from row: HTMLNode, into thread: Thread) {
        // Author
        if let authorNode = row.firstNode(matchingSelector: ".author") {
            thread.author = authorNode.textContent?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Post count
        if let countNode = row.firstNode(matchingSelector: ".replies") {
            thread.postCount = Int32(countNode.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0") ?? 0
        }
        
        // Last post date
        if let dateNode = row.firstNode(matchingSelector: ".lastpost .date") {
            thread.lastPostDate = parseDate(from: dateNode.textContent ?? "")
        }
        
        // Unread indicator
        thread.hasUnreadPosts = row.firstNode(matchingSelector: ".unread") != nil
        
        // Sticky/announcement flags
        thread.isSticky = row.firstNode(matchingSelector: ".sticky") != nil
        thread.isAnnouncement = row.firstNode(matchingSelector: ".announcement") != nil
    }
}
```

### Robust Parsing Strategies
```swift
// Defensive parsing with fallbacks
private func parseWithFallback<T>(_ parsers: [() throws -> T?]) throws -> T {
    var lastError: Error?
    
    for parser in parsers {
        do {
            if let result = try parser() {
                return result
            }
        } catch {
            lastError = error
        }
    }
    
    throw lastError ?? NetworkError.parsingError("All parsers failed")
}

// Example usage
private func parseThreadTitle(from row: HTMLNode) throws -> String {
    return try parseWithFallback([
        { row.firstNode(matchingSelector: "a.thread_title")?.textContent },
        { row.firstNode(matchingSelector: ".title a")?.textContent },
        { row.firstNode(matchingSelector: "td:nth-child(2) a")?.textContent }
    ])
}
```

## Error Handling

### Network Errors
```swift
public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidData
    case invalidResponse
    case authenticationRequired
    case authenticationFailed
    case parsingError(String)
    case postFailed
    case rateLimited
    case serverError(Int)
    case connectionError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidData:
            return "Invalid data received"
        case .invalidResponse:
            return "Invalid response"
        case .authenticationRequired:
            return "Authentication required"
        case .authenticationFailed:
            return "Authentication failed"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .postFailed:
            return "Failed to post"
        case .rateLimited:
            return "Rate limited"
        case .serverError(let code):
            return "Server error: \(code)"
        case .connectionError(let error):
            return "Connection error: \(error.localizedDescription)"
        }
    }
}
```

### Error Recovery
```swift
extension ForumsClient {
    private func performRequest<T>(
        _ request: URLRequest,
        maxRetries: Int = 3,
        parser: @escaping (Data) throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return try parser(data)
                case 401:
                    // Try to re-authenticate
                    if attempt < maxRetries - 1 {
                        try await reauthenticate()
                        continue
                    }
                    throw NetworkError.authenticationRequired
                case 429:
                    // Rate limited - exponential backoff
                    let delay = TimeInterval(pow(2.0, Double(attempt)))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                case 500...599:
                    throw NetworkError.serverError(httpResponse.statusCode)
                default:
                    throw NetworkError.invalidResponse
                }
            } catch {
                lastError = error
                
                // Exponential backoff for network errors
                if attempt < maxRetries - 1 {
                    let delay = TimeInterval(pow(2.0, Double(attempt)))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.connectionError(NSError(domain: "Unknown", code: 0, userInfo: nil))
    }
    
    private func reauthenticate() async throws {
        guard let username = UserDefaults.standard.string(forKey: "username"),
              let password = UserDefaults.standard.string(forKey: "password") else {
            throw NetworkError.authenticationRequired
        }
        
        let success = try await authenticate(username: username, password: password)
        if !success {
            throw NetworkError.authenticationFailed
        }
    }
}
```

## Caching Strategy

### Response Caching
```swift
class NetworkCache {
    private let cache = NSCache<NSString, CachedResponse>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NetworkCache")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func store(_ data: Data, for key: String, ttl: TimeInterval = 300) {
        let response = CachedResponse(data: data, timestamp: Date(), ttl: ttl)
        cache.setObject(response, forKey: key as NSString)
        
        // Also store to disk for persistence
        let fileURL = cacheDirectory.appendingPathComponent(key.md5)
        try? data.write(to: fileURL)
    }
    
    func retrieve(for key: String) -> Data? {
        // Check memory cache first
        if let cachedResponse = cache.object(forKey: key as NSString) {
            if Date().timeIntervalSince(cachedResponse.timestamp) < cachedResponse.ttl {
                return cachedResponse.data
            } else {
                cache.removeObject(forKey: key as NSString)
            }
        }
        
        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.md5)
        return try? Data(contentsOf: fileURL)
    }
}

private class CachedResponse {
    let data: Data
    let timestamp: Date
    let ttl: TimeInterval
    
    init(data: Data, timestamp: Date, ttl: TimeInterval) {
        self.data = data
        self.timestamp = timestamp
        self.ttl = ttl
    }
}
```

## Request/Response Logging

### Debug Logging
```swift
extension ForumsClient {
    private func logRequest(_ request: URLRequest) {
        #if DEBUG
        print("🌐 REQUEST: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "nil")")
        
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                print("📋 Header: \(key): \(value)")
            }
        }
        
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("📄 Body: \(bodyString)")
        }
        #endif
    }
    
    private func logResponse(_ response: URLResponse, data: Data) {
        #if DEBUG
        if let httpResponse = response as? HTTPURLResponse {
            print("🌐 RESPONSE: \(httpResponse.statusCode) \(httpResponse.url?.absoluteString ?? "nil")")
            
            for (key, value) in httpResponse.allHeaderFields {
                print("📋 Header: \(key): \(value)")
            }
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Response: \(responseString.prefix(500))...")
        }
        #endif
    }
}
```

## Testing

### Network Testing
```swift
class MockURLSession: URLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        
        return (mockData ?? Data(), mockResponse ?? URLResponse())
    }
}

// Test example
class ForumsClientTests: XCTestCase {
    func testLoadForums() async throws {
        // Given
        let mockSession = MockURLSession()
        let mockHTML = """
        <table class="forumlist">
            <tr class="forum">
                <td><a class="forum" href="forumdisplay.php?forumid=1">Test Forum</a></td>
            </tr>
        </table>
        """
        
        mockSession.mockData = mockHTML.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let client = ForumsClient(session: mockSession)
        
        // When
        let forums = try await client.loadForums()
        
        // Then
        XCTAssertEqual(forums.count, 1)
        XCTAssertEqual(forums[0].title, "Test Forum")
    }
}
```

## Best Practices

1. **Authentication Management**: Securely store and manage session cookies
2. **Error Handling**: Implement robust error handling and recovery
3. **Caching**: Use appropriate caching strategies for different content types
4. **Rate Limiting**: Respect server rate limits and implement backoff strategies
5. **Parsing**: Use defensive parsing with fallbacks for HTML structure changes
6. **Testing**: Mock network calls for reliable testing
7. **Logging**: Implement comprehensive logging for debugging
8. **Performance**: Optimize for low bandwidth and high latency connections