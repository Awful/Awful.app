//  UITextView+.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

public extension UITextView {
    /// Returns a rectangle that encompasses the current selection in the text view, or nil if there is no selection.
    var selectedRect: CGRect? {
        switch selectedTextRange {
        case .some(let selection) where selection.isEmpty:
            return caretRect(for: selection.end)
        case .some(let selection):
            let rects = selectionRects(for: selection).map { ($0 ).rect }
            if rects.isEmpty {
                return nil
            } else {
                return rects.reduce { $0.union($1) }
            }
        case .none:
            return nil
        }
    }
}
