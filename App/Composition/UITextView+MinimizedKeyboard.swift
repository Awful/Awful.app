//  UITextView+MinimizedKeyboard.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// An input view with no height. Installing it collapses the keyboard down to just the input
/// accessory toolbars, the way a connected hardware keyboard does, while the text view stays
/// first responder so the caret, the toolbars, and hardware keys keep working.
final class MinimizedKeyboardInputView: UIView {
    init() {
        super.init(frame: .zero)
        autoresizingMask = [.flexibleWidth]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 0)
    }
}

extension UITextView {

    /// Whether the keyboard is collapsed to just the input accessory toolbars.
    var isKeyboardMinimized: Bool {
        inputView is MinimizedKeyboardInputView
    }

    /// Collapses the keyboard to just the input accessory toolbars, or brings it back. Leaves any
    /// other custom input view (e.g. the legacy smilie keyboard) alone when restoring. Meant for
    /// a first responder; the toggle that calls it lives in the accessory view.
    func setKeyboardMinimized(_ minimized: Bool) {
        if minimized {
            guard !isKeyboardMinimized else { return }
            inputView = MinimizedKeyboardInputView()
        } else {
            guard isKeyboardMinimized else { return }
            inputView = nil
        }
        reloadInputViews()
    }

    /// Forgets a minimized keyboard without reloading input views, for when the keyboard is
    /// about to go away anyway. The next time the text view becomes first responder, the
    /// keyboard comes up in full.
    func resetMinimizedKeyboard() {
        if isKeyboardMinimized {
            inputView = nil
        }
    }
}
