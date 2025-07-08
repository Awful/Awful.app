# HTML Scraping

## Overview

The HTML scraping system is responsible for parsing Something Awful's forum pages and extracting structured data. This system must handle HTML structure changes gracefully and provide robust error recovery.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       HTML Scraping System                     │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   HTMLReader    │  │   Scrapers      │  │   Parsers       │  │
│  │                 │  │                 │  │                 │  │
│  │ • DOM Parser    │  │ • Forums        │  │ • Post Content  │  │
│  │ • CSS Selectors │  │ • Threads       │  │ • User Info     │  │
│  │ • Text Extraction│ │ • Posts         │  │ • Dates         │  │
│  │ • Error Handling│  │ • Users         │  │ • URLs          │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Validation     │  │  Fallback Logic │  │  Data Models    │  │
│  │                 │  │                 │  │                 │  │
│  │ • Structure     │  │ • Multiple CSS  │  │ • Forum         │  │
│  │ • Data Quality  │  │ • Regex Backup  │  │ • Thread        │  │
│  │ • Completeness  │  │ • Error Recovery│  │ • Post          │  │
│  │ • Consistency   │  │ • Logging       │  │ • User          │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## HTMLReader Integration

### Core Implementation
```swift
import HTMLReader

class HTMLScraper {
    private let document: HTMLDocument
    
    init(html: String) throws {
        guard !html.isEmpty else {
            throw ScrapingError.emptyHTML
        }
        
        // Clean HTML to handle malformed content
        let cleanedHTML = html.replacingOccurrences(of: "&nbsp;", with: " ")
                             .replacingOccurrences(of: "\\u00A0", with: " ")
        
        self.document = HTMLDocument(string: cleanedHTML)
        
        // Validate basic document structure
        guard document.firstNode(matchingSelector: "html") != nil else {
            throw ScrapingError.invalidHTML
        }
    }
    
    func selectNodes(_ selector: String) -> [HTMLNode] {
        return document.nodes(matchingSelector: selector)
    }
    
    func selectFirst(_ selector: String) -> HTMLNode? {
        return document.firstNode(matchingSelector: selector)
    }
}
```

### Safe Node Access
```swift
extension HTMLNode {
    // Safe text content extraction
    var safeTextContent: String {
        return textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    // Safe attribute access
    func safeAttribute(_ name: String) -> String? {
        return self[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Check if node has content
    var hasContent: Bool {
        return !safeTextContent.isEmpty
    }
    
    // Safe HTML content
    var safeInnerHTML: String {
        return innerHTML?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
```

## Forum Page Scraping

### Forum List Extraction
```swift
class ForumsScraper: HTMLScraper {
    func extractForums() throws -> [ScrapedForum] {
        // Multiple selector strategies for robustness
        let forumSelectors = [
            "table.forumlist tr.forum",
            ".forum-table .forum-row",
            "tr[id^='forum']",
            ".forum-container .forum-item"
        ]
        
        var forumRows: [HTMLNode] = []
        
        for selector in forumSelectors {
            forumRows = selectNodes(selector)
            if !forumRows.isEmpty {
                break
            }
        }
        
        guard !forumRows.isEmpty else {
            throw ScrapingError.noForumsFound
        }
        
        return forumRows.compactMap { row in
            parseForumRow(row)
        }
    }
    
    private func parseForumRow(_ row: HTMLNode) -> ScrapedForum? {
        // Extract forum ID with multiple strategies
        guard let forumId = extractForumId(from: row) else {
            return nil
        }
        
        // Extract title with fallback selectors
        guard let title = extractForumTitle(from: row) else {
            return nil
        }
        
        let forum = ScrapedForum(
            id: forumId,
            title: title,
            description: extractForumDescription(from: row),
            category: extractForumCategory(from: row),
            hasUnreadThreads: checkUnreadStatus(in: row),
            index: extractForumIndex(from: row)
        )
        
        return forum
    }
    
    private func extractForumId(from row: HTMLNode) -> Int? {
        // Strategy 1: From forum link href
        if let link = row.firstNode(matchingSelector: "a.forum, .forum-link a"),
           let href = link.safeAttribute("href"),
           let id = extractIdFromURL(href, pattern: #"forumid=(\d+)"#) {
            return id
        }
        
        // Strategy 2: From data attribute
        if let idString = row.safeAttribute("data-forumid"),
           let id = Int(idString) {
            return id
        }
        
        // Strategy 3: From row ID
        if let rowId = row.safeAttribute("id"),
           let id = extractIdFromString(rowId, pattern: #"forum(\d+)"#) {
            return id
        }
        
        return nil
    }
    
    private func extractForumTitle(from row: HTMLNode) -> String? {
        let titleSelectors = [
            "a.forum",
            ".forum-title a",
            ".title a",
            "td:nth-child(2) a"
        ]
        
        for selector in titleSelectors {
            if let titleNode = row.firstNode(matchingSelector: selector),
               titleNode.hasContent {
                return titleNode.safeTextContent
            }
        }
        
        return nil
    }
}
```

