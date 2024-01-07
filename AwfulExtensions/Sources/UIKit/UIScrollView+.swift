//  UIScrollView+.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

public extension UIScrollView {
    /// The scroll view's content offset as a proportion of the content size (where content size does not include any content inset).
    var fractionalContentOffset: CGPoint {
        let contentOffset = self.contentOffset
        let contentSize = self.contentSize
        return CGPoint(
            x: contentSize.width != 0 ? contentOffset.x / contentSize.width : 0,
            y: contentSize.height != 0 ? contentOffset.y / contentSize.height : 0)
    }
}
