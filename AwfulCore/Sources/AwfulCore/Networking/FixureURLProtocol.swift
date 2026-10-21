//  FixureURLProtocol.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#if DEBUG

import Foundation
import os
import UniformTypeIdentifiers

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FixtureURLProtocol")

/**
 A custom URL protocol that intercepts certain Forums requests and loads fixture data in their place.
 
 This protocol is intentionally difficult to use in an effort to avoid ever shipping this protocol enabled to actual users (e.g. via the App Store). It is wrapped in an `#if DEBUG … #endif`, it requires futzing with target memberships, and it requires adding code somewhere in the app itself to actually do anything. Please do not commit any of these changes to the git repository!
 
 All that said, here's how you might use this thing:
 
 1. Go to Awful's AppDelegate.swift and find the application(_:willFinishLaunchingWithOptions:) method.
 2. Add a line pretty early on that resembles:
 
     FixtureURLProtocol.enabledFixtures = [.announcement, .forum]
 3. In Xcode's Project navigator, go find the Core/Tests/Fixtures folder reference and add it to the Core target.
 4. Build and run.
 
 This will intercept any requests to `forumdisplay.php` (i.e. to list the forums or the threads in a forum) and to `announcement.php` (i.e. to list the current announcements) and instead load the test fixture data in its place.
 
 Note that this URL protocol will do nothing in a WKWebView, which disallows custom futzing with http and https schemes.

 ## Scripted threads

 Independent of `enabledFixtures`, a ``ScriptedThread`` installed in ``scriptedThreads`` stands in for one whole thread: each page's `showthread.php` HTML, plus which page each post is on so `goto=post` requests redirect the way the Forums do (which is how `ForumsClient.locatePost` finds a post's page). While any scripted thread is installed, the other Forums pages a posts page load touches in passing (forum lists, member info, bookmarks) answer with an empty 200 so nothing reaches the network. This is what the quote-jump test harness in App/Tests/QuoteJump drives `PostsPageViewController` with. Every scripted request is appended to ``requestLog`` so tests can assert on what was asked for.
 */
public final class FixtureURLProtocol: URLProtocol {
    
    /**
     Any fixtures added here will be loaded, causing relevant requests to be intercepted. Initially the set of enabled fixtures is empty, at which point this URL protocol does nothing.
     */
    public static var enabledFixtures: Set<Fixture> = []

    /// A whole thread's worth of `showthread.php` pages, served in place of the Forums. See ``scriptedThreads``.
    public struct ScriptedThread {
        public var threadID: String

        /// Page number to the full `showthread.php` HTML for that page, UTF-8 encoded.
        public var pages: [Int: Data]

        /// Post ID to the page it sits on, for answering `goto=post&postid=…` with the same redirect the Forums send.
        public var postPages: [String: Int]

        /// Where `goto=lastpost` redirects.
        public var lastPage: Int

        /// Where `goto=newpost` redirects.
        public var firstUnreadPage: Int

        public init(threadID: String, pages: [Int: Data], postPages: [String: Int], lastPage: Int, firstUnreadPage: Int) {
            self.threadID = threadID
            self.pages = pages
            self.postPages = postPages
            self.lastPage = lastPage
            self.firstUnreadPage = firstUnreadPage
        }
    }

    /// Scripted threads keyed by thread ID. While this is non-empty, Forums requests for `showthread.php` and the pages listed in ``scriptedPathPrefixes`` are answered here (see the class documentation); when it is empty, only ``enabledFixtures`` applies.
    public static var scriptedThreads: [String: ScriptedThread] {
        get { scriptingLock.withLock { _scriptedThreads } }
        set { scriptingLock.withLock { _scriptedThreads = newValue } }
    }

    /// Every request answered in scripted mode, in order. Tests assert on these, e.g. that a `goto=post` request carried `perpage=40`.
    public static var requestLog: [URL] {
        scriptingLock.withLock { _requestLog }
    }

