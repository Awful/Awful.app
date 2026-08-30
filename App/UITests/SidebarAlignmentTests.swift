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

    // MARK: Pass

    private func runAlignmentPass(orientation: UIDeviceOrientation, name orientationName: String) throws {
        XCUIDevice.shared.orientation = orientation
        app.launch()
        try skipUnlessLoggedIn()

        // Tab roots first (Forums last so the push flows continue from it).
        // (name, tab-button labels to try, nav title hints)
        let tabs: [(String, [String], [String])] = [
            ("Bookmarks", ["Bookmarks"], ["Bookmarks"]),
            // The tab item's accessibilityLabel is "Private messages"
            // (MessageListViewController); the nav title is "Messages".
            ("Messages", ["Private messages", "Messages"], ["Messages"]),
            ("Lepers", ["Lepers"], ["Leper’s Colony"]),
            ("Forums", ["Forums"], ["Forums"]),
        ]
        for (name, labels, hints) in tabs {
            guard selectTab(name, labels: labels) else { continue }
            revealSidebarIfHidden()
            measureScreen("\(name) (\(orientationName))", expectedTitleHints: hints)
        }

        // Thread list: push the first forum row in the sidebar.
        if pushFirstCell(fromScreen: "Forums") {
            measureScreen("Thread list (\(orientationName))", expectedTitleHints: [])

            // Posts view: the first thread row fills the detail pane.
            if pushFirstCell(fromScreen: "Thread list") {
                // Give the posts web view a moment; the nav chrome is what we
                // measure but the layout settles with the page.
                _ = app.webViews.firstMatch.waitForExistence(timeout: 10)
                measureScreen("Posts (\(orientationName))", expectedTitleHints: [], detailOnly: true)
            }
        }
    }

    // MARK: Navigation

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
    private func detailNavigationBar() -> XCUIElement? {
        navigationBars().first { $0.frame.width > Self.sidebarMaxWidth + 1 || $0.frame.minX >= 50 }
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
                measureBar(bar, pane: "detail", screen: screen, titleHints: expectedTitleHints)
            }
            attachAnnotated(shot, name: screen)
        }
    }

    private func measureBar(_ bar: XCUIElement, pane: String, screen: String, titleHints: [String]) {
        let barFrame = bar.frame
        let buttons = bar.buttons.allElementsBoundByIndex.filter { $0.exists && $0.frame.width > 0 }
        let title = titleElement(in: bar, hints: titleHints)

        guard let title, title.frame.width > 0 else {
            record(screen, pane: pane, metric: "title", detail: "no title element exposed", value: nil, ok: false)
            measureButtons(buttons, barFrame: barFrame, titleFrame: nil, screen: screen, pane: pane)
            return
        }
        let titleFrame = title.frame

        // title-h: title center vs pane center.
        let hOffset = titleFrame.midX - barFrame.midX
        let hOK = abs(hOffset) <= Self.horizontalTolerance
        record(screen, pane: pane, metric: "title-h", detail: "\"\(title.label.prefix(30))\" center offset", value: hOffset, ok: hOK)
        XCTAssertEqual(titleFrame.midX, barFrame.midX, accuracy: Self.horizontalTolerance,
                       "\(screen) \(pane): title horizontally off-center by \(fmt(hOffset))pt")

        // Overlays: pane outline + centerline, title box with its center
        // offset, and a measured margin line from each side of the pane to
        // the title.
        overlays.append(.box(barFrame, .systemGray, label: nil))
        overlays.append(.vline(x: barFrame.midX, fromY: barFrame.minY, toY: barFrame.maxY + 24, color: .systemRed, dashed: true))
        overlays.append(.box(titleFrame, hOK ? .systemGreen : .systemRed,
                             label: "Δ\(fmt(hOffset))pt" + (hOK ? "" : " OFF-CENTER")))
        overlays.append(.hline(y: titleFrame.midY, fromX: barFrame.minX, toX: titleFrame.minX,
                               color: .systemRed, label: "\(fmt(titleFrame.minX - barFrame.minX))pt"))
        overlays.append(.hline(y: titleFrame.midY, fromX: titleFrame.maxX, toX: barFrame.maxX,
                               color: .systemRed, label: "\(fmt(barFrame.maxX - titleFrame.maxX))pt"))
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
        if let trailing = buttons.max(by: { $0.frame.maxX < $1.frame.maxX }) {
            let gap = barFrame.maxX - trailing.frame.maxX
            let ok = Self.trailingGapRange.contains(gap)
            record(screen, pane: pane, metric: "btn-gap", detail: buttonName(trailing), value: gap, ok: ok)
            XCTAssertTrue(ok, "\(screen) \(pane): trailing gap after \(buttonName(trailing)) is \(fmt(gap))pt, expected \(Self.trailingGapRange)")
        }

        // contained: every button inside the pane.
        for button in buttons where !barFrame.insetBy(dx: -1, dy: -1).contains(button.frame) {
            record(screen, pane: pane, metric: "contained", detail: buttonName(button), value: nil, ok: false)
            XCTFail("\(screen) \(pane): \(buttonName(button)) escapes the nav bar: \(button.frame) vs \(barFrame)")
        }
    }

    private func titleElement(in bar: XCUIElement, hints: [String]) -> XCUIElement? {
        // Both custom title views expose their text as a static text, and the
        // SwiftUI hosting wrapper can surface the same label twice (an outer
        // wrapper enclosing the real label), so resolve every match and pick
        // the innermost — the narrowest one whose frame is the actual text.
        let texts = bar.staticTexts.allElementsBoundByIndex.filter { $0.exists && $0.frame.width > 0 }
        for hint in hints {
            let matches = texts.filter { $0.label == hint }
            if let innermost = matches.min(by: { $0.frame.width < $1.frame.width }) {
                return innermost
            }
        }
        // No hint matched: the widest static text is the title.
        return texts.max { $0.frame.width < $1.frame.width }
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
        lines.append(pad("screen", 28) + pad("pane", 9) + pad("metric", 11) + pad("points", 9) + pad("ok", 6) + "detail")
        for m in measurements {
            let value = m.value.map { fmt($0) } ?? "-"
            lines.append(pad(m.screen, 28) + pad(m.pane, 9) + pad(m.metric, 11) + pad(value, 9)
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
            for overlay in overlays {
                draw(overlay, in: cg)
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

    private func drawLabel(_ text: String, at point: CGPoint, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: color,
            .backgroundColor: UIColor.white.withAlphaComponent(0.85),
        ]
        NSAttributedString(string: text, attributes: attributes).draw(at: point)
    }
}
