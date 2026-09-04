//  UITextViewReplaceSelectionTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import UIKit
import XCTest

final class UITextViewReplaceSelectionTests: XCTestCase {

    private var textView: UITextView!

    override func setUp() {
        super.setUp()
        textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
    }

    override func tearDown() {
        textView = nil
        super.tearDown()
    }

    func testReplacingMidStringSelectionPutsCaretAfterInsertedText() {
        textView.text = "Hello world"
        textView.selectedRange = NSRange(location: 6, length: 5) // "world"

        textView.replaceSelection(with: "there, world")

        XCTAssertEqual(textView.text, "Hello there, world")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 6 + ("there, world" as NSString).length, length: 0))
    }

    func testReplacingLongSelectionWithShorterTextKeepsCaretInBounds() {
        textView.text = String(repeating: "a", count: 100)
        textView.selectedRange = NSRange(location: 0, length: 100)

        textView.replaceSelection(with: "b")

        XCTAssertEqual(textView.text, "b")
        XCTAssertLessThanOrEqual(NSMaxRange(textView.selectedRange), textView.textStorage.length)
        XCTAssertEqual(textView.selectedRange, NSRange(location: 1, length: 0))
    }

    func testInsertingIntoEmptyTextViewKeepsFontAndTextColor() {
        let font = UIFont.systemFont(ofSize: 19)
        let textColor = UIColor.purple
        textView.font = font
        textView.textColor = textColor

        textView.replaceSelection(with: "[quote]hi[/quote]")

        let attributes = textView.textStorage.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(attributes[.font] as? UIFont, font)
        XCTAssertEqual(attributes[.foregroundColor] as? UIColor, textColor)
    }

    func testTextDidChangeNotificationSeesFinalSelection() {
        textView.text = "before"
        textView.selectedRange = NSRange(location: 6, length: 0)

        var observedSelection: NSRange?
        let token = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: nil
        ) { [textView] _ in
            observedSelection = textView?.selectedRange
        }
        defer { NotificationCenter.default.removeObserver(token) }

        textView.replaceSelection(with: " and after")

        XCTAssertEqual(observedSelection, NSRange(location: ("before and after" as NSString).length, length: 0))
    }

    func testCaretArithmeticIsCorrectWithAstralPlaneCharactersBeforeSelection() {
        textView.text = "💀👏 " // U+1F480 U+1F44F space: 5 UTF-16 units
        textView.selectedRange = NSRange(location: 5, length: 0)

        textView.replaceSelection(with: "clap")

        XCTAssertEqual(textView.text, "💀👏 clap")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 9, length: 0))
    }
}

extension UITextViewReplaceSelectionTests {

    private func pumpRunLoop() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    }

    func testReplaceSelectionScrollsCaretAboveBottomInset() {
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        textView.contentInset.bottom = 100
        textView.font = .systemFont(ofSize: 17)

        textView.replaceSelection(with: Array(repeating: "line", count: 60).joined(separator: "\n"))
        pumpRunLoop()

        XCTAssertGreaterThan(textView.contentOffset.y, 0)
        let caret = textView.caretRect(for: textView.selectedTextRange!.end)
        let visibleBottom = textView.contentOffset.y + textView.bounds.height - textView.adjustedContentInset.bottom
        XCTAssertLessThanOrEqual(caret.maxY, visibleBottom + 0.5)
    }

    func testCaretOnlyScrollLeavesVisibleCaretAlone() {
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        textView.text = "short"
        textView.selectedRange = NSRange(location: 5, length: 0)
        pumpRunLoop()
        let offset = textView.contentOffset
        let size = textView.contentSize

        textView.scrollCaretToVisible(layout: .caretOnly)
        pumpRunLoop()

        XCTAssertEqual(textView.contentOffset, offset)
        XCTAssertEqual(textView.contentSize, size)
    }
}
