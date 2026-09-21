//  SidebarAlignmentTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US

import XCTest

/// Measures nav-bar title and button alignment on iPad, in both orientations,
/// across the sidebar tabs, a pushed thread list, and the posts detail pane.
///
/// Every measurement is printed (a table lands at the end of the test log) and
/// a screenshot of every screen x orientation is attached to the result
/// bundle, so a run doubles as a visual matrix. Assertions fire only when a
/// measurement exceeds the tolerances below.
///
/// Each orientation runs twice: once with the app's own defaults and once with
/// the "Reduce Liquid Glass" setting forced on through a launch argument. The
/// iPad sidebar keeps UIKit's glass-panel rendering either way, so the title
/// centering and button treatment must hold in both states.
///
/// Requires a logged-in simulator; the test skips loudly otherwise. Buttons
/// are measured, never tapped — no compose screen is ever opened. For every
/// bar button the report carries its size, its gap to the pane edge on its
/// own side (outermost buttons only), and its gap to whatever sits beside it
/// — the neighbouring button or the title — so a button that drifts, grows,
/// or crowds its neighbour shows up as a number, not just in the screenshot.
///
/// The title contract (SidebarTitleView): centred on its pane whenever the
/// whole text fits there clear of the item clusters; otherwise slid toward
/// the pane's centre until it meets the nearer cluster. Bar width is never
/// a special case — a narrow bar simply pins more titles.
final class SidebarAlignmentTests: XCTestCase {

    // MARK: Tolerances (points)

    /// Title's horizontal center vs. its pane's center.
    private static let horizontalTolerance: CGFloat = 4
    /// Title's vertical center vs. each bar button's vertical center.
    private static let verticalTolerance: CGFloat = 2
    /// Acceptable range for the gap between an outermost bar button and the
    /// pane edge on its side. Negative means the button overhangs the pane.
    private static let edgeGapRange: ClosedRange<CGFloat> = 4...24
    /// Spacing between neighbouring buttons on the sidebar's trailing side, the
    /// toggle included: `NavigationController.sidebarClusterSpacing`, which
    /// lays the trailing icons out as one evenly spaced cluster.
    private static let clusterSpacing: CGFloat = 12
    /// Slack on `clusterSpacing`: the measured frames are the glyph boxes, and
    /// a symbol drawn at 17pt in a 20pt box sits 1.5pt in from its edges.
    private static let clusterSpacingTolerance: CGFloat = 2

    /// The split view's maximumPrimaryColumnWidth (RootViewControllerStack),
    /// used to tell the sidebar nav bar from the detail pane's.
    private static let sidebarMaxWidth: CGFloat = 350
    /// A title that couldn't be centred must sit no further than this from
    /// the cluster it was slid up against. SidebarTitleView keeps its 8pt
    /// cluster gap from the item's 44pt bar slot, while the frames measured
    /// here are the 20pt glyphs centred in those slots, 12pt in from the slot
    /// edge — so a pinned (or truncated, filling-the-span) title reads 20pt
    /// from the nearest glyph, plus a little room for measurement.
    private static let pinnedGapMax: CGFloat = 24

    private var app: XCUIApplication!
    private var measurements: [Measurement] = []
    /// On iPhone there is no split view: the one nav bar is measured as pane
    /// "bar", the sidebar-summoning helpers stand down, and the sidebar-only
    /// assertions (cluster spacing, leading edge) are recorded, not enforced.
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    private var overlays: [Overlay] = []

    /// Drawing primitives collected while measuring, rendered onto the
    /// screenshot afterward. Coordinates are interface-orientation points.
    private enum Overlay {
        case box(CGRect, UIColor, label: String?)
        case hline(y: CGFloat, fromX: CGFloat, toX: CGFloat, color: UIColor, label: String)
        case vline(x: CGFloat, fromY: CGFloat, toY: CGFloat, color: UIColor, dashed: Bool)
    }

    private struct Measurement {
        var screen: String
        var pane: String
        var metric: String
        var detail: String
        var value: CGFloat?
        var ok: Bool
        /// Whether `ok` was enforced by an assertion, or only recorded.
        var asserted: Bool = false
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        measurements = []
    }

    override func tearDown() {
        printReport()
        XCUIDevice.shared.orientation = .landscapeLeft
        app = nil
        super.tearDown()
    }

    // MARK: Tests

    func testAlignmentLandscape() throws {
        try runAlignmentPass(orientation: .landscapeLeft, name: "landscape")
    }

    func testAlignmentPortrait() throws {
        try runAlignmentPass(orientation: .portrait, name: "portrait")
    }

    func testAlignmentLandscapeReducedGlass() throws {
        try runAlignmentPass(orientation: .landscapeLeft, name: "landscape", reduceLiquidGlass: true)
    }

    func testAlignmentPortraitReducedGlass() throws {
        try runAlignmentPass(orientation: .portrait, name: "portrait", reduceLiquidGlass: true)
    }

    // MARK: Pass

