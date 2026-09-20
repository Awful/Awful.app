//  UITextView+MinimizedKeyboard.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// An input view with no height. Installing it collapses the keyboard down to just the input
/// accessory toolbars, the way a connected hardware keyboard does, while the text view stays
/// first responder so the caret, the toolbars, and hardware keys keep working.
///
/// On iPad the keyboard host also shows the input assistant bar (undo/redo, predictions, mic)
/// and reserves keyboard space for it, which leaves the toolbars floating above a gap. The bar
/// only goes away when it has nothing to show, so this view empties it for as long as it is
/// installed and carries what it replaced so `restore(to:)` can put it back.
final class MinimizedKeyboardInputView: UIView {
    private let leadingBarButtonGroups: [UIBarButtonItemGroup]
    private let trailingBarButtonGroups: [UIBarButtonItemGroup]
    private let autocorrectionType: UITextAutocorrectionType

    init(collapsing textView: UITextView) {
        leadingBarButtonGroups = textView.inputAssistantItem.leadingBarButtonGroups
        trailingBarButtonGroups = textView.inputAssistantItem.trailingBarButtonGroups
        autocorrectionType = textView.autocorrectionType
        super.init(frame: .zero)
        autoresizingMask = [.flexibleWidth]

        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []
        textView.autocorrectionType = .no
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 0)
    }

    /// Puts back the input assistant bar contents and autocorrection this view took away.
    func restore(to textView: UITextView) {
        textView.inputAssistantItem.leadingBarButtonGroups = leadingBarButtonGroups
        textView.inputAssistantItem.trailingBarButtonGroups = trailingBarButtonGroups
        textView.autocorrectionType = autocorrectionType
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
            inputView = MinimizedKeyboardInputView(collapsing: self)
        } else {
            guard let minimizedView = inputView as? MinimizedKeyboardInputView else { return }
            minimizedView.restore(to: self)
            inputView = nil
        }
        reloadInputViews()
    }

    /// Forgets a minimized keyboard without reloading input views, for when the keyboard is
    /// about to go away anyway. The next time the text view becomes first responder, the
    /// keyboard comes up in full.
    func resetMinimizedKeyboard() {
        guard let minimizedView = inputView as? MinimizedKeyboardInputView else { return }
        minimizedView.restore(to: self)
        inputView = nil
    }
}
