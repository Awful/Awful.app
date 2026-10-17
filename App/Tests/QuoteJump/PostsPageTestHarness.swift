//  PostsPageTestHarness.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import AwfulCore
import AwfulSettings
import CoreData
import UIKit
import XCTest

/// Everything a quote-jump scenario needs around a real `PostsPageViewController`: a window for its web view to lay out in, a throwaway `DataStore`, `ForumsClient` pointed at the scripted `quotejump` thread, a local image server with scripted delays, and probes that read where posts sit on screen from the rendered document.
///
/// Scenarios drive the controller the way the app does: `didTapLink(to:in:)` for a tapped quote (the step before it, `WKNavigationDelegate`, is WebKit's), `PostLocator` for the router's "open this post" path, and the controller's own `loadPage`/`cancelPendingScrollRestoration` for restoration and dragging. Positions come straight from `getBoundingClientRect()`, so a scenario asserts what the reader would see.
@MainActor
final class PostsPageTestHarness {

    let window: UIWindow
    let navigationController = UINavigationController()
    let imageServer: LocalImageServer

    /// Routes the controller handed off because it couldn't show them itself (quotes of posts on other pages).
    private(set) var openedRoutes: [AwfulRoute] = []

    private let dataStore: DataStore
    private let context: NSManagedObjectContext
    private let restoredDefaults: [String: Any?]

