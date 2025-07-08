# Forums Client

## Overview

The ForumsClient is the core networking component that handles all communication with Something Awful's forums. It manages authentication, request/response handling, HTML parsing, and data persistence.

## Architecture

### Class Structure
```swift
public class ForumsClient {
    public static let shared = ForumsClient()
    
    // MARK: - Properties
    private let session: URLSession
    private let baseURL = URL(string: "https://forums.somethingawful.com")!
    private let persistentContainer: NSPersistentContainer
    private var authenticationCookies: [HTTPCookie] = []
    
    // MARK: - Initialization
    private init() {
        // URLSession configuration
        let configuration = URLSessionConfiguration.default
        configuration.httpCookiePolicy = .always
        configuration.requestCachePolicy = .reloadIgnoringCacheData
        self.session = URLSession(configuration: configuration)
        
        // Core Data setup
        self.persistentContainer = PersistenceController.shared.persistentContainer
        
        // Load saved authentication
        loadAuthenticationCookies()
    }
}
```

## Authentication

### Login Process
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
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ForumsClientError.invalidResponse
            }
            
            let html = String(data: data, encoding: .utf8) ?? ""
            let isAuthenticated = validateAuthentication(html: html, response: httpResponse)
            
            if isAuthenticated {
                await MainActor.run {
                    UserDefaults.standard.set(username, forKey: "username")
                    self.storeAuthenticationCookies()
                }
            }
            
            return isAuthenticated
        } catch {
            throw ForumsClientError.authenticationFailed(error)
        }
    }
    
    private func validateAuthentication(html: String, response: HTTPURLResponse) -> Bool {
        // Check for error messages
        if html.contains("Invalid username or password") ||
           html.contains("You have entered an invalid username or password") {
            return false
        }
        
        // Check for authentication cookies
        if let cookies = HTTPCookieStorage.shared.cookies(for: baseURL) {
            let sessionCookies = cookies.filter { cookie in
                cookie.name.contains("session") || cookie.name.contains("userid")
            }
            
            if !sessionCookies.isEmpty {
                authenticationCookies = sessionCookies
                return true
            }
        }
        
        return false
    }
    
    private func storeAuthenticationCookies() {
        do {
            let cookieData = try NSKeyedArchiver.archivedData(withRootObject: authenticationCookies, requiringSecureCoding: false)
            UserDefaults.standard.set(cookieData, forKey: "authCookies")
        } catch {
            print("Failed to store authentication cookies: \(error)")
        }
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

### Session Management
```swift
extension ForumsClient {
    public var isAuthenticated: Bool {
        return !authenticationCookies.isEmpty && 
               authenticationCookies.allSatisfy { !$0.isExpired }
    }
    
    public func logout() {
        authenticationCookies.removeAll()
        UserDefaults.standard.removeObject(forKey: "authCookies")
        UserDefaults.standard.removeObject(forKey: "username")
        
        // Clear all cookies
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
    
    private func refreshAuthenticationIfNeeded() async throws {
        guard !isAuthenticated else { return }
        
        guard let username = UserDefaults.standard.string(forKey: "username"),
              let password = UserDefaults.standard.string(forKey: "password") else {
            throw ForumsClientError.authenticationRequired
        }
        
        let success = try await authenticate(username: username, password: password)
        if !success {
            throw ForumsClientError.authenticationExpired
        }
    }
}
```

## Data Loading Methods

### Forum Loading
```swift
extension ForumsClient {
    public func loadForums() async throws -> [Forum] {
        try await refreshAuthenticationIfNeeded()
        
        let url = baseURL.appendingPathComponent("index.php")
        let (data, _) = try await session.data(from: url)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ForumsClientError.invalidData
        }
        
        return try await parseAndSaveForums(html: html)
    }
    
    private func parseAndSaveForums(html: String) async throws -> [Forum] {
        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = persistentContainer.newBackgroundContext()
            
            backgroundContext.perform {
                do {
                    let forums = try self.parseForums(from: html, context: backgroundContext)
                    try backgroundContext.save()
                    
                    DispatchQueue.main.async {
                        continuation.resume(returning: forums)
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func parseForums(from html: String, context: NSManagedObjectContext) throws -> [Forum] {
        let document = HTMLDocument(string: html)
        
        guard let forumTable = document.firstNode(matchingSelector: "table.forumlist") else {
            throw ForumsClientError.parsingError("Forum table not found")
        }
        
        let forumRows = forumTable.nodes(matchingSelector: "tr.forum")
        
        return forumRows.compactMap { row -> Forum? in
            guard let titleLink = row.firstNode(matchingSelector: "a.forum"),
                  let title = titleLink.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let href = titleLink["href"],
                  let forumId = extractForumId(from: href) else {
                return nil
            }
            
            // Find or create forum
            let fetchRequest: NSFetchRequest<Forum> = Forum.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %d", forumId)
            
            let forum: Forum
            if let existingForum = try? context.fetch(fetchRequest).first {
                forum = existingForum
            } else {
                forum = Forum(context: context)
                forum.id = Int32(forumId)
            }
            
            // Update forum properties
            forum.title = title
            forum.lastModified = Date()
            
            // Parse additional metadata
            parseForumMetadata(from: row, into: forum)
            
            return forum
        }
    }
    
    private func parseForumMetadata(from row: HTMLNode, into forum: Forum) {
        // Description
        if let descriptionNode = row.firstNode(matchingSelector: ".description") {
            forum.subtitle = descriptionNode.textContent?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Category
        if let categoryNode = row.firstNode(matchingSelector: ".category") {
            let categoryName = categoryNode.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "General"
            forum.category = findOrCreateCategory(name: categoryName, context: forum.managedObjectContext!)
        }
        
        // Forum index for sorting
        if let indexAttribute = row["data-index"] {
            forum.index = Int32(indexAttribute) ?? 0
        }
    }
}
```

### Thread Loading
```swift
extension ForumsClient {
    public func loadThreads(for forum: Forum, page: Int = 1) async throws -> [Thread] {
        try await refreshAuthenticationIfNeeded()
        
        var components = URLComponents(url: baseURL.appendingPathComponent("forumdisplay.php"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "forumid", value: String(forum.id)),
            URLQueryItem(name: "pagenumber", value: String(page))
        ]
        
        let (data, _) = try await session.data(from: components.url!)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ForumsClientError.invalidData
        }
        
        return try await parseAndSaveThreads(html: html, forum: forum)
    }
    
    private func parseAndSaveThreads(html: String, forum: Forum) async throws -> [Thread] {
        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = persistentContainer.newBackgroundContext()
            
            backgroundContext.perform {
                do {
                    // Find forum in background context
                    let forumRequest: NSFetchRequest<Forum> = Forum.fetchRequest()
                    forumRequest.predicate = NSPredicate(format: "id == %d", forum.id)
                    
                    guard let backgroundForum = try backgroundContext.fetch(forumRequest).first else {
                        throw ForumsClientError.parsingError("Forum not found in background context")
                    }
                    
                    let threads = try self.parseThreads(from: html, forum: backgroundForum, context: backgroundContext)
                    try backgroundContext.save()
                    
                    DispatchQueue.main.async {
                        continuation.resume(returning: threads)
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func parseThreads(from html: String, forum: Forum, context: NSManagedObjectContext) throws -> [Thread] {
        let document = HTMLDocument(string: html)
        
        guard let threadTable = document.firstNode(matchingSelector: "table.threadlist") else {
            throw ForumsClientError.parsingError("Thread table not found")
        }
        
        let threadRows = threadTable.nodes(matchingSelector: "tr.thread")
        
        return threadRows.compactMap { row -> Thread? in
            guard let titleLink = row.firstNode(matchingSelector: "a.thread_title"),
                  let title = titleLink.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let href = titleLink["href"],
                  let threadId = extractThreadId(from: href) else {
                return nil
            }
            
            // Find or create thread
            let fetchRequest: NSFetchRequest<Thread> = Thread.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %d", threadId)
            
            let thread: Thread
            if let existingThread = try? context.fetch(fetchRequest).first {
                thread = existingThread
            } else {
                thread = Thread(context: context)
                thread.id = Int32(threadId)
                thread.forum = forum
            }
            
            // Update thread properties
            thread.title = title
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
        
        // Thread state indicators
        thread.hasUnreadPosts = row.hasClass("unread")
        thread.isSticky = row.hasClass("sticky")
        thread.isAnnouncement = row.hasClass("announcement")
        thread.isLocked = row.hasClass("locked")
        
        // Rating
        if let ratingNode = row.firstNode(matchingSelector: ".rating"),
           let ratingText = ratingNode.textContent {
            thread.rating = Double(ratingText) ?? 0.0
        }
    }
}
```

### Post Loading
```swift
extension ForumsClient {
    public func loadPosts(for thread: Thread, page: Int = 1) async throws -> [Post] {
        try await refreshAuthenticationIfNeeded()
        
        var components = URLComponents(url: baseURL.appendingPathComponent("showthread.php"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "threadid", value: String(thread.id)),
            URLQueryItem(name: "pagenumber", value: String(page))
        ]
        
        let (data, _) = try await session.data(from: components.url!)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ForumsClientError.invalidData
        }
        
        return try await parseAndSavePosts(html: html, thread: thread)
    }
    
    private func parseAndSavePosts(html: String, thread: Thread) async throws -> [Post] {
        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = persistentContainer.newBackgroundContext()
            
            backgroundContext.perform {
                do {
                    // Find thread in background context
                    let threadRequest: NSFetchRequest<Thread> = Thread.fetchRequest()
                    threadRequest.predicate = NSPredicate(format: "id == %d", thread.id)
                    
                    guard let backgroundThread = try backgroundContext.fetch(threadRequest).first else {
                        throw ForumsClientError.parsingError("Thread not found in background context")
                    }
                    
                    let posts = try self.parsePosts(from: html, thread: backgroundThread, context: backgroundContext)
                    try backgroundContext.save()
                    
                    DispatchQueue.main.async {
                        continuation.resume(returning: posts)
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func parsePosts(from html: String, thread: Thread, context: NSManagedObjectContext) throws -> [Post] {
        let document = HTMLDocument(string: html)
        
        let postNodes = document.nodes(matchingSelector: "table.post")
        
        return postNodes.compactMap { postNode -> Post? in
            guard let postIdAttribute = postNode["id"],
                  let postId = extractPostId(from: postIdAttribute) else {
                return nil
            }
            
            // Find or create post
            let fetchRequest: NSFetchRequest<Post> = Post.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %d", postId)
            
            let post: Post
            if let existingPost = try? context.fetch(fetchRequest).first {
                post = existingPost
            } else {
                post = Post(context: context)
                post.id = Int32(postId)
                post.thread = thread
            }
            
            // Parse post content
            parsePostContent(from: postNode, into: post)
            
            return post
        }
    }
    
    private func parsePostContent(from postNode: HTMLNode, into post: Post) {
        // Author information
        if let authorNode = postNode.firstNode(matchingSelector: ".userid") {
            post.author = authorNode.textContent?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let userIdAttribute = authorNode["data-userid"] {
                post.authorID = Int32(userIdAttribute) ?? 0
            }
        }
        
        // Post date
        if let dateNode = postNode.firstNode(matchingSelector: ".postdate") {
            post.postDate = parseDate(from: dateNode.textContent ?? "")
        }
        
        // Post content
        if let contentNode = postNode.firstNode(matchingSelector: ".postbody") {
            post.content = contentNode.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            post.innerHTML = contentNode.innerHTML
        }
        
        // Post index
        if let indexAttribute = postNode["data-idx"] {
            post.index = Int32(indexAttribute) ?? 0
        }
    }
}
```

## Posting and Interaction

### Reply Posting
```swift
extension ForumsClient {
    public func postReply(to thread: Thread, content: String) async throws -> Post {
        try await refreshAuthenticationIfNeeded()
        
        // Get form token first
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
            throw ForumsClientError.postFailed
        }
        
        let html = String(data: data, encoding: .utf8) ?? ""
        
        // Check for posting errors
        if html.contains("You must wait") {
            throw ForumsClientError.rateLimited
        }
        
        if html.contains("Your post was too short") {
            throw ForumsClientError.postTooShort
        }
        
        // Parse the new post from response
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
    
    private func parseFormToken(from html: String) throws -> String {
        let document = HTMLDocument(string: html)
        
        guard let formTokenInput = document.firstNode(matchingSelector: "input[name='formkey']"),
              let formToken = formTokenInput["value"] else {
            throw ForumsClientError.parsingError("Form token not found")
        }
        
        return formToken
    }
}
```

## Error Handling

### Error Types
```swift
public enum ForumsClientError: Error, LocalizedError {
    case invalidURL
    case invalidData
    case invalidResponse
    case authenticationRequired
    case authenticationFailed(Error)
    case authenticationExpired
    case parsingError(String)
    case postFailed
    case postTooShort
    case rateLimited
    case serverError(Int)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidData:
            return "Invalid data received from server"
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationRequired:
            return "Authentication required"
        case .authenticationFailed(let error):
            return "Authentication failed: \(error.localizedDescription)"
        case .authenticationExpired:
            return "Authentication expired"
        case .parsingError(let message):
            return "Error parsing response: \(message)"
        case .postFailed:
            return "Failed to post message"
        case .postTooShort:
            return "Post content is too short"
        case .rateLimited:
            return "Rate limited. Please wait before posting again."
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
```

### Retry Logic
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
                    throw ForumsClientError.invalidResponse
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return try parser(data)
                case 401:
                    // Try to re-authenticate
                    if attempt < maxRetries - 1 {
                        try await refreshAuthenticationIfNeeded()
                        continue
                    }
                    throw ForumsClientError.authenticationRequired
                case 429:
                    // Rate limited - exponential backoff
                    let delay = TimeInterval(pow(2.0, Double(attempt)) * 2)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                case 500...599:
                    throw ForumsClientError.serverError(httpResponse.statusCode)
                default:
                    throw ForumsClientError.invalidResponse
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
        
        throw lastError ?? ForumsClientError.networkError(NSError(domain: "Unknown", code: 0, userInfo: nil))
    }
}
```

## Utility Methods

### HTML Parsing Utilities
```swift
extension ForumsClient {
    private func extractForumId(from href: String) -> Int? {
        let pattern = #"forumid=(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = href as NSString
        let results = regex?.matches(in: href, range: NSRange(location: 0, length: nsString.length))
        
        if let match = results?.first {
            let range = match.range(at: 1)
            let idString = nsString.substring(with: range)
            return Int(idString)
        }
        
        return nil
    }
    
