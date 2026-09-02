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
/// are measured, never tapped — no compose screen is ever opened.
///
/// Caveat: metrics come from accessibility frames, which don't move with
/// render-only shifts like SwiftUI `.offset` (e.g. the sidebar compose
/// button's visualOffsetX nudge in NavigationController). Purely visual
/// misalignment must be judged from the attached screenshots.
final class SidebarAlignmentTests: XCTestCase {

    // MARK: Tolerances (points)

    /// Title's horizontal center vs. its pane's center.
    private static let horizontalTolerance: CGFloat = 4
    /// Title's vertical center vs. each bar button's vertical center.
    private static let verticalTolerance: CGFloat = 2
    /// Acceptable range for the gap between the trailing bar button and the
    /// pane's trailing edge. Negative means the button overhangs the pane.
    private static let trailingGapRange: ClosedRange<CGFloat> = 4...24

    /// The split view's maximumPrimaryColumnWidth (RootViewControllerStack),
    /// used to tell the sidebar nav bar from the detail pane's.
    private static let sidebarMaxWidth: CGFloat = 350
    /// Bars narrower than this (iPad mini portrait overlay ≈ 256pt) can't
    /// center a title clear of the trailing cluster; the app gap-centers
    /// there instead. Mirrors SidebarTitleView.narrowBarWidthThreshold.
    private static let narrowBarWidth: CGFloat = 300

