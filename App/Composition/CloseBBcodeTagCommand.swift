//  CloseBBcodeTagCommand.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Auto-closes the nearest open BBcode tag in a text view.
final class CloseBBcodeTagCommand: NSObject {

    /// Whether the command can execute. KVO-compliant.
    @objc dynamic private(set) var enabled = false
    
    private let textView: UITextView
    
    init(textView: UITextView) {
        self.textView = textView
        super.init()
        
        updateEnabled()
        
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: .UITextViewTextDidChange, object: textView)
    }
    
    @objc private func textDidChange(notification: Notification) {
        updateEnabled()
    }
    
    private var textContent: Substring {
        return textView.text[..<String.Index(encodedOffset: textView.selectedRange.location)]
    }
    
    private func updateEnabled() {
        enabled = getCurrentlyOpenTag(textContent) != nil
    }
    
    /// Closes the nearest open BBcode tag.
    func execute() {
        if hasOpenCodeTag(textContent) {
            textView.insertText("[/code]")
            return
        }
        
        if let openTag = getCurrentlyOpenTag(textContent) {
            textView.insertText("[/\(openTag)]")
        }
    }
}

/*
 * Insert the appropriate closing tag, if any.
 *
 * First, scan backwards for [code]. If so, and there's no [/code] between there and here, then
 * the insertion is always [/code] (bbcode within [code] isn't interpreted).
 *
 * Scan backwards looking for [.
 * - If we find a [/tag], scan backwards for its [tag] and continue search from there.
 * - If we find [tag], trim =part if any, and insert [/tag].
 *
 * XXX should have a list of bbcode tags, and only consider those?
 */

/* Tests:
 * "[code] [b]"                -> true
 * "[code] [b] [/code]"        -> false
 * "[code] [b] [/code][code]"  -> true
 * "[code=cpp] [b]"            -> true
 * "[/code]"                   -> false
 * "[codemonkey] [b]"          -> false
 * "[code][codemonkey]"        -> true
 */
internal func hasOpenCodeTag(_ text: Substring) -> Bool {
    guard let codeRange = text.range(of: "[code", options: .backwards), codeRange.upperBound < text.endIndex else {
        return false
    }
    
    // If it's a false alarm like [codemonkey], keep looking.

    let nextCharacter = text[codeRange.upperBound]
    if nextCharacter.unicodeScalars.count == 1, !tagNameTerminators.contains(nextCharacter.unicodeScalars.first!) {
        return hasOpenCodeTag(text[..<codeRange.lowerBound])
    }
    
    // Is this still open?
    return text[codeRange.lowerBound...].range(of: "[/code]") == nil
}

/*
 * Tests:
 * "[b][i]"              -> "i"
 * "[b][i][/i]"          -> "b"
 * "[b][/b]"             -> nil
 * "[url=foo]"           -> "url"
 * "[url=foo][b][i][/b]" -> "url"
 * "["                   -> nil
 * "[foo][/x"            -> "foo"
 * "[foo attr]"          -> "foo"
 * "[code][b]"           -> "code"
 * "[b][code][/code]"    -> "b"
 * "[list][*]"           -> "list"
 */
internal func getCurrentlyOpenTag(_ text: Substring) -> Substring? {
    // Find start of preceding tag (opener or closer).
    guard let startingBracket = text.range(of: "[", options: .backwards) else { return nil }
    
    if startingBracket.upperBound == text.endIndex {
        // Incomplete tag, keep going.
        return getCurrentlyOpenTag(text[..<startingBracket.lowerBound])
    }
    
    // If it's a closer, find its opener.
    if text[startingBracket.upperBound] == "/" {
        guard let tagEnd = text[startingBracket.lowerBound...].range(of: "]") else {
            // Not a proper tag, keep searching backwards.
            return getCurrentlyOpenTag(text[..<startingBracket.lowerBound])
        }

        let afterSlash = text.index(after: startingBracket.upperBound)
        let tagName = text[afterSlash ..< tagEnd.lowerBound]
        guard let opener = text.range(of: "[\(tagName)]", options: .backwards)
            // Might be [tag=attr]
            ?? text.range(of: "[\(tagName)=", options: .backwards)
            // Might be [tag attr=val]
            ?? text.range(of: "[\(tagName) ", options: .backwards) else
        {
            // Never opened, keep searching backwards from the starting bracket.
            return getCurrentlyOpenTag(text[..<startingBracket.lowerBound])
        }

        // Now that we've matched [tag]...[/tag], keep looking back for an outer [tag2] that might still be open.
        return getCurrentlyOpenTag(text[..<opener.lowerBound])
    }
    
    // We have an opener!
    guard text[startingBracket.lowerBound...].range(of: "]") != nil else {
        // User is still typing the tag, we're done here.
        return nil
    }
    
    // Find the end of the tag name.
    guard let terminator = text.rangeOfCharacter(from: tagNameTerminators, options: [], range: startingBracket.upperBound ..< text.endIndex) else {
        // Malformed, keep looking.
        return getCurrentlyOpenTag(text[..<startingBracket.lowerBound])
    }

    let tagName = text[startingBracket.upperBound ..< terminator.lowerBound]
    if tagName == "*" {
        return getCurrentlyOpenTag(text[..<startingBracket.lowerBound])
    }
    
    return tagName
}

private let tagNameTerminators = CharacterSet(charactersIn: "]= ")
