//  CopyURLActivityTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

/// When the app runs on a Mac, the share sheet is backed by NSSharingServicePicker, which calls `valueForKey:` on each activity item. The URL box has to be an NSObject or that call aborts the app.
final class CopyURLActivityTests: XCTestCase {

    private let url = URL(string: "https://forums.somethingawful.com/")!

    func testBoxAnswersKeyValueCoding() {
        let box = CopyURLActivity.Box(url)
        XCTAssertTrue((box as AnyObject).responds(to: #selector(NSObject.value(forKey:))))
        XCTAssertNotNil((box as NSObject).value(forKey: "description"))
    }

    func testBoxOnlyFeedsCopyURLActivity() {
        let box = CopyURLActivity.Box(url)
        XCTAssertTrue(CopyURLActivity().canPerform(withActivityItems: [box]))
        XCTAssertFalse(CopyImageActivity().canPerform(withActivityItems: [box]))
        XCTAssertFalse(CopyURLActivity().canPerform(withActivityItems: [url]))
    }
}