    /// Forgets all scripted threads and the request log.
    public static func resetScripting() {
        scriptingLock.withLock {
            _scriptedThreads = [:]
            _requestLog = []
        }
    }

    /// Forums paths answered with an empty 200 while a scripted thread is installed, so stray requests during a posts page load (forum lists for the breadcrumbs, member info, bookmarks) never hit the network. `showthread.php` is handled separately.
    static let scriptedPathPrefixes = ["/forumdisplay.php", "/member.php", "/announcement.php", "/bookmarkthreads.php", "/usercp.php", "/index.php"]

    private static let scriptingLock = NSLock()
    nonisolated(unsafe) private static var _scriptedThreads: [String: ScriptedThread] = [:]
    nonisolated(unsafe) private static var _requestLog: [URL] = []

    private static func logScriptedRequest(_ url: URL) {
        scriptingLock.withLock { _requestLog.append(url) }
    }

    /// The request's URL when a scripted thread is installed and the request is one scripting answers; nil otherwise.
    private static func scriptedURL(for request: URLRequest) -> URL? {
        guard !scriptedThreads.isEmpty, let url = request.url else { return nil }
        let isScriptedPath = url.path.hasPrefix("/showthread.php") || scriptedPathPrefixes.contains(where: { url.path.hasPrefix($0) })
        return isScriptedPath ? url : nil
    }

    public enum SimulatedCloudflareChallenge {
        case off

        /// Every Forums request gets a synthetic challenge until the stand-in page's Verify link is followed, then none do. This is how real clearance behaves: zone-wide, so the launch burst and later navigation all recover from a single sheet.
        case untilVerified

        /// Every Forums request gets a synthetic challenge, verified or not, which exercises the give-up path (the retry is challenged too, so the request fails with `ServerError.cloudflareChallenge`).
        case always
    }

    /**
     Answers Forums requests with a synthetic Cloudflare challenge (a 403 carrying `cf-mitigated: challenge`).

     Independent of `enabledFixtures` and needs no fixture files, so the setup is one line in `AppDelegate.application(_:willFinishLaunchingWithOptions:)`:

         FixtureURLProtocol.simulatedCloudflareChallenge = .untilVerified

     The challenge page that `CloudflareChallengeViewController` shows can't be intercepted here (WebKit ignores custom URL protocols), so it recognises ``simulatedCloudflareRayID``, shows a stand-in page instead, and sets ``simulatedCloudflareChallengeWasVerified`` when its Verify link is followed.
     */
    public static var simulatedCloudflareChallenge: SimulatedCloudflareChallenge = .off

    /// Set by `CloudflareChallengeViewController` once a simulated challenge is verified. Reset it to see the sheet again without relaunching.
    public static var simulatedCloudflareChallengeWasVerified = false

    /// The `cf-ray` value on simulated challenges.
    public static let simulatedCloudflareRayID = "simulated-DEBUG"

    private static var shouldSimulateChallenge: Bool {
        switch simulatedCloudflareChallenge {
        case .off: false
        case .untilVerified: !simulatedCloudflareChallengeWasVerified
        case .always: true
        }
    }

    public enum SimulatedForumsOutage {
        case off

        /// Every Forums request gets a 302 to ``simulatedOutageStatusPageURL``, which is what the Forums do when they're down for maintenance.
        case redirectToStatusPage

        /// Every Forums request gets the Forums' own "Database Unavailable" page, a 503 served at the request's URL.
        case databaseUnavailable
    }

    /**
     Answers every Forums request the way the Forums do when they're down.

     Independent of `enabledFixtures` and needs no fixture files, so the setup is one line in `AppDelegate.application(_:willFinishLaunchingWithOptions:)`:

         FixtureURLProtocol.simulatedForumsOutage = .redirectToStatusPage

     `ForumsStatusPageViewController` loads the status page in a web view, which this protocol can't intercept, so the real page shows (for `.databaseUnavailable` that's the live Forums). Set this back to `.off` in the debugger before closing the sheet to see the retry succeed.
     */
    public static var simulatedForumsOutage: SimulatedForumsOutage = .off

