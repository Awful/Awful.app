//  ContentRefreshable.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A screen whose content can be reloaded from outside a gesture: keyboard shortcuts ask for
/// the same refresh that pull-to-refresh performs.
public protocol ContentRefreshable: AnyObject {

    /// Reloads the screen's content exactly as pull-to-refresh would, including its spinner.
    /// Implementations should ignore the request while a refresh is already in flight.
    func refreshContent()
}

/// A screen whose main list can be sent back to its top, as re-tapping its tab does.
public protocol ScrollableToTop: AnyObject {
    func scrollToTop(animated: Bool)
}

public extension UIScrollView {
    /// Scrolls to the very top of the content, under any bars that inset it.
    func scrollToTop(animated: Bool) {
        let top = CGPoint(x: contentOffset.x, y: -adjustedContentInset.top)
        setContentOffset(top, animated: animated)
    }
}

extension CollectionViewController: ScrollableToTop {
    public func scrollToTop(animated: Bool) {
        collectionView.scrollToTop(animated: animated)
    }
}

extension HostedCollectionViewController: ScrollableToTop {
    public func scrollToTop(animated: Bool) {
        collectionView.scrollToTop(animated: animated)
    }
}
