# Network Debugging

## Overview

This document covers debugging network issues, API problems, and HTML scraping failures in Awful.app.

## Network Infrastructure

### ForumsClient Architecture
**Core Components**:
- `ForumsClient.shared` - Main API client
- `URLSession` - Network session management
- `HTMLReader` - HTML parsing and scraping
- Custom scrapers for different page types

**Key Classes**:
- `ForumsClient` - Main networking interface
- `ThreadScraper` - Thread page parsing
- `PostScraper` - Individual post parsing
- `ForumScraper` - Forum listing parsing

### Network Configuration
```swift
// Default configuration
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30.0
configuration.timeoutIntervalForResource = 60.0
configuration.httpCookieStorage = HTTPCookieStorage.shared
```

## Common Network Issues

### Connection Failures
**Problem**: Cannot connect to Something Awful servers
**Error Messages**:
- "The request timed out"
- "Could not connect to the server"
- "Network connection lost"

**Debugging Steps**:
1. Check server status:
   ```bash
   curl -I https://forums.somethingawful.com/
   ```

2. Test connectivity:
   ```bash
   ping forums.somethingawful.com
   nslookup forums.somethingawful.com
   ```

3. Check proxy settings:
   ```swift
   let proxyDict = CFNetworkCopySystemProxySettings()
   print("Proxy settings: \(proxyDict)")
   ```

### SSL/TLS Issues
**Problem**: SSL certificate or TLS connection failures
**Solutions**:
1. Check certificate validity:
   ```bash
   openssl s_client -connect forums.somethingawful.com:443
   ```

2. Enable TLS debugging:
   ```swift
   setenv("CFNETWORK_DIAGNOSTICS", "3", 1)
   ```

3. Verify TLS configuration:
   ```swift
   let session = URLSession(configuration: .default)
   session.configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
   ```

### Authentication Problems
**Problem**: Login failures or session issues
**Common Causes**:
- Invalid credentials
- Expired session cookies
- Two-factor authentication
- IP blocking

**Solutions**:
1. Clear cookies:
   ```swift
   let cookieStorage = HTTPCookieStorage.shared
   cookieStorage.removeCookies(since: Date.distantPast)
   ```

2. Check authentication state:
   ```swift
   func isAuthenticated() -> Bool {
       // Check for required cookies
       let cookies = HTTPCookieStorage.shared.cookies(for: baseURL)
       return cookies?.contains { $0.name == "bbuserid" } ?? false
   }
   ```

3. Monitor authentication requests:
   ```swift
   // Log authentication attempts
   print("Login attempt with username: \(username)")
   ```

## API Debugging

### Request Logging
**Enable Network Logging**:
```swift
// Enable detailed network logging
UserDefaults.standard.set(true, forKey: "AwfulNetworkDebug")

// Custom request logging
func logRequest(_ request: URLRequest) {
    print("🌐 Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
    print("Headers: \(request.allHTTPHeaderFields ?? [:])")
    if let body = request.httpBody {
        print("Body: \(String(data: body, encoding: .utf8) ?? "Binary data")")
    }
}
```

### Response Analysis
**Debugging Responses**:
```swift
func analyzeResponse(_ response: URLResponse?, data: Data?, error: Error?) {
    if let error = error {
        print("❌ Network Error: \(error)")
        return
    }
    
    guard let httpResponse = response as? HTTPURLResponse else {
        print("❌ Invalid response type")
        return
    }
    
    print("📊 Status Code: \(httpResponse.statusCode)")
    print("📋 Headers: \(httpResponse.allHeaderFields)")
    
    if let data = data {
        print("📦 Response Size: \(data.count) bytes")
        if let string = String(data: data, encoding: .utf8) {
            print("📄 Response: \(string.prefix(500))...")
        }
    }
}
```

### Common HTTP Status Codes
**Success Codes**:
- 200 OK - Request successful
- 302 Found - Redirect (common for SA)