    /// Where simulated outages redirect to. The real one as of October 2026.
    public static let simulatedOutageStatusPageURL = URL(string: "https://maintenance.somethingawful.com/")!
    
    public struct Fixture: Hashable {
        fileprivate let basename: String
        fileprivate let pathPrefix: String
        fileprivate let query: String?
        
        /// Requests for announcement details.
        public static let announcement = Fixture(basename: "announcement", pathPrefix: "/announcement.php")
        
        /// Requests for the list of forums, and for the list of threads on any forum.
        public static let forum = Fixture(basename: "forumdisplay", pathPrefix: "/forumdisplay.php")

        /// Requests for a page of posts.
        public static let thread = Fixture(basename: "showthread3", pathPrefix: "/showthread.php")
        
        private init(basename: String, pathPrefix: String, query: String? = nil) {
            self.basename = basename
            self.pathPrefix = pathPrefix
            self.query = query
        }
        
        fileprivate func matches(_ request: URLRequest) -> Bool {
            guard let url = request.url else { return false }
            guard url.path.hasPrefix(pathPrefix) else { return false }
            
            if let query = query {
                return url.query == query
            } else {
                return true
            }
        }
    }
    
    public enum LoadingError: Error {
        case dataLoadFailed(Error)
        case missingFixture(String)
        case noMatchingFixture
    }
    
    override public class func canInit(with request: URLRequest) -> Bool {
        logger.debug("being asked about \(request)")
        
        let scheme = request.url?.scheme?.lowercased()
        guard scheme == "http" || scheme == "https" else {
            logger.debug("skipping \(request) because scheme isn't right")
            return false
        }
        
        guard request.url?.host?.lowercased() == "forums.somethingawful.com" else {
            logger.debug("skipping \(request) because the host isn't right")
            return false
        }
        
        if shouldSimulateChallenge {
            logger.debug("simulating a Cloudflare challenge for \(request)")
            return true
        }

        if simulatedForumsOutage != .off {
            logger.debug("simulating a Forums outage for \(request)")
            return true
        }

        if scriptedURL(for: request) != nil {
            logger.debug("answering \(request) from a scripted thread")
            return true
        }

        if enabledFixtures.contains(where: { $0.matches(request) }) {
            logger.debug("we have a winner for \(request)!")
            return true
        } else {
            logger.debug("passing on \(request) as we have no enabled fixtures; adjust FixtureURLProtocol.enabledFixtures if this surprises you")
            return false
        }
    }
    
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    public override func startLoading() {
        logger.debug("starting load for \(self.request)")

        if FixtureURLProtocol.shouldSimulateChallenge, let url = request.url {
            loadSimulatedCloudflareChallenge(for: url)
            return
        }

        if let url = request.url {
            switch FixtureURLProtocol.simulatedForumsOutage {
            case .off:
                break
            case .redirectToStatusPage:
                loadSimulatedOutageRedirect(for: url)
                return
            case .databaseUnavailable:
                loadSimulatedDatabaseUnavailablePage(for: url)
                return
            }
        }

        if let url = FixtureURLProtocol.scriptedURL(for: request) {
            FixtureURLProtocol.logScriptedRequest(url)
            loadScriptedResponse(for: url)
            return
        }
        
        guard
            let url = request.url,
            let fixture = FixtureURLProtocol.enabledFixtures.first(where: { $0.matches(request) }) else
        {
            logger.debug("no matching fixture for \(self.request), yet it should've been in enabledFixtures if we made it this far; did enabledFixtures change recently?")
            client?.urlProtocol(self, didFailWithError: LoadingError.noMatchingFixture)
            return
        }
        
        logger.debug("matching fixture for \(self.request) is \(fixture.basename)")
        
        let bundle = Bundle(for: FixtureURLProtocol.self)
        guard let fixtureURL = bundle.url(forResource: fixture.basename, withExtension: "html", subdirectory: "Fixtures") else {
            
            logger.error("missing expected fixture \(fixture.basename) in bundle \(bundle); did you forget to add Core/Tests/Fixtures to the Core target?")
            
            client?.urlProtocol(self, didFailWithError: LoadingError.missingFixture(fixture.basename))
            return
        }
        
        let resourceValues = try? fixtureURL.resourceValues(forKeys: [.typeIdentifierKey])
        let mimeType = resourceValues?.typeIdentifier
            .flatMap(UTType.init(_:))
            .flatMap(\.preferredMIMEType)

        let data: Data
        do {
            data = try Data(contentsOf: fixtureURL)
        } catch {
            client?.urlProtocol(self, didFailWithError: LoadingError.dataLoadFailed(error))
            return
        }
        
        let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        
        client?.urlProtocol(self, didLoad: data)
        
        client?.urlProtocolDidFinishLoading(self)
        
        logger.debug("done loading for \(self.request)")
    }
    
