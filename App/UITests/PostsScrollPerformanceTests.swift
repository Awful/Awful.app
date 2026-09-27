//  PostsScrollPerformanceTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US

import os
import XCTest

/// Repeatable scrolling workouts for the posts view, for measuring scroll smoothness with the
/// performance probe (see `PostsPerformance`).
///
/// With endless scroll on, each workout opens page 1 of an image-heavy thread, flicks quickly
/// down four pages, then scrolls back up two pages and down two again: unhurried in
/// `testSlowScrolling`, twice as fast in `testMediumScrolling`. The gestures are real touches, so
/// scroll anchoring and WebKit's async scrolling behave as they do for a reader. (XCUITest waits
/// for each gesture's scrolling to settle before the next, so gestures never overlap.)
///
/// The test only drives the app and logs the start and end of each phase. The numbers come from
/// the probe's own logging, so run it through `Scripts/posts-scroll-perf.sh`, which captures that
/// output alongside process CPU and memory and writes a per-phase report.
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
        Self.topPage = 1
        observeTopPage()
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
