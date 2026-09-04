//  QuoteInsertionTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import UIKit
import XCTest

final class QuoteInsertionTests: XCTestCase {

    private var textView: UITextView!
    private let quote = "[quote]hi[/quote]\n"

    override func setUp() {
        super.setUp()
        textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
    }

    override func tearDown() {
        textView = nil
        super.tearDown()
    }

    // MARK: quoteSeparator

    func testSeparatorAtStartOfDocumentIsEmpty() {
        XCTAssertEqual(quoteSeparator(before: 0, in: ""), "")
        XCTAssertEqual(quoteSeparator(before: 0, in: "abc"), "")
    }

    func testSeparatorAfterBlankLineIsEmpty() {
        XCTAssertEqual(quoteSeparator(before: 5, in: "abc\n\n"), "")
    }

    func testSeparatorAfterSingleLineBreakIsOneNewline() {
        XCTAssertEqual(quoteSeparator(before: 4, in: "abc\n"), "\n")
        XCTAssertEqual(quoteSeparator(before: 1, in: "\n"), "\n")
    }

    func testSeparatorAfterTextIsTwoNewlines() {
        XCTAssertEqual(quoteSeparator(before: 3, in: "abc"), "\n\n")
        XCTAssertEqual(quoteSeparator(before: 1, in: "a"), "\n\n")
    }

    func testSeparatorClampsOutOfRangeLocations() {
        XCTAssertEqual(quoteSeparator(before: 99, in: "abc"), "\n\n")
        XCTAssertEqual(quoteSeparator(before: -1, in: "abc"), "")
    }

    // MARK: insert(_:replacing:moveCaretAfterInsertion:)

    func testInsertAtRequestedRangeMovesCaretAfterQuote() {
        textView.text = "abc"
        textView.selectedRange = NSRange(location: 3, length: 0)

        textView.insert("\n\n" + quote, replacing: NSRange(location: 3, length: 0), moveCaretAfterInsertion: true)

        XCTAssertEqual(textView.text, "abc\n\n" + quote)
        XCTAssertEqual(textView.selectedRange, NSRange(location: ("abc\n\n" + quote as NSString).length, length: 0))
    }

    func testAppendingWhileCaretIsEarlierPreservesCaret() {
        textView.text = "typed"
        textView.selectedRange = NSRange(location: 2, length: 0)

        textView.insert("\n\n" + quote, replacing: NSRange(location: 5, length: 0), moveCaretAfterInsertion: false)

        XCTAssertEqual(textView.text, "typed\n\n" + quote)
        XCTAssertEqual(textView.selectedRange, NSRange(location: 2, length: 0))
    }

    func testCaretAtOrAfterInsertionPointShiftsByInsertedLength() {
        textView.text = "abc"
        textView.selectedRange = NSRange(location: 3, length: 0)

        textView.insert(quote, replacing: NSRange(location: 0, length: 0), moveCaretAfterInsertion: false)

        XCTAssertEqual(textView.text, quote + "abc")
        XCTAssertEqual(textView.selectedRange, NSRange(location: (quote as NSString).length + 3, length: 0))
    }

    func testSelectionStraddlingReplacedRangeCollapsesAfterInsertion() {
        textView.text = "abcdef"
        textView.selectedRange = NSRange(location: 1, length: 4) // "bcde"

        textView.insert("X", replacing: NSRange(location: 2, length: 2), moveCaretAfterInsertion: false)

        XCTAssertEqual(textView.text, "abXef")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 3, length: 0))
    }

    func testRangePastEndInsertsAtEnd() {
        textView.text = "abc"
        textView.selectedRange = NSRange(location: 0, length: 0)

        textView.insert("Z", replacing: NSRange(location: 50, length: 3), moveCaretAfterInsertion: true)

        XCTAssertEqual(textView.text, "abcZ")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 4, length: 0))
    }

    func testInsertPostsTextDidChangeWithFinalSelection() {
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

        textView.insert("!!", replacing: NSRange(location: 0, length: 0), moveCaretAfterInsertion: false)

        XCTAssertEqual(observedSelection, NSRange(location: 8, length: 0))
    }

    func testInsertIntoEmptyTextViewKeepsFontAndTextColor() {
        let font = UIFont.systemFont(ofSize: 19)
        textView.font = font
        textView.textColor = .purple

        textView.insert(quote, replacing: NSRange(location: 0, length: 0), moveCaretAfterInsertion: true)

        let attributes = textView.textStorage.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(attributes[.font] as? UIFont, font)
        XCTAssertEqual(attributes[.foregroundColor] as? UIColor, .purple)
    }
}
