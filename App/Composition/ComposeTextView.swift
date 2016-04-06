//  ComposeTextView.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A text view suitable for composing replies, posts, and private messages.
final class ComposeTextView: UITextView, CompositionHidesMenuItems {
    var hidesBuiltInMenuItems = false
    private lazy var BBcodeBar: CompositionInputAccessoryView = {
        let bar = CompositionInputAccessoryView(textView: self)
        bar.keyboardAppearance = self.keyboardAppearance
        return bar
    }()
    
    // MARK: UITextInputTraits
    
    override var keyboardAppearance: UIKeyboardAppearance {
        didSet { BBcodeBar.keyboardAppearance = keyboardAppearance }
    }
    
    // MARK: UIResponder
    
    override func becomeFirstResponder() -> Bool {
        inputAccessoryView = BBcodeBar
        guard super.becomeFirstResponder() else {
            inputAccessoryView = nil
            return false
        }
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        inputAccessoryView = nil
        return true
    }
    
    override func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool {
        guard !hidesBuiltInMenuItems else { return false }
        return super.canPerformAction(action, withSender: sender)
    }
}
