//  UnpopStackTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

/// The swipe-from-right-edge unpop stack holds view controllers that were popped off this
/// navigation controller. Anything that replaces the stack wholesale has to clear it, or the
/// gesture will splice an unrelated screen back on top.
///
/// The unpop handler is iPhone-only (`NavigationController.unpopHandler`), so these only mean
/// anything when run on an iPhone simulator.
final class UnpopStackTests: XCTestCase {

    private func makeNavigationController() throws -> NavigationController {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone,
                          "the unpop handler only exists on iPhone")
        return NavigationController(rootViewController: UIViewController())
    }

    func testSetViewControllersClearsUnpopStack() throws {
        let nav = try makeNavigationController()
        nav.setUnpopStack([StubRestorableViewController()])
        XCTAssertEqual(nav.unpopRoutes.count, 1, "precondition: something is staged for unpop")

        nav.setViewControllers([UIViewController(), UIViewController()], animated: false)

        XCTAssertTrue(nav.unpopRoutes.isEmpty,
                      "replacing the stack should discard the staged unpop view controllers")
    }

    func testPushClearsUnpopStack() throws {
        let nav = try makeNavigationController()
        nav.setUnpopStack([StubRestorableViewController()])
        XCTAssertEqual(nav.unpopRoutes.count, 1, "precondition: something is staged for unpop")

        nav.pushViewController(UIViewController(), animated: false)

        XCTAssertTrue(nav.unpopRoutes.isEmpty,
                      "a normal push should discard the staged unpop view controllers")
    }

    /// The handler stores popped view controllers deepest-first and unpops from the end, so an
    /// entry that can't be saved makes everything below it unreachable.
    func testUnpopRoutesTruncatesBelowAnUnsavableEntry() throws {
        let nav = try makeNavigationController()
        nav.setUnpopStack([
            StubRestorableViewController(),  // unreachable once the entry above it is dropped
            UIViewController(),              // not a RestorableLocation
            StubRestorableViewController(),  // next to be unpopped
        ])

        XCTAssertEqual(nav.unpopRoutes.count, 1,
                       "only the run nearest the end of the stack should survive")
    }

    func testUnpopRoutesIsEmptyWhenTheNextEntryCannotBeSaved() throws {
        let nav = try makeNavigationController()
        nav.setUnpopStack([StubRestorableViewController(), UIViewController()])

        XCTAssertTrue(nav.unpopRoutes.isEmpty,
                      "saving the deeper entry would unpop to the wrong screen")
    }

    /// Assigning the `viewControllers` property is a different selector from
    /// `setViewControllers(_:animated:)` and is deliberately left alone, because that's what the
    /// split view's collapse/separate handling uses to move stacks between columns.
    func testAssigningViewControllersPropertyLeavesUnpopStackAlone() throws {
        let nav = try makeNavigationController()
        nav.setUnpopStack([StubRestorableViewController()])

        nav.viewControllers = [UIViewController()]

        XCTAssertEqual(nav.unpopRoutes.count, 1,
                       "the property setter is not the override point; collapse/expand relies on that")
    }
}

private final class StubRestorableViewController: UIViewController, RestorableLocation {
    var restorationRoute: AwfulRoute? { .forumList }
}
