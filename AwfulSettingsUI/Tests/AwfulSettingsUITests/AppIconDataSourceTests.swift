//  AppIconDataSourceTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulSettingsUI
import SwiftUI
import XCTest

/// Stands in for `UIApplication.setAlternateIconName`: every request parks on a continuation
/// until the test resolves or fails it by icon name, so tests control completion order.
@MainActor
private final class IconSetterStub {
    private(set) var received: [String] = []
    private var pending: [String: CheckedContinuation<Void, Error>] = [:]

    struct Failure: Error {}

    func set(_ icon: AppIconDataSource.AppIcon) async throws {
        received.append(icon.imageName)
        try await withCheckedThrowingContinuation { continuation in
            pending[icon.imageName] = continuation
        }
    }

    func resolve(_ name: String) {
        pending.removeValue(forKey: name)?.resume()
    }

    func fail(_ name: String) {
        pending.removeValue(forKey: name)?.resume(throwing: Failure())
    }
}

@MainActor
final class AppIconDataSourceTests: XCTestCase {
    private typealias AppIcon = AppIconDataSource.AppIcon

    private let a = AppIcon(accessibilityLabel: "A", imageName: "a")
    private let b = AppIcon(accessibilityLabel: "B", imageName: "b")
    private let c = AppIcon(accessibilityLabel: "C", imageName: "c")
    private let d = AppIcon(accessibilityLabel: "D", imageName: "d")

    private var setter: IconSetterStub!
    private var dataSource: AppIconDataSource!

    override func setUp() async throws {
        setter = IconSetterStub()
        let setter = setter!
        dataSource = AppIconDataSource(
            appIcons: [a, b, c, d],
            imageLoader: { _ in Image(systemName: "app") },
            selected: a,
            setter: { try await setter.set($0) }
        )
    }

    /// `select(_:)` returns before its task runs, so tests poll on the main actor until
    /// `condition` holds. Bounded so a wrong expectation fails instead of hanging.
    private func waitUntil(
        _ condition: @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<500 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for condition", file: file, line: line)
    }

    /// Gives any settled-but-still-scheduled tasks a chance to run, to catch late writes.
    private func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    func testSuccessKeepsSelection() async {
        dataSource.select(b)
        XCTAssertEqual(dataSource.selected, b, "selection is optimistic")

        await waitUntil { self.setter.received == ["b"] }
        setter.resolve("b")
        await settle()

        XCTAssertEqual(dataSource.selected, b)
    }

    func testFailureRollsBackToConfirmed() async {
        dataSource.select(b)
        await waitUntil { self.setter.received == ["b"] }

        setter.fail("b")
        await waitUntil { self.dataSource.selected == self.a }

        XCTAssertEqual(dataSource.selected, a)
    }

    /// Rapid taps B then C. B is applied by the system before C fails, so the rollback target
    /// is B — the last icon the system actually accepted — not the pre-burst A.
    func testLatestFailureRollsBackToLastConfirmed() async {
        dataSource.select(b)
        await waitUntil { self.setter.received == ["b"] }
        dataSource.select(c)
        XCTAssertEqual(dataSource.selected, c)

        setter.resolve("b")
        await waitUntil { self.setter.received == ["b", "c"] }
        setter.fail("c")
        await waitUntil { self.dataSource.selected == self.b }

        XCTAssertEqual(dataSource.selected, b)
    }

    /// Rapid taps B then C. B fails after the user has already moved on to C; the failure
    /// must not clobber C, which then succeeds.
    func testEarlierFailureDoesNotClobberLaterSelection() async {
        dataSource.select(b)
        await waitUntil { self.setter.received == ["b"] }
        dataSource.select(c)

        setter.fail("b")
        await waitUntil { self.setter.received == ["b", "c"] }
        XCTAssertEqual(dataSource.selected, c, "an earlier failure must not roll back a later selection")

        setter.resolve("c")
        await settle()
        XCTAssertEqual(dataSource.selected, c)
    }

    /// Taps B, C, D while B is in flight. C is queued behind B but superseded by D before it
    /// starts, so the system never receives it.
    func testQueuedRequestSkippedWhenSuperseded() async {
        dataSource.select(b)
        await waitUntil { self.setter.received == ["b"] }
        dataSource.select(c)
        dataSource.select(d)

        setter.resolve("b")
        await waitUntil { self.setter.received == ["b", "d"] }
        setter.resolve("d")
        await settle()

        XCTAssertEqual(setter.received, ["b", "d"])
        XCTAssertEqual(dataSource.selected, d)
    }

    /// After an earlier confirmed change, a later failure rolls back to that change even if
    /// the request that confirmed it had itself been superseded (the system call still ran).
    func testSupersededRequestStillRecordsConfirmation() async {
        dataSource.select(b)
        await waitUntil { self.setter.received == ["b"] }
        dataSource.select(c)   // supersedes B, but B's system call is already running

        setter.resolve("b")
        await waitUntil { self.setter.received == ["b", "c"] }
        setter.fail("c")
        await waitUntil { self.dataSource.selected == self.b }

        XCTAssertEqual(dataSource.selected, b)
    }
}