**Error Codes**:
- 403 Forbidden - Authentication required or IP blocked
- 404 Not Found - Page doesn't exist
- 500 Internal Server Error - Server-side issue
- 503 Service Unavailable - Server maintenance

## HTML Scraping Issues

### Parsing Failures
**Problem**: HTML parsing returns unexpected results
**Common Causes**:
- Something Awful HTML structure changes
- Malformed HTML
- Missing elements
- Encoding issues

**Debugging**:
1. Log raw HTML:
   ```swift
   func debugHTML(_ html: String) {
       print("📝 Raw HTML length: \(html.count)")
       print("📝 HTML preview: \(html.prefix(1000))")
       
       // Save to file for inspection
       let url = FileManager.default.temporaryDirectory.appendingPathComponent("debug.html")
       try? html.write(to: url, atomically: true, encoding: .utf8)
       print("📁 Saved debug HTML to: \(url.path)")
   }
   ```

2. Test CSS selectors:
   ```swift
   func testSelector(_ selector: String, in document: HTMLDocument) {
       let nodes = document.nodes(matchingSelector: selector)
       print("🔍 Selector '\(selector)' found \(nodes.count) nodes")
       for (index, node) in nodes.enumerated() {
           print("  [\(index)]: \(node.textContent?.prefix(50) ?? "No text")")
       }
   }
   ```

### Scraper Debugging
**Thread Scraper Issues**:
```swift
// Debug thread scraping
func debugThreadScraping(html: String) {
    let document = HTMLDocument(string: html)
    
    // Check for posts
    let posts = document.nodes(matchingSelector: "table.post")
    print("Found \(posts.count) posts")
    
    // Check for thread title
    let title = document.firstNode(matchingSelector: "title")?.textContent
    print("Thread title: \(title ?? "Not found")")
    
    // Check for pagination
    let pages = document.nodes(matchingSelector: ".pages a")
    print("Found \(pages.count) page links")
}
```

**Post Scraper Issues**:
```swift
// Debug post content extraction
func debugPostContent(postNode: HTMLNode) {
    // Check post ID
    let postID = postNode.attributes["id"]
    print("Post ID: \(postID ?? "Not found")")
    
    // Check post content
    let content = postNode.firstNode(matchingSelector: ".postbody")?.innerHTML
    print("Post content length: \(content?.count ?? 0)")
    
    // Check author
    let author = postNode.firstNode(matchingSelector: ".author")?.textContent
    print("Author: \(author ?? "Not found")")
}
```

### Content Validation
**Validate Scraped Data**:
```swift
func validateScrapedData(_ data: ScrapedData) -> Bool {
    // Check required fields
    guard !data.title.isEmpty else {
        print("❌ Missing title")
        return false
    }
    
    guard !data.posts.isEmpty else {
        print("❌ No posts found")
        return false
    }
    
    // Validate each post
    for post in data.posts {
        guard !post.content.isEmpty else {
            print("❌ Empty post content")
            return false
        }
    }
    
    return true
}
```

## Specific Debugging Scenarios

### Login Process Debugging
**Problem**: Login fails or doesn't persist
**Debug Steps**:
1. Monitor login request:
   ```swift
   func debugLogin(username: String, password: String) {
       print("🔐 Starting login for user: \(username)")
       
       // Check initial cookies
       let initialCookies = HTTPCookieStorage.shared.cookies(for: loginURL)
       print("Initial cookies: \(initialCookies?.count ?? 0)")
       
       // Perform login
       login(username: username, password: password) { result in
           switch result {
           case .success:
               let finalCookies = HTTPCookieStorage.shared.cookies(for: self.baseURL)
               print("✅ Login successful, final cookies: \(finalCookies?.count ?? 0)")
               self.logCookies(finalCookies)
           case .failure(let error):
               print("❌ Login failed: \(error)")
           }
       }
   }
   ```