    /// - Parameter embedTweets: Off by default so the page never loads Twitter's widgets script from the network; `fireTweetsLoaded(in:)` simulates its "loaded" event, which the controller handles whatever the setting.
    init(pageThree: QuoteJumpFixture.PageThreeVariant = .unread, embedTweets: Bool = false, endlessScroll: Bool = false) throws {
        imageServer = try LocalImageServer()

        // A real `DataStore` rather than a bare in-memory context: its main context carries the observer that stamps `lastModifiedDate`, without which nothing the app inserts on the main context (a located post, say) can save.
        let storeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("QuoteJumpTests-\(UUID().uuidString)", isDirectory: true)
        dataStore = DataStore(storeDirectoryURL: storeDirectory)
        context = dataStore.mainManagedObjectContext

        ForumsClient.shared.managedObjectContext = context
        ForumsClient.shared.baseURL = URL(string: "https://forums.somethingawful.com/")!

        FixtureURLProtocol.resetScripting()
        FixtureURLProtocol.scriptedThreads[QuoteJumpFixture.threadID] = try QuoteJumpFixture.scriptedThread(imageBase: imageServer.baseURL, pageThree: pageThree)

        // Settings that decide what the page renders and how it scrolls, pinned so a developer's own simulator settings can't change a scenario.
        let settings: [(key: String, value: Any)] = [
            (Settings.loadImages.key, true),
            (Settings.showAvatars.key, false),
            (Settings.embedTweets.key, embedTweets),
            (Settings.embedBlueskyPosts.key, false),
            (Settings.embedVideos.key, false),
            (Settings.endlessScrollPosts.key, endlessScroll),
            (Settings.frogAndGhostEnabled.key, false),
            (Settings.immersiveModeEnabled.key, false),
            (Settings.collapseLongQuotes.key, false),
            (Settings.darkMode.key, false),
            (Settings.autoDarkTheme.key, false),
            (Settings.fontScale.key, 100.0),
        ]
        let defaults = UserDefaults.standard
        restoredDefaults = Dictionary(uniqueKeysWithValues: settings.map { ($0.key, defaults.object(forKey: $0.key)) })
        for (key, value) in settings {
            defaults.set(value, forKey: key)
        }

        let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
            window.frame = frame
        } else {
            window = UIWindow(frame: frame)
        }
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }

    /// Undoes what `init` set up. Call from `tearDown`.
    func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
        imageServer.stop()
        FixtureURLProtocol.resetScripting()
        ForumsClient.shared.managedObjectContext = nil
        try? FileManager.default.removeItem(at: dataStore.storeDirectoryURL)
        let defaults = UserDefaults.standard
        for (key, value) in restoredDefaults {
            if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
    }

    // MARK: Thread state

    /// The fixture thread in the store, created on first use.
    var thread: AwfulThread {
        AwfulThread.objectForKey(objectKey: ThreadKey(threadID: QuoteJumpFixture.threadID), in: context)
    }

    /// How far the reader has read, as the app records it (the fixture pages' own seen markers decide what hides behind Previous Posts).
    func setSeenPosts(_ count: Int) throws {
        thread.seenPosts = Int32(count)
        try context.save()
    }

    /// Fetches pages into the store without showing them, so a scenario can start with a post already cached (as `PostLocator.cachedPostsPageViewController` requires).
    func cachePages(_ pages: [Int]) async throws {
        for page in pages {
            _ = try await ForumsClient.shared.listPosts(in: thread, writtenBy: nil, page: .specific(page), updateLastReadPost: false)
        }
    }

    func cachedPost(index: Int) -> Post? {
        Post.existingObjectForKey(objectKey: PostKey(postID: QuoteJumpFixture.postID(forIndex: index)), in: context)
    }

    // MARK: Showing pages

    /// Opens `page` of the fixture thread as navigating to it in the app does, returning once the render has finished and any staged scroll has been applied.
    func openPage(_ page: Int, restoring: PendingPostsRestoration? = nil) async throws -> PostsPageViewController {
        let viewController = makeViewController()
        viewController.loadPage(.specific(page), updatingCache: true, updatingLastReadPost: false, restoring: restoring)
        install(viewController)
        try await waitForRender(of: viewController)
        return viewController
    }

    /// Opens the page holding the post at `index` the way `AwfulURLRouter` does for a `.post` route: straight from the cache when the post's page is known, otherwise by asking the (scripted) Forums where it is. Returns once rendered and scrolled.
    func openViaPostRoute(toIndex index: Int) async throws -> PostsPageViewController {
        let postID = QuoteJumpFixture.postID(forIndex: index)
        let viewController: PostsPageViewController
        if let cached = PostLocator.cachedPostsPageViewController(postID: postID, updateLastReadPost: false, in: context) {
            viewController = cached
        } else {
            viewController = try await PostLocator.makePostsPageViewController(postID: postID, updateLastReadPost: false)
        }
        prepare(viewController)
        install(viewController)
        try await waitForRender(of: viewController)
        return viewController
    }

    /// `AwfulURLRouter`'s path for a post that isn't cached, exposed so a scenario can assert on how it fails.
    func locateUncachedPost(id postID: String) async throws -> PostsPageViewController {
        try await PostLocator.makePostsPageViewController(postID: postID, updateLastReadPost: false)
    }

    private func makeViewController() -> PostsPageViewController {
        let viewController = PostsPageViewController(thread: thread)
        prepare(viewController)
        return viewController
    }

    private func prepare(_ viewController: PostsPageViewController) {
        viewController.openRoute = { [weak self] route in
            self?.openedRoutes.append(route)
        }
    }

    private func install(_ viewController: PostsPageViewController) {
        navigationController.setViewControllers([viewController], animated: false)
        window.layoutIfNeeded()
    }

    /// Waits for the next render to finish and scroll into place (see `PostsPageViewController.onDidFinishRenderingForTesting`), or returns at once when the document is already loaded and nothing is in flight.
    func waitForRender(of viewController: PostsPageViewController, timeout: TimeInterval = 15) async throws {
        if !viewController.isAwaitingRenderedContent {
            // A render that already finished can't signal again; make sure its scroll has settled.
            await waitForScrollToSettle(in: viewController)
            return
        }
        try await withTimeout(timeout, description: "render of \(viewController.thread.threadID)") {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                var resumed = false
                viewController.onDidFinishRenderingForTesting = {
                    guard !resumed else { return }
                    resumed = true
                    viewController.onDidFinishRenderingForTesting = nil
                    continuation.resume()
                }
            }
        }
        await waitForScrollToSettle(in: viewController)
    }

    // MARK: Acting

    /// What tapping a quote link in the rendered page does once WebKit has handed the link to the app.
    func tapQuote(toIndex index: Int, in viewController: PostsPageViewController) {
        tapQuote(toPostID: QuoteJumpFixture.postID(forIndex: index), in: viewController)
    }

    /// Like `tapQuote(toIndex:in:)`, for a post that isn't in the fixture thread (a deleted one, say).
    func tapQuote(toPostID postID: String, in viewController: PostsPageViewController) {
        viewController.didTapLink(to: QuoteJumpFixture.quoteLinkURL(toPostID: postID), in: viewController.renderViewForTesting)
    }

    /// Clicks the first element matching `selector` in the document, so the tap goes through WebKit's navigation delegate as a real tap would. Returns false when nothing matched.
    @discardableResult
    func click(_ selector: String, in viewController: PostsPageViewController) async throws -> Bool {
        let result = try await eval("""
            (function() {
                var element = document.querySelector(\(jsString(selector)));
                if (!element) { return false; }
                element.click();
                return true;
            })()
            """, in: viewController)
        return result as? Bool ?? false
    }

    /// What the web view sends once Twitter's widgets script has finished laying out tweets.
    func fireTweetsLoaded(in viewController: PostsPageViewController) async throws {
        // `postMessage` hands back a promise, which `evaluateJavaScript` can't return, so don't return it.
        try await eval("(function() { webkit.messageHandlers.didFinishLoadingTweets.postMessage({}); return true; })()", in: viewController)
        // The message is delivered to the controller asynchronously; let it arrive and act before measuring.
        try? await Task.sleep(nanoseconds: 300_000_000)
        await waitForScrollToSettle(in: viewController)
    }

    /// Models the reader starting to drag, which abandons any staged scroll target.
    func drag(in viewController: PostsPageViewController) {
        viewController.cancelPendingScrollRestoration()
    }

    // MARK: Probing

    func topInset(of viewController: PostsPageViewController) -> CGFloat {
        viewController.topInsetForPostFramingForTesting
    }

    /// The post's top edge in viewport coordinates, or nil when it isn't in the document.
    func postTop(index: Int, in viewController: PostsPageViewController) async throws -> CGFloat? {
        let result = try await eval("""
            (function() {
                var post = document.getElementById(\(jsString(QuoteJumpFixture.postID(forIndex: index))));
                return post ? post.getBoundingClientRect().top : null;
            })()
            """, in: viewController)
        return (result as? NSNumber).map { CGFloat($0.doubleValue) }
    }

    func isInDocument(index: Int, in viewController: PostsPageViewController) async throws -> Bool {
        try await postTop(index: index, in: viewController) != nil
    }

    /// The first post whose bottom edge is below the top inset, i.e. the one the reader sees at the top of the viewport.
    func topVisiblePostIndex(in viewController: PostsPageViewController) async throws -> Int? {
        let inset = topInset(of: viewController)
        let result = try await eval("""
            (function() {
                var posts = document.querySelectorAll('post');
                for (var i = 0; i < posts.length; i++) {
                    if (posts[i].getBoundingClientRect().bottom > \(inset) + 1) { return posts[i].id; }
                }
                return null;
            })()
            """, in: viewController)
        return (result as? String).flatMap(QuoteJumpFixture.index(ofPostID:))
    }

    struct ScrollMetrics {
        var scrollY: CGFloat
        var scrollHeight: CGFloat
        var innerHeight: CGFloat
        var isAtBottom: Bool { scrollY + innerHeight >= scrollHeight - 2 }
    }

    func scrollMetrics(in viewController: PostsPageViewController) async throws -> ScrollMetrics {
        let result = try await eval("[window.scrollY, document.documentElement.scrollHeight, window.innerHeight]", in: viewController)
        let numbers = (result as? [NSNumber]) ?? []
        guard numbers.count == 3 else { throw HarnessError.badScrollMetrics }
        return ScrollMetrics(scrollY: CGFloat(numbers[0].doubleValue), scrollHeight: CGFloat(numbers[1].doubleValue), innerHeight: CGFloat(numbers[2].doubleValue))
    }

    /// Asserts that the reader is looking at the post at `index`: its top edge sits at the top inset (within `tolerance` points), or the document is scrolled as far as it goes and the post is on screen.
    func assertLanded(on index: Int, in viewController: PostsPageViewController, tolerance: CGFloat = 4, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) async throws {
        let inset = topInset(of: viewController)
        guard let top = try await postTop(index: index, in: viewController) else {
            XCTFail("post \(index) is not in the document. \(message)", file: file, line: line)
            return
        }
        let metrics = try await scrollMetrics(in: viewController)
        let topVisible = try await topVisiblePostIndex(in: viewController)
        if abs(top - inset) <= tolerance { return }
        if metrics.isAtBottom, top >= inset - tolerance, top < metrics.innerHeight { return }
        let hash = (try? await eval("window.location.hash", in: viewController) as? String) ?? ""
        XCTFail("expected post \(index) at the top (inset \(inset)) but its top is at \(top); the top visible post is \(topVisible.map(String.init) ?? "none"), scrollY \(metrics.scrollY) of \(metrics.scrollHeight - metrics.innerHeight), location.hash \"\(hash)\", images served \(imageServer.servedCount). \(message)", file: file, line: line)
    }

    // MARK: Waiting

    /// Waits until `window.scrollY` has stopped changing (smooth scrolls animate; layout shifts move it), or gives up after `timeout`.
    func waitForScrollToSettle(in viewController: PostsPageViewController, timeout: TimeInterval = 3) async {
        let deadline = Date(timeIntervalSinceNow: timeout)
        var last: Double?
        var stableReadings = 0
        while Date() < deadline {
            let current = (try? await eval("window.scrollY", in: viewController) as? NSNumber)?.doubleValue
            if let current, let last, abs(current - last) < 0.5 {
                stableReadings += 1
                if stableReadings >= 3 { return }
            } else {
                stableReadings = 0
            }
            last = current
            try? await Task.sleep(nanoseconds: 60_000_000)
        }
    }

    /// Lets scripted media finish: sleeps for `milliseconds`, then waits for layout and scrolling to settle.
    func settle(milliseconds: Int, in viewController: PostsPageViewController) async {
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
        _ = try? await eval("new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))", in: viewController)
        await waitForScrollToSettle(in: viewController)
    }

    @discardableResult
    func eval(_ javaScript: String, in viewController: PostsPageViewController) async throws -> Any? {
        try await viewController.renderViewForTesting.evalForTesting(javaScript)
    }

    private func jsString(_ string: String) -> String {
        String(data: try! JSONEncoder().encode(string), encoding: .utf8)!
    }

    private func withTimeout<T: Sendable>(_ seconds: TimeInterval, description: String, _ operation: @escaping @MainActor () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw HarnessError.timedOut(description)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    enum HarnessError: Error, CustomStringConvertible {
        case timedOut(String)
        case badScrollMetrics

        var description: String {
            switch self {
            case .timedOut(let what): return "timed out waiting for \(what)"
            case .badScrollMetrics: return "could not read scroll metrics from the document"
            }
        }
    }
}
