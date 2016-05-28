//  CloseBBcodeTagCommand.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Auto-closes the nearest open BBcode tag in a text view.
final class CloseBBcodeTagCommand: NSObject {
    /// Whether the command can execute. KVO-compliant.
    dynamic private(set) var enabled = false
    
    private let textView: UITextView
    
    init(textView: UITextView) {
        self.textView = textView
        super.init()
        
        updateEnabled()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(textDidChange), name: UITextViewTextDidChangeNotification, object: textView)
    }
    
    @objc private func textDidChange(notification: NSNotification) {
        updateEnabled()
    }
    
    private var textContent: String {
        return (textView.text as NSString).substringToIndex(textView.selectedRange.location)
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
private func hasOpenCodeTag(text: NSString) -> Bool {
    let codeRange = text.rangeOfString("[code", options: .BackwardsSearch)
    if codeRange.location == NSNotFound || NSMaxRange(codeRange) >= text.length { return false }
    
    // If it's a false alarm like [codemonkey], keep looking.
    if tagNameTerminators.characterIsMember(text.characterAtIndex(NSMaxRange(codeRange))) {
        return hasOpenCodeTag(text.substringToIndex(codeRange.location))
    }
    
    // Is this still open?
    return (text.substringFromIndex(codeRange.location) as NSString).rangeOfString("[/code]").location == NSNotFound
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
private func getCurrentlyOpenTag(text: NSString) -> String? {
    // Find start of preceding tag (opener or closer).
    let startingBracket = text.rangeOfString("[", options: .BackwardsSearch).location
    guard startingBracket != NSNotFound else { return nil }
    
    if startingBracket >= text.length - 1 {
        // Incomplete tag, keep going.
        return getCurrentlyOpenTag(text.substringToIndex(startingBracket))
    }
    
    // If it's a closer, find its opener.
    if String(text.characterAtIndex(startingBracket + 1)) == "/" {
        var tagRange = (text.substringFromIndex(startingBracket) as NSString).rangeOfString("]")
        if tagRange.location == NSNotFound {
            // Not a proper tag, keep searching backwards.
            return getCurrentlyOpenTag(text.substringToIndex(startingBracket))
        }
        
        tagRange = NSRange(location: startingBracket + 2, length: tagRange.location - 2)
        let tagName = text.substringWithRange(tagRange)
        
        var openerLocation = text.rangeOfString("[\(tagName)]", options: .BackwardsSearch).location
        
        if openerLocation == NSNotFound {
            // Might be [tag=attr]
            openerLocation = text.rangeOfString("[\(tagName)=", options: .BackwardsSearch).location
        }
        
        if openerLocation == NSNotFound {
            // Might be [tag attr=val]
            openerLocation = text.rangeOfString("[\(tagName) ", options: .BackwardsSearch).location
        }
        
        if openerLocation == NSNotFound {
            // Never opened, keep searching backwards from the starting bracket.
            return getCurrentlyOpenTag(text.substringToIndex(startingBracket))
        }
        
        // Now that we've matched [tag]...[/tag], keep looking back for an outer [tag2] that might still be open.
        return getCurrentlyOpenTag(text.substringToIndex(openerLocation))
    }
    
    // We have an opener! Find the end of the tag name.
    var tagRange = text.rangeOfCharacterFromSet(tagNameTerminators, options: [], range: NSRange(location: startingBracket + 1, length: text.length - startingBracket - 1))
    if tagRange.location == NSNotFound {
        // Malformed, keep looking.
        return getCurrentlyOpenTag(text.substringToIndex(startingBracket))
    }
    
    tagRange.length -= 1 // Omit the ] or =;
    let tagName = text.substringWithRange(NSRange(location: startingBracket + 1, length: tagRange.location - startingBracket - 1))
    if tagName == "*" {
        return getCurrentlyOpenTag(text.substringToIndex(startingBracket))
    }
    
    return tagName
}

private let tagNameTerminators = NSCharacterSet(charactersInString: "]= ")