    private func extractThreadId(from href: String) -> Int? {
        let pattern = #"threadid=(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = href as NSString
        let results = regex?.matches(in: href, range: NSRange(location: 0, length: nsString.length))
        
        if let match = results?.first {
            let range = match.range(at: 1)
            let idString = nsString.substring(with: range)
            return Int(idString)
        }
        
        return nil
    }
    
    private func extractPostId(from id: String) -> Int? {
        let pattern = #"post(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = id as NSString
        let results = regex?.matches(in: id, range: NSRange(location: 0, length: nsString.length))
        
        if let match = results?.first {
            let range = match.range(at: 1)
            let idString = nsString.substring(with: range)
            return Int(idString)
        }
        
        return nil
    }
    
    private func parseDate(from dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy h:mm a"
        return formatter.date(from: dateString.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
```

## Usage Examples

### Basic Usage
```swift
// Authentication
let client = ForumsClient.shared
let success = try await client.authenticate(username: "user", password: "pass")

// Load forums
let forums = try await client.loadForums()

// Load threads for a forum
let threads = try await client.loadThreads(for: forums[0])

// Load posts for a thread
let posts = try await client.loadPosts(for: threads[0])

// Post a reply
let newPost = try await client.postReply(to: threads[0], content: "Hello world!")
```

### Error Handling
```swift
do {
    let forums = try await ForumsClient.shared.loadForums()
    // Handle success
} catch ForumsClientError.authenticationRequired {
    // Show login screen
} catch ForumsClientError.networkError(let error) {
    // Show network error message
} catch {
    // Handle other errors
}
```

## Testing

### Mock Client
```swift
class MockForumsClient: ForumsClient {
    var shouldFail = false
    var mockForums: [Forum] = []
    var mockThreads: [Thread] = []
    var mockPosts: [Post] = []
    
    override func loadForums() async throws -> [Forum] {
        if shouldFail {
            throw ForumsClientError.networkError(NSError(domain: "Test", code: 0, userInfo: nil))
        }
        return mockForums
    }
    
    override func loadThreads(for forum: Forum, page: Int = 1) async throws -> [Thread] {
        if shouldFail {
            throw ForumsClientError.networkError(NSError(domain: "Test", code: 0, userInfo: nil))
        }
        return mockThreads
    }
}
```

## Best Practices

1. **Authentication Management**: Always check authentication before making requests
2. **Error Handling**: Implement comprehensive error handling with appropriate retry logic
3. **Background Processing**: Use background contexts for Core Data operations
4. **Rate Limiting**: Respect server rate limits and implement backoff strategies
5. **Caching**: Cache responses appropriately to reduce server load
6. **Parsing**: Use defensive parsing with fallbacks for HTML structure changes
7. **Testing**: Use dependency injection to enable proper unit testing