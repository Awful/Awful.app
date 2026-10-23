//  NavigationControllerNilShowTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

/// UIKit calls `willShow`/`didShow` with a nil view controller when a navigation controller's
/// stack is set to empty, which the split view's collapse does to the detail column. The header
/// says nonnull, so Swift imports the parameter as non-optional, and the delegate has to cope.
final class NavigationControllerNilShowTests: XCTestCase {

    private typealias Show = @convention(c) (AnyObject, Selector, AnyObject, AnyObject?, Bool) -> Void

    private func callShow(_ selector: Selector, on nav: NavigationController) {
        let imp = unsafeBitCast(nav.method(for: selector), to: Show.self)
        imp(nav, selector, nav, nil, false)
    }

    /// Calls the delegate methods the way UIKit does, with nil where a view controller goes.
    func testShowDelegateToleratesNilViewController() {
        let nav = NavigationController(rootViewController: UIViewController())
        nav.loadViewIfNeeded()

        callShow(#selector(UINavigationControllerDelegate.navigationController(_:willShow:animated:)), on: nav)
        callShow(#selector(UINavigationControllerDelegate.navigationController(_:didShow:animated:)), on: nav)
    }

    /// The route the split view's collapse takes.
    func testEmptyingTheStackDoesNotCrash() {
        let nav = NavigationController(rootViewController: UIViewController())
        nav.loadViewIfNeeded()

        nav.viewControllers = []

        XCTAssertTrue(nav.viewControllers.isEmpty)
    }
}