    public override func stopLoading() {
        // nothing to do here; everything happens in startLoading()
    }

    // MARK: Scripted threads

    private func loadScriptedResponse(for url: URL) {
        let threads = FixtureURLProtocol.scriptedThreads
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems ?? []
        func query(_ name: String) -> String? { queryItems.first(where: { $0.name == name })?.value }

        guard url.path.hasPrefix("/showthread.php") else {
            logger.debug("scripted: empty page for \(url)")
            finishScripted(url: url, statusCode: 200, body: Data())
            return
        }

        if query("action") == "setseen" {
            finishScripted(url: url, statusCode: 200, body: Data())
            return
        }

        if query("goto") == "post", let postID = query("postid") {
            if let thread = threads.values.first(where: { $0.postPages[postID] != nil }), let page = thread.postPages[postID] {
                logger.debug("scripted: post \(postID) is on page \(page) of thread \(thread.threadID), redirecting")
                redirectScripted(from: url, threadID: thread.threadID, page: page, fragment: "post\(postID)")
            } else {
                logger.debug("scripted: post \(postID) is in no scripted thread, answering not found")
                finishScriptedNotFound(url: url)
            }
            return
        }

        guard let threadID = query("threadid"), let thread = threads[threadID] else {
            logger.debug("scripted: no scripted thread for \(url), answering not found")
            finishScriptedNotFound(url: url)
            return
        }

        switch query("goto") {
        case "newpost":
            redirectScripted(from: url, threadID: threadID, page: thread.firstUnreadPage, fragment: nil)
            return
        case "lastpost":
            redirectScripted(from: url, threadID: threadID, page: thread.lastPage, fragment: nil)
            return
        default:
            break
        }

        let pageNumber = query("pagenumber").flatMap { Int($0) } ?? 1
        if let page = thread.pages[pageNumber] {
            logger.debug("scripted: page \(pageNumber) of thread \(threadID)")
            finishScripted(url: url, statusCode: 200, body: page)
        } else {
            logger.debug("scripted: thread \(threadID) has no page \(pageNumber)")
            finishScripted(url: url, statusCode: 404, body: Data("<!DOCTYPE html><html><body><p>No scripted page \(pageNumber) for thread \(threadID).</p></body></html>".utf8))
        }
    }

