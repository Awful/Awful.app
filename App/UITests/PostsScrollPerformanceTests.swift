//  PostsScrollPerformanceTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US

import os
import XCTest

/// Repeatable scrolling workouts for the posts view, for measuring scroll smoothness with the
/// performance probe (see `PostsPerformance`).
///
/// With endless scroll on, `testSlowScrolling` and `testMediumScrolling` open page 1 of an
/// image-heavy thread, flick quickly down four pages, then scroll back up two pages and down two
/// again, unhurried and twice as fast. `testScrollUpAfterPreviousPosts` scrolls up through posts
/// revealed by Previous posts. The gestures are real touches, so scroll anchoring and WebKit's
/// async scrolling behave as they do for a reader. (XCUITest waits for each gesture's scrolling to
/// settle before the next, so gestures never overlap.)
///
/// The tests drive the app and log the start and end of each phase; only the Previous posts one
/// asserts anything. The numbers come from the probe's own logging, so run them through
/// `Scripts/posts-scroll-perf.sh`, which captures that output alongside process CPU and memory and
/// writes a per-phase report.
///
/// Progress comes from the probe too: it posts a Darwin notification naming the page at the top of
/// the viewport whenever that changes, so the test never snapshots the web view's (large, and
/// slow to snapshot) accessibility tree mid-workout.
///
/// Requires a logged-in simulator; skips otherwise. Settings are overridden through launch
/// arguments, which don't persist.
final class PostsScrollPerformanceTests: XCTestCase {

    /// GIF Thread: pages of GIFs, imgur videos and the odd tweet.
    private static let threadURL = URL(string: "awfulhttps://forums.somethingawful.com/showthread.php?threadid=3867897&perpage=40&pagenumber=1&noseen=1")!

    /// Matches `PostsPerformance.topPageNotificationPrefix` in the app.
    private static let topPageNotificationPrefix = "com.awfulapp.Awful.perf.topPage."

    /// The page at the top of the viewport, as last announced by the app. The probe reports 0 for the page first loaded, which here is page 1.
    private static var topPage = 1

    /// Matches `PostsPerformance.shiftAboveNotificationPrefix`, `atTopNotificationName` and `setSeenNotificationName` in the app.
    private static let shiftAboveNotificationPrefix = "com.awfulapp.Awful.perf.shiftAbove."
    private static let atTopNotificationName = "com.awfulapp.Awful.perf.atTop"
    private static let setSeenNotificationName = "com.awfulapp.Awful.perf.setSeen"

    /// Posts that changed height above the viewport while scrolling, as announced by the app: drawn for the first time (leaving their placeholder height), or grown as images and embeds loaded.
    private static var firstRenderShifts = 0
    private static var growthShifts = 0
    private static var reachedTop = false
    private static var didSetSeen = false