    private var app: XCUIApplication!
    private var measurements: [Measurement] = []
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
        // (name, tab-button labels to try, nav title hints)
        let tabs: [(String, [String], [String])] = [
            ("Bookmarks", ["Bookmarks"], ["Bookmarks"]),
            // The tab item's accessibilityLabel is "Private messages"
            // (MessageListViewController); the nav title is "Messages".
            ("Messages", ["Private messages", "Messages"], ["Messages"]),
            ("Lepers", ["Lepers"], ["Leper’s Colony"]),
            ("Settings", ["Settings"], ["Settings"]),
            ("Forums", ["Forums"], ["Forums"]),
        ]
        for (name, labels, hints) in tabs {
            guard selectTab(name, labels: labels) else { continue }
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
            }
        }
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
    private func selectTab(_ name: String, labels: [String]) -> Bool {
        // The Messages tab only exists when the account can send PMs.
        for label in labels {
            let button = app.tabBars.buttons[label]
            if button.waitForExistence(timeout: 5) {
                button.tap()
                _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)
                return true
            }
        }
        record("\(name)", pane: "-", metric: "tab", detail: "tab button not found; skipped", value: nil, ok: true)
        return false
    }

    /// In portrait the sidebar hides (.secondaryOnly / overlay); summon it via
    /// the system toggle so its nav bar exists to measure.
    private func revealSidebarIfHidden() {
        if sidebarNavigationBar() != nil { return }

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
        navigationBars().first { $0.frame.width <= Self.sidebarMaxWidth + 1 && $0.frame.minX < 50 }
    }

    /// The detail pane's nav bar: whichever visible bar isn't the sidebar's.
    /// State restoration can leave a stale full-window bar in the hierarchy
    /// (seen after launching with Settings selected), so among candidates
    /// take the one with the rightmost origin — the live detail bar starts
    /// at the sidebar's trailing edge in pinned mode, and in portrait
    /// overlay it's the only candidate anyway.
    private func detailNavigationBar() -> XCUIElement? {
        navigationBars()
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
            measureButtons(buttons, barFrame: barFrame, titleFrame: nil, screen: screen, pane: pane)
            return
        }
        let titleFrame = title.frame

        // title-h: title center vs pane center (against the nearest
        // acceptable center when the split view offers more than one).
        // A title centered within its own granted container is also
        // legitimate: on narrow bars (iPad mini portrait, ≈256pt) and in
        // some overlay states, UIKit grants the title view a span between
        // the item clusters that can't sit on the pane's center, and the
        // app centers the text in that span. The container counts only
        // when it's meaningfully wider than the text (fill-mode signature),
        // so a snug leading-anchored title — the original bug — still
        // fails, as does text sitting off-center inside a wide container.
        var centers = panes.map(\.midX)
        if let container = titleContainer(in: bar, matching: title),
           container.frame.width >= titleFrame.width + 20 {
            centers.append(container.frame.midX)
        }
        // On a bar too narrow to center anything, a long title that fills
        // the whole inter-cluster gap has nowhere better to be — accept it
        // as-is. Narrow bars only: on wide bars filling a lopsided gap was
        // the original off-center bug and must keep failing. The diag row
        // records the compared edges, for judging any flaky run at a glance.
        if barFrame.width < Self.narrowBarWidth {
            let leadEdge = buttons.filter { $0.frame.midX < barFrame.midX }
                .map(\.frame.maxX).max() ?? barFrame.minX
            let trailEdge = buttons.filter { $0.frame.midX > barFrame.midX }
                .map(\.frame.minX).min() ?? barFrame.maxX
            // ±40pt: the mini's overlay-state layout varies a little from
            // run to run, and on a bar this narrow a title within 40pt of
            // both clusters has no meaningfully better position anyway.
            if titleFrame.minX <= leadEdge + 40, titleFrame.maxX >= trailEdge - 40 {
                centers.append(titleFrame.midX)
            }
            record(screen, pane: pane, metric: "narrow-diag",
                   detail: "lead \(fmt(leadEdge)) trail \(fmt(trailEdge)) title \(fmt(titleFrame.minX))–\(fmt(titleFrame.maxX))",
                   value: nil, ok: true)
        }
        let paneCenter = centers.min { abs(titleFrame.midX - $0) < abs(titleFrame.midX - $1) } ?? barFrame.midX
        // The pane whose center the verdict effectively used — margins and
        // the drawn measurement lines come from this rect, so they reflect
        // the judged pane rather than the bar element's raw frame (which on
        // iOS 26 can span the full window, sidebar included).
        let chosenPane = panes.min { abs($0.midX - paneCenter) < abs($1.midX - paneCenter) } ?? barFrame
        let hOffset = titleFrame.midX - paneCenter
        let hOK = abs(hOffset) <= Self.horizontalTolerance
        record(screen, pane: pane, metric: "title-h", detail: "\"\(title.label.prefix(30))\" center offset", value: hOffset, ok: hOK)
        XCTAssertEqual(titleFrame.midX, paneCenter, accuracy: Self.horizontalTolerance,
                       "\(screen) \(pane): title horizontally off-center by \(fmt(hOffset))pt")

        // Overlays: pane outline + centerline, title box with its center
        // offset, and a measured margin line from each side of the pane to
        // the title.
        overlays.append(.box(chosenPane, .systemGray, label: nil))
        overlays.append(.vline(x: paneCenter, fromY: chosenPane.minY, toY: chosenPane.maxY + 24, color: .systemRed, dashed: true))
        overlays.append(.box(titleFrame, hOK ? .systemGreen : .systemRed,
                             label: "Δ\(fmt(hOffset))pt" + (hOK ? "" : " OFF-CENTER")))
        overlays.append(.hline(y: titleFrame.midY, fromX: chosenPane.minX, toX: titleFrame.minX,
                               color: .systemRed, label: "\(fmt(titleFrame.minX - chosenPane.minX))pt"))
        overlays.append(.hline(y: titleFrame.midY, fromX: titleFrame.maxX, toX: chosenPane.maxX,
                               color: .systemRed, label: "\(fmt(chosenPane.maxX - titleFrame.maxX))pt"))
        for button in buttons {
            overlays.append(.box(button.frame, .systemBlue, label: nil))
        }

        // title-v: title center vs each button center.
        for button in buttons {
            let vOffset = titleFrame.midY - button.frame.midY
            let vOK = abs(vOffset) <= Self.verticalTolerance
            record(screen, pane: pane, metric: "title-v", detail: "vs \(buttonName(button))", value: vOffset, ok: vOK)
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

        measureButtons(buttons, barFrame: barFrame, titleFrame: titleFrame, screen: screen, pane: pane)
    }

    private func measureButtons(_ buttons: [XCUIElement], barFrame: CGRect, titleFrame: CGRect?, screen: String, pane: String) {
        // btn-gap: trailing button's edge to the pane's trailing edge.
        // Only buttons actually on the trailing side count — an empty detail
        // pane's lone leading (show-sidebar) button would otherwise measure
        // a meaningless several-hundred-point "gap".
        let trailingSide = buttons.filter { $0.frame.midX > barFrame.midX }
        if let trailing = trailingSide.max(by: { $0.frame.maxX < $1.frame.maxX }) {
            let gap = barFrame.maxX - trailing.frame.maxX
            let ok = Self.trailingGapRange.contains(gap)
            record(screen, pane: pane, metric: "btn-gap", detail: buttonName(trailing), value: gap, ok: ok)
            XCTAssertTrue(ok, "\(screen) \(pane): trailing gap after \(buttonName(trailing)) is \(fmt(gap))pt, expected \(Self.trailingGapRange)")
        } else if !buttons.isEmpty {
            record(screen, pane: pane, metric: "btn-gap", detail: "no trailing-side buttons", value: nil, ok: true)
        }

        // contained: every button inside the pane.
        for button in buttons where !barFrame.insetBy(dx: -1, dy: -1).contains(button.frame) {
            record(screen, pane: pane, metric: "contained", detail: buttonName(button), value: nil, ok: false)
            XCTFail("\(screen) \(pane): \(buttonName(button)) escapes the nav bar: \(button.frame) vs \(barFrame)")
        }
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
    /// title-view span when the title exposes a container/text pair.
    private func titleContainer(in bar: XCUIElement, matching title: XCUIElement) -> XCUIElement? {
        titleTexts(in: bar).filter { $0.label == title.label }.max { $0.frame.width < $1.frame.width }
    }

    private func buttonName(_ button: XCUIElement) -> String {
        let id = button.identifier
        if !id.isEmpty { return id }
        let label = button.label
        return label.isEmpty ? "(unnamed button)" : label
    }

    // MARK: Reporting

    private func record(_ screen: String, pane: String, metric: String, detail: String, value: CGFloat?, ok: Bool) {
        measurements.append(Measurement(screen: screen, pane: pane, metric: metric, detail: detail, value: value, ok: ok))
    }

    private func printReport() {
        guard !measurements.isEmpty else { return }
        func pad(_ s: String, _ width: Int) -> String {
            s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
        }
        var lines = ["", "=== Alignment report ==="]
        lines.append(pad("screen", 40) + pad("pane", 9) + pad("metric", 11) + pad("points", 9) + pad("ok", 6) + "detail")
        for m in measurements {
            let value = m.value.map { fmt($0) } ?? "-"
            lines.append(pad(m.screen, 40) + pad(m.pane, 9) + pad(m.metric, 11) + pad(value, 9)
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
