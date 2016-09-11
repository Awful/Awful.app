//  CloseBBcodeTagCommand.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Auto-closes the nearest open BBcode tag in a text view.
final class CloseBBcodeTagCommand: NSObject {
    /// Whether the command can execute. KVO-compliant.
    dynamic fileprivate(set) var enabled = false
    
    fileprivate let textView: UITextView
    
    init(textView: UITextView) {
        self.textView = textView
        super.init()
        
        updateEnabled()
        
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: NSNotification.Name.UITextViewTextDidChange, object: textView)
    }
    
    @objc private func textDidChange(notification: NSNotification) {
        updateEnabled()
    }
    
    private var textContent: String {
        return (textView.text as NSString).substring(to: textView.selectedRange.location)
    }
    
    fileprivate func updateEnabled() {
        enabled = getCurrentlyOpenTag(textContent as NSString) != nil
    }
    
    /// Closes the nearest open BBcode tag.
    func execute() {
        if hasOpenCodeTag(textContent as NSString) {
            textView.insertText("[/code]")
            return
        }
        
        if let openTag = getCurrentlyOpenTag(textContent as NSString) {
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
fileprivate func hasOpenCodeTag(_ text: NSString) -> Bool {
    let codeRange = text.range(of: "[code", options: .backwards)
    if codeRange.location == NSNotFound || NSMaxRange(codeRange) >= text.length { return false }
    
    // If it's a false alarm like [codemonkey], keep looking.
    
    if
        let nextCharacter = UnicodeScalar(text.character(at: NSMaxRange(codeRange))),
        tagNameTerminators.contains(nextCharacter)
    {
        return hasOpenCodeTag(text.substring(to: codeRange.location) as NSString)
    }
    
    // Is this still open?
    return (text.substring(from: codeRange.location) as NSString).range(of: "[/code]").location == NSNotFound
}

/*
 * Tests:
 * "[b][i]"              -> "i"
 * "[b][i][/i]"          -> "b"
 * "[b][/b]"             -> nil
 * "[url=foo]"           -> "url"
 * "[url=foo][b][i][/b]" -> "url"
 * "["                   -> "nil"
 * "[foo][/x"            -> "foo"
 * "[foo attr]"          -> "foo"
 * "[code][b]"           -> "code"
 * "[b][code][/code]"    -> "b"
 * "[list][*]"           -> "list"
 */
fileprivate func getCurrentlyOpenTag(_ text: NSString) -> String? {
    // Find start of preceding tag (opener or closer).
    let startingBracket = text.range(of: "[", options: .backwards).location
    guard startingBracket != NSNotFound else { return nil }
    
    if startingBracket >= text.length - 1 {
        // Incomplete tag, keep going.
        return getCurrentlyOpenTag(text.substring(to: startingBracket) as NSString)
    }
    
    // If it's a closer, find its opener.
    if String(text.character(at: startingBracket + 1)) == "/" {
        var tagRange = (text.substring(from: startingBracket) as NSString).range(of: "]")
        if tagRange.location == NSNotFound {
            // Not a proper tag, keep searching backwards.
            return getCurrentlyOpenTag(text.substring(to: startingBracket) as NSString)
        }
        
        tagRange = NSRange(location: startingBracket + 2, length: tagRange.location - 2)
        let tagName = text.substring(with: tagRange)
        
        var openerLocation = text.range(of: "[\(tagName)]", options: .backwards).location
        
        if openerLocation == NSNotFound {
            // Might be [tag=attr]
            openerLocation = text.range(of: "[\(tagName)=", options: .backwards).location
        }
        
        if openerLocation == NSNotFound {
            // Might be [tag attr=val]
            openerLocation = text.range(of: "[\(tagName) ", options: .backwards).location
        }
        
        if openerLocation == NSNotFound {
            // Never opened, keep searching backwards from the starting bracket.
            return getCurrentlyOpenTag(text.substring(to: startingBracket) as NSString)
        }
        
        // Now that we've matched [tag]...[/tag], keep looking back for an outer [tag2] that might still be open.
        return getCurrentlyOpenTag(text.substring(to: openerLocation) as NSString)
    }
    
    // We have an opener! Find the end of the tag name.
    var tagRange = text.rangeOfCharacter(from: tagNameTerminators as CharacterSet, options: [], range: NSRange(location: startingBracket + 1, length: text.length - startingBracket - 1))
    if tagRange.location == NSNotFound {
        // Malformed, keep looking.
        return getCurrentlyOpenTag(text.substring(to: startingBracket) as NSString)
    }
    
    tagRange.length -= 1 // Omit the ] or =;
    let tagName = text.substring(with: NSRange(location: startingBracket + 1, length: tagRange.location - startingBracket - 1))
    if tagName == "*" {
        return getCurrentlyOpenTag(text.substring(to: startingBracket) as NSString)
    }
    
    return tagName
}

fileprivate let tagNameTerminators = CharacterSet(charactersIn: "]= ")
