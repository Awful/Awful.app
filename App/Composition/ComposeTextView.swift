//  ComposeTextView.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A text view suitable for composing replies, posts, and private messages.
final class ComposeTextView: URLCleaningTextView, CompositionHidesMenuItems {
    var hidesBuiltInMenuItems = false
    fileprivate lazy var BBcodeBar: CompositionInputAccessoryView = {
        let bar = CompositionInputAccessoryView(textView: self)
        bar.keyboardAppearance = self.keyboardAppearance
        return bar
    }()
    
    // MARK: UITextInputTraits
    
    override var keyboardAppearance: UIKeyboardAppearance {
        didSet { BBcodeBar.keyboardAppearance = keyboardAppearance }
    }
    
    // MARK: UIResponder
    
    /// Shown above the keyboard instead of the plain BBcode bar. The view controller sets this so
    /// composition screens get the modern toolbar too; `becomeFirstResponder` reinstalls the
    /// accessory view every time, so it has to be told which one to use.
    var accessoryView: UIView? {
        didSet {
            if isFirstResponder {
                inputAccessoryView = accessoryView ?? BBcodeBar
                reloadInputViews()
            }
        }
    }

    override func becomeFirstResponder() -> Bool {
        inputAccessoryView = accessoryView ?? BBcodeBar
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
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard !hidesBuiltInMenuItems else { return false }
        return super.canPerformAction(action, withSender: sender)
    }
}
