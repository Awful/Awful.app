//  UITextView+Selections.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import os
import UIKit

private let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier!, category: "Composition")

extension UITextView {

    /**
     Replaces the `selectedRange` with `text` by modifying `textStorage` directly.

     This bypasses input traits and avoids text view contents jumping around after inserting an image.

     `Notification.Name.UITextViewTextDidChange` is manually posted while calling this method, and the caret is then scrolled into view with a full layout pass (see `scrollCaretToVisible(paddingBelow:animated:layout:)`). I haven't tested whether `UITextViewDelegate` calls get made as a result of calling this method, but I would not be surprised if they are bypassed.

     - Seealso: rdar://problem/34617193 UITextView that isn't first responder ignores smartQuotesType when calling replace(_:withText:)
     */
    func replaceSelection(with text: String) {
        replaceSelection(with: NSAttributedString(string: text, attributes: attributesForStorageInsertion))
    }

    /// If the text view is empty when mucking with text storage then the `font` and `textColor` properties are ignored, so bake them into inserted strings.
    private var attributesForStorageInsertion: [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let font = font {
            attributes[.font] = font
        }
        if let textColor = textColor {
            attributes[.foregroundColor] = textColor
        }
        return attributes
    }

    /// Replaces the `selectedRange` with `attributedText` by modifying `textStorage` directly. See `replaceSelection(with:)` above for caveats.
    func replaceSelection(with attributedText: NSAttributedString) {
        insert(attributedText, replacing: selectedRange, moveCaretAfterInsertion: true)
    }

    /**
     Replaces `range` with `text` by modifying `textStorage` directly, for insertions that were requested earlier than they happen (e.g. a quote that arrives after the user has kept typing).

     When `moveCaretAfterInsertion` is `false` the selection stays on the text it was on: unchanged if it precedes `range`, shifted by the inserted length if it sits at or beyond it.

     Posts `UITextView.textDidChangeNotification` and scrolls the caret into view, like `replaceSelection(with:)`.
     */
    func insert(_ text: String, replacing range: NSRange, moveCaretAfterInsertion: Bool) {
        insert(NSAttributedString(string: text, attributes: attributesForStorageInsertion), replacing: range, moveCaretAfterInsertion: moveCaretAfterInsertion)
    }

    private func insert(_ attributedText: NSAttributedString, replacing range: NSRange, moveCaretAfterInsertion: Bool) {
        let previouslySelected = selectedRange
        var range = range
        if range.location == NSNotFound || range.location > textStorage.length {
            range = NSRange(location: textStorage.length, length: 0)
        }
        range.length = min(range.length, textStorage.length - range.location)

        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: attributedText)
        textStorage.endEditing()

        // Setting the selection mid-batch hands a stale range to the text input controller's
        // tokenizer and crashes when the text view is first responder (NLStringTokenizer, iOS 26);
        // it must happen after endEditing() has published the edit. Clamp defensively.
        let newSelection: NSRange
        if moveCaretAfterInsertion {
            newSelection = NSRange(location: range.location + attributedText.length, length: 0)
        } else if previouslySelected.location >= NSMaxRange(range) {
            newSelection = NSRange(location: previouslySelected.location + attributedText.length - range.length, length: previouslySelected.length)
        } else if NSMaxRange(previouslySelected) > range.location {
            // The selection straddled the replaced text; collapse it after the insertion.
            newSelection = NSRange(location: range.location + attributedText.length, length: 0)
        } else {
            newSelection = previouslySelected
        }
        let clampedLocation = min(newSelection.location, textStorage.length)
        selectedRange = NSRange(location: clampedLocation, length: min(newSelection.length, textStorage.length - clampedLocation))

