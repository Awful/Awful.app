//  UITextViewInsertAttachmentTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import UIKit
import XCTest

final class UITextViewInsertAttachmentTests: XCTestCase {

    private var textView: UITextView!

    override func setUp() {
        super.setUp()
        textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
    }

    override func tearDown() {
        textView = nil
        super.tearDown()
    }

    private var attachmentCharacter: String { "\u{FFFC}" }

    private func makeAttachment() -> NSTextAttachment {
        let attachment = NSTextAttachment()
        attachment.image = UIImage()
        return attachment
    }

    func testInsertingIntoEmptyTextViewPutsCaretOnLineBelowAttachment() {
        textView.insertAttachmentOnOwnLine(makeAttachment())

        XCTAssertEqual(textView.text, "\(attachmentCharacter)\n")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 2, length: 0))
    }

    func testInsertingMidLinePushesAttachmentOntoItsOwnLine() {
        textView.text = "Helloworld"
        textView.selectedRange = NSRange(location: 5, length: 0) // "Hello|world"

        textView.insertAttachmentOnOwnLine(makeAttachment())

        XCTAssertEqual(textView.text, "Hello\n\(attachmentCharacter)\nworld")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 8, length: 0))
    }

    func testInsertingAtLineStartDoesNotDoubleNewline() {
        textView.text = "Hello\n"
        textView.selectedRange = NSRange(location: 6, length: 0)

        textView.insertAttachmentOnOwnLine(makeAttachment())

        XCTAssertEqual(textView.text, "Hello\n\(attachmentCharacter)\n")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 8, length: 0))
    }

    func testConsecutiveInsertionsStackAttachmentsOnSeparateLines() {
        textView.insertAttachmentOnOwnLine(makeAttachment())
        textView.insertAttachmentOnOwnLine(makeAttachment())

        XCTAssertEqual(textView.text, "\(attachmentCharacter)\n\(attachmentCharacter)\n")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 4, length: 0))
    }

    func testInsertingIntoEmptyTextViewKeepsFontAndTextColorOnTrailingNewline() {
        let font = UIFont.systemFont(ofSize: 19)
        let textColor = UIColor.purple
        textView.font = font
        textView.textColor = textColor

        textView.insertAttachmentOnOwnLine(makeAttachment())

        let attributes = textView.textStorage.attributes(at: 1, effectiveRange: nil)
        XCTAssertEqual(attributes[.font] as? UIFont, font)
        XCTAssertEqual(attributes[.foregroundColor] as? UIColor, textColor)
    }

    func testTextDidChangeNotificationSeesFinalSelection() {
        var observedSelection: NSRange?
        let token = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: nil
        ) { [textView] _ in
            observedSelection = textView?.selectedRange
        }
        defer { NotificationCenter.default.removeObserver(token) }

        textView.insertAttachmentOnOwnLine(makeAttachment())

        XCTAssertEqual(observedSelection, NSRange(location: 2, length: 0))
    }
}