2. Analyze cookies:
   ```swift
   func logCookies(_ cookies: [HTTPCookie]?) {
       guard let cookies = cookies else { return }
       for cookie in cookies {
           print("🍪 \(cookie.name): \(cookie.value)")
           print("   Domain: \(cookie.domain), Path: \(cookie.path)")
           print("   Secure: \(cookie.isSecure), HttpOnly: \(cookie.isHTTPOnly)")
       }
   }
   ```

### Thread Loading Issues
**Problem**: Threads don't load or display incorrectly
**Debug Steps**:
1. Monitor thread request:
   ```swift
   func debugThreadLoading(threadID: String) {
       print("📱 Loading thread: \(threadID)")
       
       let url = threadURL(for: threadID)
       print("URL: \(url)")
       
       loadThread(threadID: threadID) { result in
           switch result {
           case .success(let thread):
               print("✅ Thread loaded: \(thread.title)")
               print("Posts: \(thread.posts.count)")
           case .failure(let error):
               print("❌ Thread loading failed: \(error)")
           }
       }
   }
   ```

2. Validate thread data:
   ```swift
   func validateThread(_ thread: Thread) {
       print("Thread validation:")
       print("  Title: \(thread.title.isEmpty ? "❌ Empty" : "✅ Present")")
       print("  Posts: \(thread.posts.isEmpty ? "❌ None" : "✅ \(thread.posts.count)")")
       print("  Author: \(thread.author?.isEmpty ?? true ? "❌ Missing" : "✅ Present")")
   }
   ```

### Image Loading Problems
**Problem**: Images don't load or display
**Debug Steps**:
1. Check image URLs:
   ```swift
   func debugImageLoading(imageURL: URL) {
       print("🖼️ Loading image: \(imageURL)")
       
       URLSession.shared.dataTask(with: imageURL) { data, response, error in
           if let error = error {
               print("❌ Image loading failed: \(error)")
               return
           }
           
           guard let httpResponse = response as? HTTPURLResponse else {
               print("❌ Invalid response")
               return
           }
           
           print("📊 Image response status: \(httpResponse.statusCode)")
           print("📦 Image data size: \(data?.count ?? 0) bytes")
           
           if let mimeType = httpResponse.mimeType {
               print("📄 MIME type: \(mimeType)")
           }
       }.resume()
   }
   ```

2. Validate image cache:
   ```swift
   func debugImageCache() {
       let cache = URLCache.shared
       print("📦 Cache stats:")
       print("  Current disk usage: \(cache.currentDiskUsage)")
       print("  Disk capacity: \(cache.diskCapacity)")
       print("  Current memory usage: \(cache.currentMemoryUsage)")
       print("  Memory capacity: \(cache.memoryCapacity)")
   }
   ```

## Advanced Debugging Techniques

### Network Traffic Analysis
**Using Charles Proxy**:
1. Configure proxy in iOS Simulator
2. Install Charles certificate
3. Monitor HTTPS traffic
4. Analyze request/response patterns

**Using Wireshark**:
1. Capture network traffic
2. Filter by host (forums.somethingawful.com)
3. Analyze packet contents
4. Identify connection issues

### Custom Network Interceptor
```swift
class NetworkInterceptor: URLProtocol {
    override func canInit(with request: URLRequest) -> Bool {
        // Only intercept SA requests
        return request.url?.host?.contains("somethingawful.com") ?? false
    }
    
    override func startLoading() {
        // Log request
        print("🔍 Intercepted request: \(request.url?.absoluteString ?? "")")
        
        // Proceed with normal request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Log response
            if let error = error {
                print("❌ Request failed: \(error)")
            } else {
                print("✅ Request succeeded")
            }
            
            // Forward response
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
            } else {
                if let response = response {
                    self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                if let data = data {
                    self.client?.urlProtocol(self, didLoad: data)
                }
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
        task.resume()
    }
    
    override func stopLoading() {
        // Cleanup
    }
}

// Register the interceptor
URLProtocol.registerClass(NetworkInterceptor.self)
```

