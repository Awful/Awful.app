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
 */
public final class FixtureURLProtocol: URLProtocol {
    
    /**
     Any fixtures added here will be loaded, causing relevant requests to be intercepted. Initially the set of enabled fixtures is empty, at which point this URL protocol does nothing.
     */
    public static var enabledFixtures: Set<Fixture> = []
    
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
}

#endif