    private func runAlignmentPass(
        orientation: UIDeviceOrientation,
        name orientationName: String,
        reduceLiquidGlass: Bool = false
    ) throws {
        XCUIDevice.shared.orientation = orientation
        if reduceLiquidGlass {
            // `-key value` pairs land in UserDefaults' argument domain, which
            // overrides the app domain for the launched process only — nothing
            // persists on the simulator. The value must be the plist literal:
            // a bare `1` or `YES` arrives as a String, and Foil's
            // @FoilDefaultStorage force-unwraps its Bool cast at app-delegate
            // init, crashing the app before the first screen.
            app.launchArguments += ["-disable_liquid_glass", "<true/>"]
        }
        app.launch()
        try skipUnlessLoggedIn()
        let variant = reduceLiquidGlass ? "\(orientationName), reduced glass" : orientationName

        // Tab roots first (Forums last so the push flows continue from it).
        // (name, tab-button labels to try, tab icon image identifier, nav title hints)
        let tabs: [(String, [String], String, [String])] = [
            ("Bookmarks", ["Bookmarks"], "bookmarks", ["Bookmarks"]),
            // The tab item's accessibilityLabel is "Private messages"
            // (MessageListViewController); the nav title is "Messages".
            ("Messages", ["Private messages", "Messages"], "pm-icon", ["Messages"]),
            ("Lepers", ["Lepers"], "lepers", ["Leper’s Colony"]),
            ("Settings", ["Settings"], "cog", ["Settings"]),
            ("Forums", ["Forums"], "forum-list", ["Forums"]),
        ]
        for (name, labels, icon, hints) in tabs {
            guard selectTab(name, labels: labels, icon: icon) else { continue }
            revealSidebarIfHidden()
            measureScreen("\(name) (\(variant))", expectedTitleHints: hints)
            if name == "Settings" {
                verifyReduceLiquidGlassToggle(expected: reduceLiquidGlass, screen: "\(name) (\(variant))")
            }
        }

        // Thread list: push the first forum row in the sidebar.
        if pushFirstCell(fromScreen: "Forums") {
            measureScreen("Thread list (\(variant))", expectedTitleHints: [])

            // Posts view: the first thread row fills the detail pane.
            if pushFirstCell(fromScreen: "Thread list") {
                // Give the posts web view a moment; the nav chrome is what we
                // measure but the layout settles with the page.
                _ = app.webViews.firstMatch.waitForExistence(timeout: 10)
                measureScreen("Posts (\(variant))", expectedTitleHints: [], detailOnly: true)

                // The sidebar's thread-list bar again, now that opening a thread
                // has re-laid the split view out: its title must not have moved
                // (it used to slide right on the first open, the bar's later
                // layout correcting a placement made against half-sized items).
                if !isPhone {
                    let before = "Thread list (\(variant))"
                    let after = "Thread list after open (\(variant))"
                    measureScreen(after, expectedTitleHints: [])
                    let offset = { (screen: String) in
                        self.measurements.first { $0.screen == screen && $0.pane == "sidebar" && $0.metric == "title-h" }?.value
                    }
                    if let a = offset(before), let b = offset(after) {
                        let shift = b - a
                        let ok = abs(shift) <= 1
                        record(after, pane: "sidebar", metric: "title-shift", detail: "vs before the thread opened", value: shift, ok: ok, asserted: true)
                        XCTAssertEqual(b, a, accuracy: 1, "\(after): title moved \(fmt(shift))pt when the thread opened")
                    }
                }
            }

            // A second thread list with a short forum name, so the bar is
            // measured with a title that fits untruncated as well as with the
            // long one above.
            if popToForums(), let cell = forumCell(containing: Self.shortForumName) {
                cell.tap()
                _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)
                measureScreen("Thread list short (\(variant))", expectedTitleHints: [])
            } else {
                record("Thread list short (\(variant))", pane: "-", metric: "push",
                       detail: "no forum containing \"\(Self.shortForumName)\" found; skipped", value: nil, ok: true)
            }
        }
    }

    /// A forum with a short name, for the untruncated-title thread list. A
    /// top-level forum, so it is in the list without expanding a category.
    private static let shortForumName = "C-SPAM"

    /// Pops the sidebar (or the iPhone's stack) back to the Forums root by
    /// tapping Back until the bar's title is "Forums".
    private func popToForums() -> Bool {
        for _ in 0..<4 {
            if titleElement(in: sidebarNavigationBar() ?? app.navigationBars.firstMatch, hints: ["Forums"])?.label == "Forums" {
                return true
            }
            let bar = sidebarNavigationBar() ?? app.navigationBars.firstMatch
            let back = bar.buttons.matching(NSPredicate(format: "label == 'Back' OR identifier == 'BackButton'")).firstMatch
            guard back.waitForExistence(timeout: 2) else { return false }
            back.tap()
            usleep(600_000)
        }
        return false
    }

    /// The forum row whose name text contains `name` (the rows are custom
    /// cells; the name is a static text inside), paging the list down to find
    /// it (lists only expose rows on screen). Tapping the text taps the row.
    private func forumCell(containing name: String) -> XCUIElement? {
        let query = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", name))
        for _ in 0..<8 {
            let cell = query.firstMatch
            if cell.exists, cell.isHittable { return cell }
            let list = sidebarScrollableElement()
                ?? [app.collectionViews, app.tables].map(\.firstMatch).first { $0.exists }
            guard let list else { return nil }
            list.swipeUp()
        }
        return nil
    }

    // MARK: Navigation

    /// Confirms the launch argument reached the app by reading the Settings
    /// toggle, which mirrors the same user default. Without this a reduced-glass
    /// pass that silently measured normal glass would still pass.
    ///
    /// The toggle lives in the Themes section, well below the fold, and SwiftUI
    /// only exposes rows once they're on screen — so page the sidebar's own
    /// scroll view (never the detail pane) until it turns up. Settings has
    /// already been measured by now, so the scrolling is harmless. The toggle
    /// only exists on iOS 26, so a switch that never appears is recorded, not
    /// failed.
    private func verifyReduceLiquidGlassToggle(expected: Bool, screen: String) {
        let toggle = app.switches
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Reduce Liquid Glass"))
            .firstMatch
        var swipes = 0
        while !toggle.exists, swipes < 10, let list = sidebarScrollableElement() {
            list.swipeUp()
            swipes += 1
        }
        guard toggle.waitForExistence(timeout: 2) else {
            record(screen, pane: "-", metric: "glass-mode", detail: "Reduce Liquid Glass toggle not exposed; unverified", value: nil, ok: true)
            return
        }
        let isOn = (toggle.value as? String) == "1"
        let state = { (on: Bool) in on ? "on" : "off" }
        record(screen, pane: "-", metric: "glass-mode",
               detail: "Reduce Liquid Glass toggle \(state(isOn)), expected \(state(expected))",
               value: nil, ok: isOn == expected)
        XCTAssertEqual(isOn, expected,
                       "\(screen): Reduce Liquid Glass toggle is \(state(isOn)) but this pass expected \(state(expected))")
    }

    /// The sidebar column's scrolling content (Settings' Form, a table, …):
    /// the first scrollable element sitting under the sidebar nav bar.
    private func sidebarScrollableElement() -> XCUIElement? {
        guard let barFrame = sidebarNavigationBar()?.frame else { return nil }
        let candidates = [app.collectionViews, app.tables, app.scrollViews]
            .flatMap { $0.allElementsBoundByIndex }
        return candidates.first {
            $0.exists && $0.frame.width > 0
                && $0.frame.midX > barFrame.minX && $0.frame.midX < barFrame.maxX
        }
    }

    private func skipUnlessLoggedIn() throws {
        // State restoration can land anywhere — e.g. a posts view with the
        // sidebar hidden, where no tab bar exists in the hierarchy — so
        // summon the sidebar before concluding anything about login.
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 15) { return }
        revealSidebarIfHidden()
        if tabBar.waitForExistence(timeout: 5) { return }
        attach(screenshot: "no-tab-bar")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "element-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        throw XCTSkip("No tab bar found even after summoning the sidebar — either not logged in (log in manually, see Scripts/screenshot-matrix/README.md) or the tab bar isn't exposed as a tab bar; see the element-hierarchy attachment.")
    }

    @discardableResult
    private func selectTab(_ name: String, labels: [String], icon: String) -> Bool {
        // The Messages tab only exists when the account can send PMs.
        let tabBarFrame = app.tabBars.firstMatch.frame
        // The iPhone's iOS 26 tab bar buttons carry no label (only Messages
        // sets one), just their icon image with its asset name as identifier.
        let iconImage = app.tabBars.images[icon]
        if iconImage.waitForExistence(timeout: 2) {
            iconImage.tap()
            _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)
            return true
        }
        for label in labels {
            // The iPad sidebar exposes its tabs as the tab bar's buttons. The
            // iPhone's iOS 26 tab bar reports only its explicitly labelled
            // items (Messages) under `tabBars`; the rest surface as plain
            // buttons elsewhere in the tree, told apart by sitting inside the
            // tab bar's frame.
            let inTabBar = app.tabBars.buttons[label]
            let byPrefix = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH[c] %@ OR identifier BEGINSWITH[c] %@", label, label))
                .allElementsBoundByIndex
                .first { $0.exists && !tabBarFrame.isEmpty && tabBarFrame.intersects($0.frame) && $0.frame.width < tabBarFrame.width }
            let button = inTabBar.waitForExistence(timeout: 2) ? inTabBar : byPrefix
            if let button, button.exists {
                button.tap()
                _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)
                return true
            }
        }
        record("\(name)", pane: "-", metric: "tab", detail: "tab button not found; skipped", value: nil, ok: true)
        // The hierarchy explains how this tab bar exposes its items.
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "tab-lookup-\(name)"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        return false
    }

    /// In portrait the sidebar hides (.secondaryOnly / overlay); summon it via
    /// the system toggle so its nav bar exists to measure.
    private func revealSidebarIfHidden() {
        if isPhone || sidebarNavigationBar() != nil { return }

        // System toggle / the app's own show-sidebar button, by name.
        let candidates = [
            app.buttons["ToggleSidebar"],
            app.buttons["Show Sidebar"],
            app.buttons["Sidebar"],
            app.navigationBars.buttons["back"],
        ]
        for toggle in candidates where toggle.waitForExistence(timeout: 2) {
            toggle.tap()
            if sidebarAppeared() { return }
        }

        // The detail root's leading bar button is the app's show-sidebar
        // button whenever the sidebar is hidden (RootViewControllerStack's
        // backBarButtonItem), whatever it's exposed as.
        if let bar = detailNavigationBar() {
            let buttons = bar.buttons.allElementsBoundByIndex.filter { $0.exists && $0.frame.width > 0 }
            if let leading = buttons.min(by: { $0.frame.minX < $1.frame.minX }) {
                leading.tap()
                if sidebarAppeared() { return }
            }
        }

        // Last resort: rightward pan (AwfulSplitViewController's gesture).
        app.swipeRight()
        _ = sidebarAppeared()
    }

    private func sidebarAppeared() -> Bool {
        for _ in 0..<6 {
            if sidebarNavigationBar() != nil || app.tabBars.firstMatch.exists { return true }
            usleep(500_000)
        }
        return false
    }

    @discardableResult
    private func pushFirstCell(fromScreen screen: String) -> Bool {
        revealSidebarIfHidden()
        let cell = app.cells.firstMatch
        guard cell.waitForExistence(timeout: 10) else {
            record(screen, pane: "sidebar", metric: "push", detail: "no cell to tap; flow stops here", value: nil, ok: true)
            return false
        }
        cell.tap()
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)
        return true
    }

    // MARK: Pane identification

    /// The nav bar belonging to the sidebar column: leftmost bar no wider than
    /// the split view's maximum primary column width.
    private func sidebarNavigationBar() -> XCUIElement? {
        if isPhone { return navigationBars().first }
        return navigationBars().first { $0.frame.width <= Self.sidebarMaxWidth + 1 && $0.frame.minX < 50 }
    }

    /// The detail pane's nav bar: whichever visible bar isn't the sidebar's.
    /// State restoration can leave a stale full-window bar in the hierarchy
    /// (seen after launching with Settings selected), so among candidates
    /// take the one with the rightmost origin — the live detail bar starts
    /// at the sidebar's trailing edge in pinned mode, and in portrait
    /// overlay it's the only candidate anyway.
    private func detailNavigationBar() -> XCUIElement? {
        if isPhone { return nil }
        return navigationBars()
            .filter { $0.frame.width > Self.sidebarMaxWidth + 1 || $0.frame.minX >= 50 }
            .max { $0.frame.minX < $1.frame.minX }
    }

    private func navigationBars() -> [XCUIElement] {
        let bars = app.navigationBars.allElementsBoundByIndex
        return bars.filter { $0.exists && $0.frame.width > 0 }
    }

    // MARK: Measurement

    private func measureScreen(_ screen: String, expectedTitleHints: [String], detailOnly: Bool = false) {
        XCTContext.runActivity(named: screen) { _ in
            // Grab the pixels before poking at frames so the image matches
            // what was measured; overlays are drawn on afterward.
            let shot = XCUIScreen.main.screenshot().image
            overlays = []
            if isPhone {
                // One bar for everything; only the Posts screen (detailOnly)
                // must have a title, as on the iPad detail pane.
                if let bar = navigationBars().first {
                    measureBar(bar, pane: "bar", screen: screen, titleHints: expectedTitleHints, requireTitle: detailOnly)
                } else {
                    record(screen, pane: "bar", metric: "bar", detail: "no nav bar on screen", value: nil, ok: true)
                }
                attachAnnotated(shot, name: screen)
                return
            }
            if !detailOnly, let bar = sidebarNavigationBar() {
                measureBar(bar, pane: "sidebar", screen: screen, titleHints: expectedTitleHints)
            } else if !detailOnly {
                record(screen, pane: "sidebar", metric: "bar", detail: "sidebar nav bar not on screen", value: nil, ok: true)
            }
            if let bar = detailNavigationBar() {
                // A detail pane with nothing loaded (fresh launch, no thread
                // selected) legitimately has no title, so only the Posts
                // screen — where the test navigated to real content — treats
                // a missing detail title as a failure.
                measureBar(bar, pane: "detail", screen: screen, titleHints: expectedTitleHints,
                           acceptablePanes: detailPaneRects(for: bar), requireTitle: detailOnly)
            }
            attachAnnotated(shot, name: screen)
        }
    }

    /// The pane rectangles a detail title may legitimately center on.
    /// Usually just the bar's own frame — but the split view's states
    /// diverge: on iOS 26 the detail bar element can report a full-window
    /// frame while its title is centered on the visible pane beside the
    /// sidebar, and in portrait overlay the title is correctly centered on
    /// the full window underneath the sidebar. When the bar and sidebar
    /// overlap, accept either pane; a title matching neither is a real
    /// misalignment. The chosen pane is also what the margin annotations
    /// measure from, so lines never run underneath the sidebar.
    private func detailPaneRects(for bar: XCUIElement) -> [CGRect] {
        let frame = bar.frame
        var panes = [frame]
        if let side = sidebarNavigationBar()?.frame, frame.minX < side.maxX - 1 {
            let leading = side.maxX + side.minX  // mirror the sidebar's own gutter
            if frame.maxX > leading {
                panes.append(CGRect(x: leading, y: frame.minY, width: frame.maxX - leading, height: frame.height))
            }
        }
        return panes
    }

    private func measureBar(_ bar: XCUIElement, pane: String, screen: String, titleHints: [String],
                            acceptablePanes: [CGRect]? = nil, requireTitle: Bool = true) {
        let barFrame = bar.frame
        let panes = acceptablePanes ?? [barFrame]
        let buttons = bar.buttons.allElementsBoundByIndex.filter { $0.exists && $0.frame.width > 0 }
        let title = titleElement(in: bar, hints: titleHints)

        guard let title, title.frame.width > 0 else {
            if requireTitle {
                record(screen, pane: pane, metric: "title", detail: "no title element exposed", value: nil, ok: false)
                XCTFail("\(screen) \(pane): no title element exposed")
            } else {
                record(screen, pane: pane, metric: "title", detail: "no title (empty pane); skipped", value: nil, ok: true)
            }
            measureButtons(buttons, paneRect: barFrame, titleFrame: nil, screen: screen, pane: pane)
            return
        }
        let titleFrame = title.frame

        // title-h: title center vs pane center (against the nearest acceptable
        // center when the split view offers more than one). A title that can't
        // be centered clear of the item clusters is slid toward the center
        // until it meets the nearer cluster (SidebarTitleView) — accepted only
        // when it really is pinned there, so a snug leading-anchored title (the
        // original bug) and text sitting off-center inside a wide container
        // both still fail. Detail titles are the system's: same rule.
        let centers = panes.map(\.midX)
        var paneCenter = centers.min { abs(titleFrame.midX - $0) < abs(titleFrame.midX - $1) } ?? barFrame.midX
        var pinnedNote = ""
        if abs(titleFrame.midX - paneCenter) > Self.horizontalTolerance {
            let leadEdge = buttons.filter { $0.frame.midX < paneCenter }.map(\.frame.maxX).max() ?? barFrame.minX
            let trailEdge = buttons.filter { $0.frame.midX > paneCenter }.map(\.frame.minX).min() ?? barFrame.maxX
            let pinnedTrailing = titleFrame.midX < paneCenter && trailEdge - titleFrame.maxX <= Self.pinnedGapMax
            let pinnedLeading = titleFrame.midX > paneCenter && titleFrame.minX - leadEdge <= Self.pinnedGapMax
            record(screen, pane: pane, metric: "pinned-diag",
                   detail: "lead \(fmt(leadEdge)) trail \(fmt(trailEdge)) title \(fmt(titleFrame.minX))–\(fmt(titleFrame.maxX))",
                   value: nil, ok: true)
            if pinnedTrailing || pinnedLeading {
                paneCenter = titleFrame.midX
                pinnedNote = pinnedTrailing && pinnedLeading ? " (fills the span; truncated)"
                    : pinnedTrailing ? " (pinned to trailing cluster)" : " (pinned to leading cluster)"
            }
        }
        // The pane whose center the verdict effectively used — margins and
        // the drawn measurement lines come from this rect, so they reflect
        // the judged pane rather than the bar element's raw frame (which on
        // iOS 26 can span the full window, sidebar included).
        let chosenPane = panes.min { abs($0.midX - paneCenter) < abs($1.midX - paneCenter) } ?? barFrame
        let hOffset = titleFrame.midX - paneCenter
        let hOK = abs(hOffset) <= Self.horizontalTolerance
        record(screen, pane: pane, metric: "title-h", detail: "\"\(title.label.prefix(30))\" center offset\(pinnedNote)", value: hOffset, ok: hOK)
        XCTAssertEqual(titleFrame.midX, paneCenter, accuracy: Self.horizontalTolerance,
                       "\(screen) \(pane): title horizontally off-center by \(fmt(hOffset))pt")

        // Overlays: pane outline + centerline, title box with its center
        // offset, and a measured margin line from each side of the pane to
        // the title.
        overlays.append(.box(chosenPane, .systemGray, label: nil))
        overlays.append(.vline(x: paneCenter, fromY: chosenPane.minY, toY: chosenPane.maxY + 24, color: .systemRed, dashed: true))
        overlays.append(.box(titleFrame, hOK ? .systemGreen : .systemRed,
                             label: "Δ\(fmt(hOffset))pt" + (hOK ? "" : " OFF-CENTER")))
        // title-span: the wider container the text sits in, when there is
        // one. The text box above is the accessibility frame of the rendered
        // label, which for a truncated title can run a few points short of
        // the glyphs; the span shows how much room the title view was
        // actually granted, so the two together explain a pinned title.
        if let container = titleContainer(in: bar, matching: title) {
            let span = container.frame
            record(screen, pane: pane, metric: "title-span",
                   detail: "container \(fmt(span.minX))–\(fmt(span.maxX)), text \(fmt(titleFrame.minX))–\(fmt(titleFrame.maxX))",
                   value: span.width, ok: true)
            overlays.append(.box(span.insetBy(dx: -1, dy: -1), .systemGray, label: nil))
        }
        overlays.append(.hline(y: titleFrame.midY, fromX: chosenPane.minX, toX: titleFrame.minX,
                               color: .systemRed, label: "\(fmt(titleFrame.minX - chosenPane.minX))pt"))
        overlays.append(.hline(y: titleFrame.midY, fromX: titleFrame.maxX, toX: chosenPane.maxX,
                               color: .systemRed, label: "\(fmt(chosenPane.maxX - titleFrame.maxX))pt"))
        // Button boxes are drawn after measureButtons has judged them (see the
        // end of this method), so a box can carry its verdict colour.

        // title-v: title center vs each button center.
        for button in buttons {
            let vOffset = titleFrame.midY - button.frame.midY
            let vOK = abs(vOffset) <= Self.verticalTolerance
            record(screen, pane: pane, metric: "title-v", detail: "vs \(buttonName(button))", value: vOffset, ok: vOK, asserted: true)
            XCTAssertEqual(titleFrame.midY, button.frame.midY, accuracy: Self.verticalTolerance,
                           "\(screen) \(pane): title vertically misaligned with \(buttonName(button)) by \(fmt(vOffset))pt")
        }

        // overlap: title vs any button.
        var overlapped = false
        for button in buttons {
            let overlap = titleFrame.intersection(button.frame)
            if !overlap.isNull, overlap.width > 0.5, overlap.height > 0.5 {
                overlapped = true
                record(screen, pane: pane, metric: "overlap", detail: "with \(buttonName(button))", value: overlap.width, ok: false)
                XCTFail("\(screen) \(pane): title overlaps \(buttonName(button)) by \(fmt(overlap.width))pt")
            }
        }
        if !overlapped {
            record(screen, pane: pane, metric: "overlap", detail: "none", value: 0, ok: true)
        }

        measureButtons(buttons, paneRect: chosenPane, titleFrame: titleFrame, screen: screen, pane: pane)
    }

    /// Outlines each button in its verdict colour: green when every asserted
    /// measurement that names it passed, red when one failed, blue when none
    /// was asserted. Called from measureButtons once the verdicts are in.
    private func drawButtonBoxes(_ buttons: [XCUIElement], screen: String, pane: String) {
        for button in buttons {
            let name = buttonName(button)
            let judged = measurements.filter {
                $0.screen == screen && $0.pane == pane && $0.asserted && $0.detail.contains(name)
            }
            let color: UIColor = judged.isEmpty ? .systemBlue : (judged.allSatisfy(\.ok) ? .systemGreen : .systemRed)
            overlays.append(.box(button.frame, color, label: nil))
        }
    }

    /// Button geometry. Components (buttons plus the title, when there is
    /// one) are walked leading to trailing so each gap is measured once,
    /// between neighbours; the outermost buttons are also measured against
    /// the pane edge on their side. Every gap is drawn on the screenshot
    /// just under the buttons' baseline so the lines don't sit on the
    /// title's own margin lines.
    ///
    /// Metrics: `btn-size` (width, detail holds w×h), `edge-lead` /
    /// `edge-trail` (outermost button to its pane edge, asserted against
    /// `edgeGapRange` on the sidebar; recorded only on the detail pane, whose
    /// leading edge can be covered by the sidebar), `gap` (between
    /// neighbouring components; fails only when they overlap), and
    /// `contained` (a button escaping the bar).
    /// Colour for a drawn button measurement: green or red when the value was
    /// asserted (pass/fail), blue when it was only recorded.
    private func verdictColor(asserted: Bool, ok: Bool) -> UIColor {
        asserted ? (ok ? .systemGreen : .systemRed) : .systemBlue
    }

    private func measureButtons(_ buttons: [XCUIElement], paneRect: CGRect, titleFrame: CGRect?, screen: String, pane: String) {
        guard !buttons.isEmpty else {
            record(screen, pane: pane, metric: "btn-size", detail: "no buttons", value: nil, ok: true)
            return
        }

        // btn-size: each button's platter, leading to trailing.
        let sorted = buttons.sorted { $0.frame.minX < $1.frame.minX }
        for button in sorted {
            let f = button.frame
            record(screen, pane: pane, metric: "btn-size",
                   detail: "\(buttonName(button)) \(fmt(f.width))×\(fmt(f.height)) at x \(fmt(f.minX))",
                   value: f.width, ok: true)
        }

        // Components in bar order: buttons and the title. Name + frame.
        var components: [(name: String, frame: CGRect)] = sorted.map { (buttonName($0), $0.frame) }
        if let titleFrame, titleFrame.width > 0 {
            components.append(("title", titleFrame))
            components.sort { $0.frame.minX < $1.frame.minX }
        }
        let lineY = (sorted.map(\.frame.maxY).max() ?? paneRect.maxY) - 3

        // edge-lead / edge-trail: outermost button to its own pane edge.
        // Only when a button really is the outermost component on that side,
        // so a leading-only bar (an empty detail pane's show-sidebar button)
        // never reports a several-hundred-point "trailing gap".
        let leadingIsButton = components.first?.name != "title"
        let trailingIsButton = components.last?.name != "title"
        if leadingIsButton, let first = components.first {
            let gap = first.frame.minX - paneRect.minX
            // A detail bar in portrait overlay starts under the sidebar; its
            // leading button then sits well inside the judged pane. Assert on
            // the sidebar, record elsewhere.
            let asserted = pane == "sidebar"
            let ok = !asserted || Self.edgeGapRange.contains(gap)
            record(screen, pane: pane, metric: "edge-lead", detail: "pane edge → \(first.name)", value: gap, ok: ok, asserted: asserted)
            XCTAssertTrue(ok, "\(screen) \(pane): leading gap before \(first.name) is \(fmt(gap))pt, expected \(Self.edgeGapRange)")
            overlays.append(.hline(y: lineY, fromX: paneRect.minX, toX: first.frame.minX,
                                   color: verdictColor(asserted: asserted, ok: ok), label: "\(fmt(gap))pt"))
        }
        // A bar whose only button sits on the leading half (an empty detail
        // pane's show-sidebar button) has no trailing button to measure.
        if trailingIsButton, let last = components.last, last.frame.midX > paneRect.midX {
            let gap = paneRect.maxX - last.frame.maxX
            // Sidebar only, like the leading edge: an iPhone bar in landscape
            // insets its items from the Dynamic Island side by ~40pt.
            let asserted = pane == "sidebar"
            let ok = !asserted || Self.edgeGapRange.contains(gap)
            record(screen, pane: pane, metric: "edge-trail", detail: "\(last.name) → pane edge", value: gap, ok: ok, asserted: asserted)
            XCTAssertTrue(ok, "\(screen) \(pane): trailing gap after \(last.name) is \(fmt(gap))pt, expected \(Self.edgeGapRange)")
            overlays.append(.hline(y: lineY, fromX: last.frame.maxX, toX: paneRect.maxX,
                                   color: verdictColor(asserted: asserted, ok: ok), label: "\(fmt(gap))pt"))
        } else if trailingIsButton {
            record(screen, pane: pane, metric: "edge-trail", detail: "no trailing-side buttons", value: nil, ok: true)
        }

        // gap: between each pair of neighbouring components. Two buttons on
        // the sidebar's trailing side must sit `clusterSpacing` apart (the
        // evenly spaced cluster, toggle included); any other button pair
        // fails only when it overlaps. Title/button gaps are recorded, not
        // judged — the title's placement is measureBar's business.
        for (lhs, rhs) in zip(components, components.dropFirst()) {
            let gap = rhs.frame.minX - lhs.frame.maxX
            let bothButtons = lhs.name != "title" && rhs.name != "title"
            let trailingPair = bothButtons && pane == "sidebar"
                && lhs.frame.midX > paneRect.midX && rhs.frame.midX > paneRect.midX
            let ok: Bool
            if trailingPair {
                ok = abs(gap - Self.clusterSpacing) <= Self.clusterSpacingTolerance
            } else {
                ok = gap >= -0.5 || !bothButtons
            }
            record(screen, pane: pane, metric: "gap", detail: "\(lhs.name) → \(rhs.name)", value: gap, ok: ok, asserted: trailingPair || !ok)
            if trailingPair {
                XCTAssertEqual(gap, Self.clusterSpacing, accuracy: Self.clusterSpacingTolerance,
                               "\(screen) \(pane): \(lhs.name) → \(rhs.name) gap is \(fmt(gap))pt, expected \(fmt(Self.clusterSpacing))pt")
            } else if !ok {
                XCTFail("\(screen) \(pane): \(lhs.name) overlaps \(rhs.name) by \(fmt(-gap))pt")
            }
            if gap > 0.5 {
                overlays.append(.hline(y: lineY, fromX: lhs.frame.maxX, toX: rhs.frame.minX,
                                       color: verdictColor(asserted: trailingPair, ok: ok), label: "\(fmt(gap))pt"))
            }
        }

        // contained: every button inside the pane.
        for button in buttons where !paneRect.insetBy(dx: -1, dy: -1).contains(button.frame) {
            record(screen, pane: pane, metric: "contained", detail: buttonName(button), value: nil, ok: false, asserted: true)
            XCTFail("\(screen) \(pane): \(buttonName(button)) escapes the nav bar: \(button.frame) vs \(paneRect)")
        }

        drawButtonBoxes(buttons, screen: screen, pane: pane)
    }

    private func titleTexts(in bar: XCUIElement) -> [XCUIElement] {
        bar.staticTexts.allElementsBoundByIndex.filter { $0.exists && $0.frame.width > 0 }
    }

    /// The rendered title text. The title can surface as a nested
    /// container/text pair with the same label (the SwiftUI hosting wrapper
    /// enclosing the real label), and only the inner one is the rendered
    /// text — SidebarTitleView shifts its content within the container, so
    /// the container's frame is meaningless for alignment. Pick the label
    /// from the hints (else the widest text's), then take the narrowest
    /// element carrying it.
    private func titleElement(in bar: XCUIElement, hints: [String]) -> XCUIElement? {
        let texts = titleTexts(in: bar)
        let label = hints.first { hint in texts.contains { $0.label == hint } }
            ?? texts.max(by: { $0.frame.width < $1.frame.width })?.label
        guard let label else { return nil }
        return texts.filter { $0.label == label }.min { $0.frame.width < $1.frame.width }
    }

    /// The widest same-label element enclosing the title text — the granted
    /// title-view span when the title exposes a container/text pair. Nil
    /// when the title is a single element (nothing wider than itself).
    private func titleContainer(in bar: XCUIElement, matching title: XCUIElement) -> XCUIElement? {
        let widest = titleTexts(in: bar).filter { $0.label == title.label }
            .max { $0.frame.width < $1.frame.width }
        guard let widest, widest.frame.width > title.frame.width + 0.5 else { return nil }
        return widest
    }

    private func buttonName(_ button: XCUIElement) -> String {
        let id = button.identifier
        if !id.isEmpty { return id }
        let label = button.label
        return label.isEmpty ? "(unnamed button)" : label
    }

    // MARK: Reporting

    private func record(_ screen: String, pane: String, metric: String, detail: String, value: CGFloat?, ok: Bool, asserted: Bool = false) {
        measurements.append(Measurement(screen: screen, pane: pane, metric: metric, detail: detail, value: value, ok: ok, asserted: asserted))
    }

    private func printReport() {
        guard !measurements.isEmpty else { return }
        func pad(_ s: String, _ width: Int) -> String {
            s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
        }
        var lines = ["", "=== Alignment report ==="]
        lines.append(pad("screen", 40) + pad("pane", 9) + pad("metric", 12) + pad("points", 9) + pad("ok", 6) + "detail")
        for m in measurements {
            let value = m.value.map { fmt($0) } ?? "-"
            lines.append(pad(m.screen, 40) + pad(m.pane, 9) + pad(m.metric, 12) + pad(value, 9)
                         + pad(m.ok ? "OK" : "FAIL", 6) + m.detail)
        }
        lines.append("========================")
        print(lines.joined(separator: "\n"))
    }

    private func fmt(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }

    private func attach(screenshot name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: Screenshot annotation

    /// Renders the collected overlays onto the screenshot and attaches the
    /// result. The canvas is the app frame in interface-orientation points;
    /// landscape screenshots arrive portrait-native and are rotated to match
    /// (the tests always use .landscapeLeft, i.e. interface landscape-right,
    /// so one fixed rotation suffices).
    private func attachAnnotated(_ shot: UIImage, name: String) {
        let canvas = app.frame.size
        guard canvas.width > 0, canvas.height > 0 else { return }
        drawnLabelRects = []
        annotationCanvasWidth = canvas.width
        let renderer = UIGraphicsImageRenderer(size: canvas)
        let annotated = renderer.image { context in
            let cg = context.cgContext
            let imageIsPortrait = shot.size.height >= shot.size.width
            let canvasIsPortrait = canvas.height >= canvas.width
            if imageIsPortrait == canvasIsPortrait {
                shot.draw(in: CGRect(origin: .zero, size: canvas))
            } else {
                // Portrait-native buffer under a landscape-right interface:
                // the screen's top edge lies along the image's right edge,
                // so a 90° counterclockwise rotation puts it upright.
                cg.saveGState()
                cg.translateBy(x: 0, y: canvas.height)
                cg.rotate(by: -.pi / 2)
                shot.draw(in: CGRect(x: 0, y: 0, width: canvas.height, height: canvas.width))
                cg.restoreGState()
            }
            // Lines and boxes first, labels in a second pass on top — a
            // button box drawn after a label used to slice through its text.
            pendingLabels = []
            for overlay in overlays {
                draw(overlay, in: cg)
            }
            for label in pendingLabels {
                renderLabel(label.text, at: label.point, color: label.color)
            }
        }
        let attachment = XCTAttachment(image: annotated)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func draw(_ overlay: Overlay, in cg: CGContext) {
        cg.setLineWidth(1)
        cg.setLineDash(phase: 0, lengths: [])
        switch overlay {
        case let .box(rect, color, label):
            cg.setStrokeColor(color.cgColor)
            cg.stroke(rect)
            if let label {
                drawLabel(label, at: CGPoint(x: rect.minX, y: max(0, rect.minY - 14)), color: color)
            }

        case let .hline(y, fromX, toX, color, label):
            guard toX - fromX > 0.5 else { break }
            cg.setStrokeColor(color.cgColor)
            cg.move(to: CGPoint(x: fromX, y: y))
            cg.addLine(to: CGPoint(x: toX, y: y))
            // End ticks, so it reads as a measurement.
            for x in [fromX, toX] {
                cg.move(to: CGPoint(x: x, y: y - 4))
                cg.addLine(to: CGPoint(x: x, y: y + 4))
            }
            cg.strokePath()
            drawLabel(label, at: CGPoint(x: (fromX + toX) / 2 - 12, y: y + 5), color: color)

        case let .vline(x, fromY, toY, color, dashed):
            cg.setStrokeColor(color.cgColor)
            if dashed { cg.setLineDash(phase: 0, lengths: [4, 3]) }
            cg.move(to: CGPoint(x: x, y: fromY))
            cg.addLine(to: CGPoint(x: x, y: toY))
            cg.strokePath()
            cg.setLineDash(phase: 0, lengths: [])
        }
    }

    /// Labels already placed on the current screenshot, so later ones can
    /// dodge them instead of printing on top and blending the numbers.
    private var drawnLabelRects: [CGRect] = []
    private var annotationCanvasWidth: CGFloat = 0
    private var pendingLabels: [(text: String, point: CGPoint, color: UIColor)] = []

    /// Queues a label for the second (topmost) drawing pass.
    private func drawLabel(_ text: String, at point: CGPoint, color: UIColor) {
        pendingLabels.append((text, point, color))
    }

    private func renderLabel(_ text: String, at point: CGPoint, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: color,
            .backgroundColor: UIColor.white.withAlphaComponent(0.85),
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()

        // Keep the label on the canvas, then slide it down in line-height
        // steps until it stops intersecting anything already drawn.
        var origin = point
        if annotationCanvasWidth > 0 {
            origin.x = max(2, min(origin.x, annotationCanvasWidth - size.width - 2))
        }
        origin.y = max(0, origin.y)
        for _ in 0..<8 {
            let candidate = CGRect(origin: origin, size: size).insetBy(dx: -2, dy: -1)
            if !drawnLabelRects.contains(where: { $0.intersects(candidate) }) { break }
            origin.y += size.height + 2
        }
        drawnLabelRects.append(CGRect(origin: origin, size: size).insetBy(dx: -2, dy: -1))
        string.draw(at: origin)
    }
}
