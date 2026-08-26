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

    /// How far this scroll view has scrolled from its top, as 0...1, for driving
    /// the iOS 26 navigation bar's opaque→transparent transition.
    ///
    /// A dead zone at the top absorbs the point or two of drift that routinely
    /// survives loading and scroll restoration — a `WKWebView` anchored to a post
    /// lands at the body margin above it, not at exactly zero. Without it, an
    /// offset nobody can perceive as scrolled renders the nav bar in its
    /// half-faded mid-transition state and leaves it there.
    var navigationBarScrollProgress: CGFloat {
        let deadZone: CGFloat = 4
        let transitionDistance: CGFloat = 30

        // Resting at the top means an offset of -adjustedContentInset.top.
        let distanceFromTop = contentOffset.y + adjustedContentInset.top
        if distanceFromTop <= deadZone {
            return 0
        } else if distanceFromTop >= transitionDistance {
            return 1
        } else {
            return (distanceFromTop - deadZone) / (transitionDistance - deadZone)
        }
    }
}
