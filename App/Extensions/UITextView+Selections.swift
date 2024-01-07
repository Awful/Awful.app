//  UITextView+Selections.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UITextView {

    /**
     Replaces the `selectedRange` with `text` by modifying `textStorage` directly.

     This bypasses input traits and avoids text view contents jumping around after inserting an image.

     `Notification.Name.UITextViewTextDidChange` is manually posted while calling this method. I haven't tested whether `UITextViewDelegate` calls get made as a result of calling this method, but I would not be surprised if they are bypassed.

     - Seealso: rdar://problem/34617193 UITextView that isn't first responder ignores smartQuotesType when calling replace(_:withText:)
     */
    func replaceSelection(with text: String) {
        // If the text view is empty when mucking with text storage then the `font` and `textColor` properties are ignored.
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let font = font {
            attributes[.font] = font
        }
        if let textColor = textColor {
            attributes[.foregroundColor] = textColor
        }

        let previouslySelected = selectedRange

        textStorage.beginEditing()
        textStorage.replaceCharacters(in: previouslySelected, with: NSAttributedString(string: text, attributes: attributes))
        selectedRange = NSRange(location: previouslySelected.location + text.utf16.count, length: 0)
        textStorage.endEditing()

        // Mucking with text storage does not send this notification automatically, but we'd like this notification to be sent.
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: self)
    }
}