### Performance Monitoring
**Network Performance Metrics**:
```swift
func monitorNetworkPerformance() {
    let startTime = CFAbsoluteTimeGetCurrent()
    
    performNetworkRequest { result in
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("⏱️ Network request duration: \(duration)s")
        
        switch result {
        case .success(let data):
            let throughput = Double(data.count) / duration
            print("📊 Throughput: \(throughput) bytes/sec")
        case .failure(let error):
            print("❌ Request failed after \(duration)s: \(error)")
        }
    }
}
```

## Diagnostic Tools

### Console Commands
```bash
# Monitor network activity
sudo tcpdump -i en0 host forums.somethingawful.com

# Check DNS resolution
nslookup forums.somethingawful.com

# Test connectivity
telnet forums.somethingawful.com 80

# Check SSL certificate
openssl s_client -connect forums.somethingawful.com:443 -servername forums.somethingawful.com
```

### Xcode Network Debugging
1. **Network Link Conditioner**:
   - Simulate poor network conditions
   - Test with different connection types
   - Verify timeout handling

2. **Instruments**:
   - Network activity template
   - HTTP traffic monitoring
   - Response time analysis

### Third-Party Tools
1. **Proxyman**: macOS network debugging proxy
2. **Charles**: Cross-platform HTTP proxy
3. **Postman**: API testing and debugging
4. **curl**: Command-line HTTP client

## Error Handling Best Practices

### Robust Error Handling
```swift
func handleNetworkError(_ error: Error) {
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet:
            showOfflineMessage()
        case .timedOut:
            showTimeoutMessage()
        case .cannotFindHost:
            showServerUnavailableMessage()
        default:
            showGenericNetworkError()
        }
    } else {
        showGenericError(error)
    }
}
```

### Retry Logic
```swift
func performRequestWithRetry(maxRetries: Int = 3, delay: TimeInterval = 1.0) {
    var attempts = 0
    
    func attemptRequest() {
        attempts += 1
        
        performRequest { result in
            switch result {
            case .success:
                // Success, nothing more to do
                break
            case .failure(let error):
                if attempts < maxRetries && shouldRetry(error) {
                    print("Retrying request (attempt \(attempts + 1))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        attemptRequest()
                    }
                } else {
                    // Max retries reached or non-retryable error
                    handleFinalError(error)
                }
            }
        }
    }
    
    attemptRequest()
}
```

## Testing Network Code

### Unit Testing Network Requests
```swift
class NetworkTests: XCTestCase {
    func testSuccessfulRequest() {
        let expectation = XCTestExpectation(description: "Network request")
        
        ForumsClient.shared.loadThread(threadID: "123") { result in
            switch result {
            case .success(let thread):
                XCTAssertFalse(thread.title.isEmpty)
                XCTAssertFalse(thread.posts.isEmpty)
            case .failure(let error):
                XCTFail("Request failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
}
```

### Mock Network Responses
```swift
class MockURLProtocol: URLProtocol {
    static var mockData: Data?
    static var mockResponse: URLResponse?
    static var mockError: Error?
    
    override func startLoading() {
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            if let response = MockURLProtocol.mockResponse {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = MockURLProtocol.mockData {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
```

## Resolution Strategies

### Systematic Debugging Process
1. **Isolate the Problem**:
   - Reproduce consistently
   - Test with minimal cases
   - Identify specific failing requests

2. **Gather Information**:
   - Enable debug logging
   - Capture network traffic
   - Analyze error messages

3. **Test Hypotheses**:
   - Try different approaches
   - Test edge cases
   - Verify assumptions

4. **Implement Solutions**:
   - Add error handling
   - Implement retry logic
   - Update parsing logic

### Communication with Backend
1. **Document Issues**:
   - Specific URLs failing
   - Error patterns
   - Reproduction steps

2. **Coordinate Changes**:
   - API modifications
   - HTML structure changes
   - Server configuration updates

3. **Test Solutions**:
   - Verify fixes work
   - Test edge cases
   - Monitor production behavior