### Thread List Extraction
```swift
class ThreadsScraper: HTMLScraper {
    func extractThreads() throws -> [ScrapedThread] {
        let threadSelectors = [
            "table.threadlist tr.thread",
            ".thread-table .thread-row",
            "tr[id^='thread']"
        ]
        
        var threadRows: [HTMLNode] = []
        
        for selector in threadSelectors {
            threadRows = selectNodes(selector)
            if !threadRows.isEmpty {
                break
            }
        }
        
        guard !threadRows.isEmpty else {
            throw ScrapingError.noThreadsFound
        }
        
        return threadRows.compactMap { row in
            parseThreadRow(row)
        }
    }
    
    private func parseThreadRow(_ row: HTMLNode) -> ScrapedThread? {
        guard let threadId = extractThreadId(from: row),
              let title = extractThreadTitle(from: row) else {
            return nil
        }
        
        let thread = ScrapedThread(
            id: threadId,
            title: title,
            author: extractThreadAuthor(from: row),
            authorId: extractThreadAuthorId(from: row),
            postCount: extractPostCount(from: row),
            lastPostDate: extractLastPostDate(from: row),
            isSticky: checkStickyStatus(in: row),
            isAnnouncement: checkAnnouncementStatus(in: row),
            isLocked: checkLockedStatus(in: row),
            hasUnreadPosts: checkUnreadStatus(in: row),
            rating: extractThreadRating(from: row)
        )
        
        return thread
    }
    
    private func extractThreadId(from row: HTMLNode) -> Int? {
        // Strategy 1: From thread title link
        if let link = row.firstNode(matchingSelector: "a.thread_title, .thread-title a"),
           let href = link.safeAttribute("href"),
           let id = extractIdFromURL(href, pattern: #"threadid=(\d+)"#) {
            return id
        }
        
        // Strategy 2: From goto link
        if let gotoLink = row.firstNode(matchingSelector: "a[href*='goto=lastpost']"),
           let href = gotoLink.safeAttribute("href"),
           let id = extractIdFromURL(href, pattern: #"threadid=(\d+)"#) {
            return id
        }
        
        // Strategy 3: From row data attribute
        if let idString = row.safeAttribute("data-threadid"),
           let id = Int(idString) {
            return id
        }
        
        return nil
    }
    
    private func extractPostCount(from row: HTMLNode) -> Int32 {
        let countSelectors = [
            ".replies",
            ".post-count",
            "td:nth-child(4)"
        ]
        
        for selector in countSelectors {
            if let countNode = row.firstNode(matchingSelector: selector),
               let countString = countNode.safeTextContent.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().nilIfEmpty,
               let count = Int32(countString) {
                return count
            }
        }
        
        return 0
    }
}
```

## Post Content Scraping

