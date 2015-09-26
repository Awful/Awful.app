//  UIKit.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UITableViewCell {
    /// Gets/sets the background color of the selectedBackgroundView (inserting one if necessary).
    var selectedBackgroundColor: UIColor? {
        get {
            return selectedBackgroundView?.backgroundColor
        }
        set {
            if selectedBackgroundView == nil {
                selectedBackgroundView = UIView()
            }
            selectedBackgroundView?.backgroundColor = newValue
        }
    }
}

extension UITextView {
    /// Returns a rectangle that encompasses the current selection in the text view, or nil if there is no selection.
    var selectedRect: CGRect? {
        switch selectedTextRange {
        case .Some(let selection) where selection.empty:
            return caretRectForPosition(selection.end)
        case .Some(let selection):
            let rects = selectionRectsForRange(selection).map { $0.rect }
            if rects.isEmpty {
                return nil
            } else {
                return rects.reduce(CGRect.null) { $0.union($1) }
            }
        case .None:
            return nil
        }
    }
}