    /// Shares the probe's category so one `log stream` captures both.
    private let logger = Logger(subsystem: "com.awfulapp.Awful.UITests", category: "PostsPerformance")

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // `-key value` pairs land in the launched process's argument domain only. Booleans the
        // app reads through Foil must be plist literals; see SidebarAlignmentTests.
        app.launchArguments += [
            "-AwfulPerfProbe", "YES",
            "-endless_scroll_posts", "<true/>",
        ]
        // Set by posts-scroll-perf.sh's --gifs option (passed through xcodebuild as TEST_RUNNER_AWFUL_PERF_AUTOPLAY_GIFS) to compare runs with and without animated GIFs. Otherwise the simulator's own setting applies.
        if let autoplay = ProcessInfo.processInfo.environment["AWFUL_PERF_AUTOPLAY_GIFS"] {
            app.launchArguments += ["-autoplay_gifs", autoplay == "YES" ? "<true/>" : "<false/>"]
        }
        // Set by posts-scroll-perf.sh's --no-frames option, to measure the web content process without the probe's frame sampling.
        if ProcessInfo.processInfo.environment["AWFUL_PERF_PROBE_FRAMES"] == "NO" {
            app.launchArguments += ["-AwfulPerfProbeFrames", "NO"]
        }
        Self.topPage = 1
        Self.firstRenderShifts = 0
        Self.growthShifts = 0
        Self.reachedTop = false
        Self.didSetSeen = false
        observeTopPage()
        observeProbeEvents()
    }

    override func tearDown() {
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), observerToken)
        super.tearDown()
    }

    /// Back up and down two pages unhurriedly: drags let go while moving, so each carries on a little.
    func testSlowScrolling() throws {
        try workout(name: "slow") { up in
            self.drag(up: up, velocity: XCUIGestureVelocity(1500))
        }
    }

    /// The same at twice the speed.
    func testMediumScrolling() throws {
        try workout(name: "medium") { up in
            self.drag(up: up, velocity: XCUIGestureVelocity(3000))
        }
    }

    /// A reader opens a page at its first unread post, taps Previous posts to put the posts before it back above them, and scrolls up through those. None of those posts has been drawn yet, so each must already have its real height; if one is first drawn on the way up, everything below it lurches.
    ///
    /// Set `AWFUL_PERF_SET_SEEN` (passed through xcodebuild as `TEST_RUNNER_AWFUL_PERF_SET_SEEN`) to `<threadID>:<index>` to choose the thread and first unread post. The default is post 20 of page 3148 of the Bluesky thread, which has plenty of tweets and Bluesky posts. Pick a post on a full page, so the posts don't change between runs, and vary it now and then: embeds a run has already loaded come from cache next time.
    func testScrollUpAfterPreviousPosts() throws {
        let spec = ProcessInfo.processInfo.environment["AWFUL_PERF_SET_SEEN"] ?? "3879285:125900"
        let parts = spec.split(separator: ":")
        guard parts.count == 2, let index = Int(parts[1]), index > 1 else {
            throw XCTSkip("AWFUL_PERF_SET_SEEN should look like <threadID>:<index>, with an index past the first post")
        }
        let threadID = String(parts[0])
        let page = (index - 1) / 40 + 1

        // Marks the thread read up to the post before `index`, as "Mark as read up to here" does, so the page opens there with the earlier posts hidden.
        app.launchArguments += ["-AwfulPerfSetSeen", spec]
        app.launch()
        try skipUnlessLoggedIn()
        guard #available(iOS 16.4, *) else {
            throw XCTSkip("Opening the thread by URL needs iOS 16.4 or newer.")
        }
        waitUntil(timeout: 20) { Self.didSetSeen }
        XCTAssertTrue(Self.didSetSeen, "the app didn't report marking the thread read")

        app.open(URL(string: "awfulhttps://forums.somethingawful.com/showthread.php?threadid=\(threadID)&perpage=40&pagenumber=\(page)")!)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 20), "no posts web view")
        sleep(6)

        // The top bar shows once the reader scrolls up a little.
        let previousPosts = app.buttons["Previous posts"]
        for _ in 0..<5 where !(previousPosts.exists && previousPosts.isHittable) {
            point(0.4).press(forDuration: 0.05, thenDragTo: point(0.5), withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(previousPosts.isHittable, "no Previous posts button; is post \(index) within the thread?")
        XCTAssertTrue(previousPosts.isEnabled, "no posts to reveal; is the Forums option to mark seen posts in a different colour on?")
        previousPosts.tap()
        // Not `sleep`: the run loop must deliver what the tap caused before the counts reset, or it's counted as happening while scrolling.
        RunLoop.current.run(until: Date().addingTimeInterval(2))

        Self.firstRenderShifts = 0
        Self.growthShifts = 0
        Self.reachedTop = false
        phase("previous-posts/up") {
            repeatGesture(until: { Self.reachedTop }, maxGestures: 300) {
                self.drag(up: false, velocity: XCUIGestureVelocity(1500))
            }
        }
        sleep(3)
        logger.info("[ui-test] shifts above viewport: \(Self.firstRenderShifts) first draws, \(Self.growthShifts) growths")
        logger.info("[ui-test] done previous-posts")

        XCTAssertEqual(Self.firstRenderShifts, 0, "posts were drawn for the first time above the viewport while scrolling up, so the page jumped")
    }

    // MARK: Workout

    /// - Parameter scroll: One gesture moving the page down (`up` is the finger moving up the screen) or back up.
    private func workout(name: String, scroll: (_ up: Bool) -> Void) throws {
        app.launch()
        try skipUnlessLoggedIn()
        guard #available(iOS 16.4, *) else {
            throw XCTSkip("Opening the thread by URL needs iOS 16.4 or newer.")
        }
        app.open(Self.threadURL)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 20), "no posts web view")
        // Let the first page and its up-front images load before measuring anything.
        sleep(6)

        phase("\(name)/fast-down-4") {
            // Pages 1 through 4, until page 5 reaches the top of the screen.
            repeatGesture(until: { Self.topPage >= 5 }, maxGestures: 150) {
                self.flick()
            }
        }
        sleep(3)

        phase("\(name)/up-2") {
            // From the start of page 5 back past the start of page 3.
            repeatGesture(until: { Self.topPage <= 2 }, maxGestures: 400) {
                scroll(false)
            }
        }
        sleep(3)

        phase("\(name)/down-2") {
            // And down again to the start of page 5.
            repeatGesture(until: { Self.topPage >= 5 }, maxGestures: 400) {
                scroll(true)
            }
        }
        // Let the last scroll session and snapshot reports arrive.
        sleep(4)
        logger.info("[ui-test] done \(name, privacy: .public)")
    }

    // MARK: Gestures

    /// Gestures target screen coordinates rather than the web view element, which XCUITest would otherwise resolve (snapshotting its whole accessibility tree) before every gesture.
    private func point(_ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y))
    }

    /// A long, hard flick up the screen that sends the page flying.
    private func flick() {
        point(0.9).press(forDuration: 0.01, thenDragTo: point(0.1), withVelocity: XCUIGestureVelocity(6000), thenHoldForDuration: 0)
    }

    /// A drag let go while still moving, so the page carries on a little.
    /// - Parameter up: Whether the finger moves up the screen (scrolling down the page).
    private func drag(up: Bool, velocity: XCUIGestureVelocity) {
        let (start, end) = up ? (point(0.7), point(0.3)) : (point(0.3), point(0.7))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: velocity, thenHoldForDuration: 0)
    }

    private func repeatGesture(until done: () -> Bool, maxGestures: Int, gesture: () -> Void) {
        for count in 1...maxGestures {
            gesture()
            // Deliver any top-page notifications that arrived during the gesture.
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            if done() {
                logger.info("[ui-test] reached page \(Self.topPage) after \(count) gestures")
                return
            }
        }
        XCTFail("didn't reach the target within \(maxGestures) gestures (top page \(Self.topPage))")
    }

    private func waitUntil(timeout: TimeInterval, _ done: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !done(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }

    // MARK: Progress

    private var observerToken: UnsafeRawPointer {
        UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    private func observeTopPage() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        // Darwin notifications carry no payload, so there's one name per page.
        for page in 0...60 {
            CFNotificationCenterAddObserver(center, observerToken, { _, _, name, _, _ in
                guard let name = name?.rawValue as String?,
                      let page = Int(name.dropFirst(PostsScrollPerformanceTests.topPageNotificationPrefix.count))
                else { return }
                PostsScrollPerformanceTests.topPage = max(page, 1)
            }, "\(Self.topPageNotificationPrefix)\(page)" as CFString, nil, .deliverImmediately)
        }
    }

    private func observeProbeEvents() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let callback: CFNotificationCallback = { _, _, name, _, _ in
            switch name?.rawValue as String? {
            case PostsScrollPerformanceTests.shiftAboveNotificationPrefix + "firstRender":
                PostsScrollPerformanceTests.firstRenderShifts += 1
            case PostsScrollPerformanceTests.shiftAboveNotificationPrefix + "growth":
                PostsScrollPerformanceTests.growthShifts += 1
            case PostsScrollPerformanceTests.atTopNotificationName:
                PostsScrollPerformanceTests.reachedTop = true
            case PostsScrollPerformanceTests.setSeenNotificationName:
                PostsScrollPerformanceTests.didSetSeen = true
            default:
                break
            }
        }
        for name in [
            Self.shiftAboveNotificationPrefix + "firstRender",
            Self.shiftAboveNotificationPrefix + "growth",
            Self.atTopNotificationName,
            Self.setSeenNotificationName,
        ] {
            CFNotificationCenterAddObserver(center, observerToken, callback, name as CFString, nil, .deliverImmediately)
        }
    }

    // MARK: Logging

    private func phase(_ name: String, _ body: () -> Void) {
        logger.info("[ui-test] phase \(name, privacy: .public) start")
        body()
        logger.info("[ui-test] phase \(name, privacy: .public) end")
    }

    private func skipUnlessLoggedIn() throws {
        if app.tabBars.firstMatch.waitForExistence(timeout: 15) { return }
        // Restoration may have landed in a thread; that's logged in too.
        if app.webViews.firstMatch.exists { return }
        throw XCTSkip("No tab bar or posts view found; log in on this simulator first.")
    }
}