### Post Extraction
```swift
class PostsScraper: HTMLScraper {
    func extractPosts() throws -> [ScrapedPost] {
        let postSelectors = [
            "table.post",
            ".post-container",
            "div[id^='post']"
        ]
        
        var postNodes: [HTMLNode] = []
        
        for selector in postSelectors {
            postNodes = selectNodes(selector)
            if !postNodes.isEmpty {
                break
            }
        }
        
        guard !postNodes.isEmpty else {
            throw ScrapingError.noPostsFound
        }
        
        return postNodes.compactMap { node in
            parsePostNode(node)
        }
    }
    
    private func parsePostNode(_ node: HTMLNode) -> ScrapedPost? {
        guard let postId = extractPostId(from: node) else {
            return nil
        }
        
        let post = ScrapedPost(
            id: postId,
            content: extractPostContent(from: node),
            innerHTML: extractPostHTML(from: node),
            author: extractPostAuthor(from: node),
            authorId: extractPostAuthorId(from: node),
            postDate: extractPostDate(from: node),
            editDate: extractEditDate(from: node),
            index: extractPostIndex(from: node),
            attachments: extractAttachments(from: node)
        )
        
        return post
    }
    
    private func extractPostContent(from node: HTMLNode) -> String {
        let contentSelectors = [
            ".postbody",
            ".post-content",
            ".message"
        ]
        
        for selector in contentSelectors {
            if let contentNode = node.firstNode(matchingSelector: selector) {
                // Clean up content
                var content = contentNode.safeTextContent
                
                // Remove quoted text indicators
                content = content.replacingOccurrences(of: "Originally posted by", with: "")
                
                // Normalize whitespace
                content = content.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                
                return content
            }
        }
        
        return ""
    }
    
    private func extractPostHTML(from node: HTMLNode) -> String? {
        let contentSelectors = [
            ".postbody",
            ".post-content",
            ".message"
        ]
        
        for selector in contentSelectors {
            if let contentNode = node.firstNode(matchingSelector: selector) {
                var html = contentNode.safeInnerHTML
                
                // Clean up HTML
                html = cleanPostHTML(html)
                
                return html.isEmpty ? nil : html
            }
        }
        
        return nil
    }
    
    private func cleanPostHTML(_ html: String) -> String {
        var cleaned = html
        
        // Remove script tags
        cleaned = cleaned.replacingOccurrences(
            of: #"<script[^>]*>.*?</script>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove dangerous attributes
        cleaned = cleaned.replacingOccurrences(
            of: #"\son\w+\s*=\s*["\'][^"\']*["\']"#,
            with: "",
            options: .regularExpression
        )
        
        // Convert relative URLs to absolute
        cleaned = cleaned.replacingOccurrences(
            of: #"src\s*=\s*["\'](?!/|https?://)([^"\']+)["\']"#,
            with: "src=\"https://forums.somethingawful.com/$1\"",
            options: .regularExpression
        )
        
        return cleaned
    }
}
```

## Defensive Parsing Strategies

### Fallback Parser System
```swift
class DefensiveParser {
    private let strategies: [ParsingStrategy]
    
    init(strategies: [ParsingStrategy]) {
        self.strategies = strategies
    }
    
    func parse<T>(_ input: HTMLNode) throws -> T {
        var lastError: Error?
        
        for strategy in strategies {
            do {
                if let result: T = try strategy.parse(input) {
                    return result
                }
            } catch {
                lastError = error
                AwfulLogger.shared.log("Parsing strategy failed: \(error)", level: .warning)
            }
        }
        
        throw lastError ?? ScrapingError.allStrategiesFailed
    }
}

protocol ParsingStrategy {
    func parse<T>(_ input: HTMLNode) throws -> T?
}

// Example: Thread title parsing with multiple strategies
class ThreadTitleParsingStrategy: ParsingStrategy {
    func parse<T>(_ input: HTMLNode) throws -> T? {
        let selectors = [
            "a.thread_title",
            ".title a",
            "td:nth-child(2) a",
            ".thread-link"
        ]
        
        for selector in selectors {
            if let node = input.firstNode(matchingSelector: selector),
               node.hasContent {
                return node.safeTextContent as? T
            }
        }
        
        return nil
    }
}
```

### Pattern Extraction Utilities
```swift
extension HTMLScraper {
    func extractIdFromURL(_ url: String, pattern: String) -> Int? {
        return extractFromString(url, pattern: pattern)
    }
    
    func extractIdFromString(_ string: String, pattern: String) -> Int? {
        return extractFromString(string, pattern: pattern)
    }
    
    private func extractFromString(_ string: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let nsString = string as NSString
        let results = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        
        guard let match = results.first,
              match.numberOfRanges > 1 else {
            return nil
        }
        
        let range = match.range(at: 1)
        let idString = nsString.substring(with: range)
        return Int(idString)
    }
    
    func parseDate(from dateString: String) -> Date? {
        let formatters = [
            DateFormatter.saStandardFormatter,
            DateFormatter.saAlternativeFormatter,
            DateFormatter.iso8601Formatter
        ]
        
        let cleanedString = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for formatter in formatters {
            if let date = formatter.date(from: cleanedString) {
                return date
            }
        }
        
        return nil
    }
}

extension DateFormatter {
    static let saStandardFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy h:mm a"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    static let saAlternativeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
}
```

## Data Models