    /// Sends a 302 to the page's URL, shaped like the Forums' own redirects: `threadid` and `pagenumber` but no `perpage`, which `ForumsClient.listPosts` re-adds on redirect for exactly that reason. The response carries an empty body, so a client that refuses the redirect gets a 302 and nothing else.
    private func redirectScripted(from url: URL, threadID: String, page: Int, fragment: String?) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "forums.somethingawful.com"
        components.path = "/showthread.php"
        components.queryItems = [
            URLQueryItem(name: "threadid", value: threadID),
            URLQueryItem(name: "pagenumber", value: String(page)),
        ]
        components.fragment = fragment
        let location = components.url!
        let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: [
            "Location": location.absoluteString,
            "Content-Type": "text/html; charset=utf-8",
        ])!
        client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: location), redirectResponse: response)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    private func finishScripted(url: URL, statusCode: Int, body: Data) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": "text/html; charset=utf-8",
            "Content-Length": String(body.count),
        ])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    /// Answers with the shape of the Forums' own "that doesn't exist" page: `body.standarderror` with `#content div.standard`, which `StandardErrorScrapeResult` turns into `ServerError.standard` so a lookup fails instead of scraping nothing.
    private func finishScriptedNotFound(url: URL) {
        finishScripted(url: url, statusCode: 200, body: Data(FixtureURLProtocol.notFoundPage.utf8))
    }

    private static let notFoundPage = """
        <!DOCTYPE html>
        <html lang="en">
        <head><meta charset="utf-8"><title>Specified post was not found - The Something Awful Forums</title></head>
        <body id="something_awful" class="standarderror">
        <div id="container">
        <div id="content">
        <div class="standard">
        <h2>Specified post was not found</h2>
        <div class="inner">
        <p>The post you are looking for does not exist. It may have been deleted, or it may never have existed. Please check the URL and try again.</p>
        </div>
        </div>
        </div>
        </div>
        </body>
        </html>
        """

    /// Answers the way the Forums do during an outage: a 302 to the status page, with nothing in the body.
    private func loadSimulatedOutageRedirect(for url: URL) {
        let location = FixtureURLProtocol.simulatedOutageStatusPageURL
        let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: [
            "Location": location.absoluteString,
            "Content-Type": "text/html; charset=utf-8",
        ])!
        client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: location), redirectResponse: response)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
        logger.debug("done simulating Forums outage redirect for \(url)")
    }

    /// Answers with the shape of the Forums' "Database Unavailable" page (see the `database-unavailable.html` fixture): a 503 whose body carries the `database_error` class and the `#msg h1` that `DatabaseUnavailableScrapeResult` reads.
    private func loadSimulatedDatabaseUnavailablePage(for url: URL) {
        let body = """
            <!DOCTYPE html>
            <html>
            <head><title>Database Unavailable</title></head>
            <body id="something_awful" class="database_error">
            <div id="closemsg"><div id="msg">
            <h1>Database Unavailable!</h1>
            The database is currently not available. You can try doing whatever it is you were trying to do again later. You do not need to notify anyone of your arrival at this page.
            <div class="note">Simulated by FixtureURLProtocol.simulatedForumsOutage</div>
            </div></div>
            </body>
            </html>
            """
        let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": "text/html; charset=utf-8",
        ])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
        logger.debug("done simulating Database Unavailable page for \(url)")
    }

    /// Answers with the shape of a real Cloudflare managed challenge: a 403, the `cf-mitigated` header, and a minimal "Just a moment…" body carrying the markers `CloudflareChallenge` looks for.
    private func loadSimulatedCloudflareChallenge(for url: URL) {
        let body = """
            <!DOCTYPE html>
            <html lang="en-US">
            <head>
            <title>Just a moment...</title>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
            </head>
            <body class="no-js">
            <div class="main-wrapper" role="main">
            <h1>forums.somethingawful.com</h1>
            <p>Verifying you are human. This may take a few seconds.</p>
            <div id="cf-chl-widget"></div>
            </div>
            <script>window._cf_chl_opt = { cRay: "simulated" };</script>
            <script src="/cdn-cgi/challenge-platform/h/b/orchestrate/chl_page/v1?ray=simulated"></script>
            </body>
            </html>
            """
        let data = Data(body.utf8)
        let response = HTTPURLResponse(
            url: url,
            statusCode: 403,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "cf-mitigated": "challenge",
                "cf-ray": FixtureURLProtocol.simulatedCloudflareRayID,
                "Content-Type": "text/html; charset=UTF-8",
                "Server": "cloudflare",
            ]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
        logger.debug("done simulating Cloudflare challenge for \(url)")
    }
}

#endif