        // Mucking with text storage does not send this notification automatically, but we'd like this notification to be sent.
        // Posted after the selection is final: CloseBBcodeTagCommand's observer reads selectedRange.
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: self)

        // Programmatic inserts can be tall (image attachments, long quotes), and TextKit 2's lazy
        // contentSize doesn't account for them yet, so this is the one place that pays for a full
        // layout before scrolling. Observers of the notification above only do the cheap follow.
        scrollCaretToVisible(layout: .wholeDocument)
    }

    /// Inserts `attachment` at the selection Notes-style: the attachment on its own line, with the caret on a fresh line below it.
    func insertAttachmentOnOwnLine(_ attachment: NSTextAttachment) {
        let insertion = NSMutableAttributedString()
        let location = selectedRange.location
        let string = textStorage.string as NSString
        if location > 0, string.character(at: location - 1) != 0x0A /* "\n" */ {
            insertion.append(NSAttributedString(string: "\n"))
        }
        insertion.append(NSAttributedString(attachment: attachment))
        insertion.append(NSAttributedString(string: "\n"))
        insertion.addAttributes(attributesForStorageInsertion, range: NSRange(location: 0, length: insertion.length))

        replaceSelection(with: insertion)
    }

    /// How much layout work `scrollCaretToVisible` does before reading the caret's position.
    enum CaretScrollLayout {
        /// Lay out the whole document and repair `contentSize` first. Needed after programmatic
        /// inserts of tall content and after inset changes, when TextKit 2's lazily estimated
        /// `contentSize` is stale.
        case wholeDocument
        /// Trust the current layout and `contentSize`. Cheap enough for every keystroke.
        case caretOnly
    }

    /// Scrolls so the caret is visible, with `padding` points of breathing room below it.
    func scrollCaretToVisible(paddingBelow padding: CGFloat = 20, animated: Bool = false, layout: CaretScrollLayout = .wholeDocument) {
        // TextKit 2 lays out lazily: right after an edit (especially a tall image attachment),
        // the caret rect and contentSize are stale until the next layout pass, so scrolling
        // immediately computes garbage. Wait a runloop tick, then force layout and scroll.
        DispatchQueue.main.async { [weak self] in
            self?.reallyScrollCaretToVisible(paddingBelow: padding, animated: animated, layout: layout)
        }
    }

    private func reallyScrollCaretToVisible(paddingBelow padding: CGFloat, animated: Bool, layout: CaretScrollLayout) {
        let state = signposter.beginInterval("scrollCaretToVisible", "\(layout == .wholeDocument ? "wholeDocument" : "caretOnly")")
        defer { signposter.endInterval("scrollCaretToVisible", state) }

        // The caret can be far below the lazily-laid-out viewport; ensure the whole document is
        // laid out so caretRect and the laid-out height are trustworthy.
        var layoutHeight: CGFloat = 0
        if layout == .wholeDocument, #available(iOS 16.0, *), let textLayoutManager {
            textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
            layoutHeight = textLayoutManager.usageBoundsForTextContainer.maxY
                + textContainerInset.top + textContainerInset.bottom
        }
        layoutIfNeeded()

        guard let end = selectedTextRange?.end else { return }
        var rect = caretRect(for: end)
        guard !rect.isNull, !rect.isInfinite else { return }
        rect.size.height += padding

        // UITextView can lag updating contentSize after an edit, and the padded caret rect can
        // extend past the end of the content; widen contentSize so the offset we set below isn't
        // clamped back to a smaller maximum.
        var contentHeight = contentSize.height
        if layout == .wholeDocument {
            contentHeight = max(contentSize.height, layoutHeight, rect.maxY)
            if contentSize.height < contentHeight {
                contentSize.height = contentHeight
            }
        }

        // scrollRectToVisible ignores contentInset, so anything scrolled to the bottom of our
        // bounds sits behind the keyboard and input accessory toolbars. Compute the region those
        // insets leave visible and scroll minimally to contain the caret in it.
        let visibleTop = contentOffset.y + adjustedContentInset.top
        let visibleBottom = contentOffset.y + bounds.height - adjustedContentInset.bottom
        var target = contentOffset
        if rect.maxY > visibleBottom {
            target.y += rect.maxY - visibleBottom
        } else if rect.minY < visibleTop {
            target.y -= visibleTop - rect.minY
        }
        let maxOffsetY = max(contentHeight + adjustedContentInset.bottom - bounds.height, -adjustedContentInset.top)
        target.y = min(max(target.y, -adjustedContentInset.top), maxOffsetY)
        if target.y != contentOffset.y {
            setContentOffset(target, animated: animated)
        }
    }
}

/// The line breaks to put before a quote inserted at `location` so it starts on its own paragraph: nothing at the start of the document or after a blank line, one newline after a line break, otherwise two.
func quoteSeparator(before location: Int, in string: NSString) -> String {
    let location = max(0, min(location, string.length))
    guard location > 0 else { return "" }
    let precedingLength = min(2, location)
    let preceding = string.substring(with: NSRange(location: location - precedingLength, length: precedingLength))
    if preceding == "\n\n" {
        return ""
    } else if preceding.hasSuffix("\n") {
        return "\n"
    } else {
        return "\n\n"
    }
}