### Scraped Data Structures
```swift
// Intermediate data structures for parsed content
struct ScrapedForum {
    let id: Int
    let title: String
    let description: String?
    let category: String?
    let hasUnreadThreads: Bool
    let index: Int
}

struct ScrapedThread {
    let id: Int
    let title: String
    let author: String?
    let authorId: Int?
    let postCount: Int32
    let lastPostDate: Date?
    let isSticky: Bool
    let isAnnouncement: Bool
    let isLocked: Bool
    let hasUnreadPosts: Bool
    let rating: Double?
}

struct ScrapedPost {
    let id: Int
    let content: String
    let innerHTML: String?
    let author: String?
    let authorId: Int?
    let postDate: Date?
    let editDate: Date?
    let index: Int32
    let attachments: [ScrapedAttachment]
}

struct ScrapedAttachment {
    let id: Int
    let filename: String
    let url: String
    let thumbnailUrl: String?
    let fileSize: Int?
    let mimeType: String?
}
```

## Error Handling

### Scraping Errors
```swift
enum ScrapingError: Error, LocalizedError {
    case emptyHTML
    case invalidHTML
    case noForumsFound
    case noThreadsFound
    case noPostsFound
    case parsingFailed(String)
    case invalidStructure(String)
    case allStrategiesFailed
    
    var errorDescription: String? {
        switch self {
        case .emptyHTML:
            return "HTML content is empty"
        case .invalidHTML:
            return "HTML structure is invalid"
        case .noForumsFound:
            return "No forums found in HTML"
        case .noThreadsFound:
            return "No threads found in HTML"
        case .noPostsFound:
            return "No posts found in HTML"
        case .parsingFailed(let details):
            return "Parsing failed: \(details)"
        case .invalidStructure(let details):
            return "Invalid HTML structure: \(details)"
        case .allStrategiesFailed:
            return "All parsing strategies failed"
        }
    }
}
```

### Validation and Recovery
```swift
class ScrapingValidator {
    static func validateForum(_ forum: ScrapedForum) -> Bool {
        return forum.id > 0 && !forum.title.isEmpty
    }
    
    static func validateThread(_ thread: ScrapedThread) -> Bool {
        return thread.id > 0 && !thread.title.isEmpty
    }
    
    static func validatePost(_ post: ScrapedPost) -> Bool {
        return post.id > 0 && (!post.content.isEmpty || post.innerHTML != nil)
    }
    
    static func sanitizeContent(_ content: String) -> String {
        var sanitized = content
        
        // Remove potentially dangerous content
        sanitized = sanitized.replacingOccurrences(
            of: #"<script[^>]*>.*?</script>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Normalize whitespace
        sanitized = sanitized.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

## Testing

### Mock HTML Generation
```swift
class MockHTMLGenerator {
    static func generateForumListHTML() -> String {
        return """
        <table class="forumlist">
            <tr class="forum">
                <td><a class="forum" href="forumdisplay.php?forumid=1">General Discussion</a></td>
                <td class="description">General forum for discussions</td>
            </tr>
            <tr class="forum">
                <td><a class="forum" href="forumdisplay.php?forumid=2">YOSPOS</a></td>
                <td class="description">You Only Screw People Over Sometimes</td>
            </tr>
        </table>
        """
    }
    
    static func generateThreadListHTML() -> String {
        return """
        <table class="threadlist">
            <tr class="thread">
                <td><a class="thread_title" href="showthread.php?threadid=1">Test Thread</a></td>
                <td class="author">TestUser</td>
                <td class="replies">42</td>
                <td class="lastpost">
                    <div class="date">Jan 01, 2024 12:00 PM</div>
                </td>
            </tr>
        </table>
        """
    }
}

// Test example
class HTMLScrapingTests: XCTestCase {
    func testForumExtraction() throws {
        let html = MockHTMLGenerator.generateForumListHTML()
        let scraper = try ForumsScraper(html: html)
        
        let forums = try scraper.extractForums()
        
        XCTAssertEqual(forums.count, 2)
        XCTAssertEqual(forums[0].title, "General Discussion")
        XCTAssertEqual(forums[0].id, 1)
    }
}
```

## Best Practices

1. **Multiple Selector Strategies**: Always provide fallback CSS selectors
2. **Defensive Parsing**: Handle malformed HTML gracefully
3. **Data Validation**: Validate all extracted data before use
4. **Error Recovery**: Log failures but continue processing when possible
5. **Content Sanitization**: Clean user-generated content for security
6. **Performance**: Use efficient parsing strategies for large pages
7. **Testing**: Create comprehensive test cases with real HTML samples
8. **Monitoring**: Track parsing success rates and common failure patterns