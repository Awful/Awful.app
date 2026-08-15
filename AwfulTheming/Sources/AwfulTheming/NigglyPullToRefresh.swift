//  NigglyPullToRefresh.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PullToRefresh
import UIKit

/// Installs the standard themed "niggly" refresh view on a scroll view, for screens that don't
/// inherit `TableViewController`/`CollectionViewController` (e.g. web-view-backed screens).
@MainActor
public final class NigglyPullToRefresh {

    private weak var scrollView: UIScrollView?
    private weak var niggly: NigglyRefreshLottieView?

    public init() {}

    deinit {
        // PullToRefresh observes the scroll view via KVO; detach before everything deallocates.
        scrollView?.removePullToRefresh(at: .top)
    }

    public func install(on scrollView: UIScrollView, theme: Theme, action: @escaping () -> Void) {
        guard scrollView.topPullToRefresh == nil else { return }
        self.scrollView = scrollView

        let niggly = NigglyRefreshLottieView(theme: theme)
        let targetSize = CGSize(width: scrollView.bounds.width, height: 0)
        niggly.bounds.size = niggly.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        niggly.autoresizingMask = .flexibleWidth
        niggly.backgroundColor = theme[uicolor: "backgroundColor"]
        self.niggly = niggly

        let animator = NigglyRefreshLottieView.RefreshAnimator(view: niggly)

        let pullToRefresh = PullToRefresh(refreshView: niggly, animator: animator, height: niggly.bounds.height, position: .top)
        pullToRefresh.animationDuration = 0.3
        pullToRefresh.initialSpringVelocity = 0
        pullToRefresh.springDamping = 1
        scrollView.addPullToRefresh(pullToRefresh, action: action)
    }

    public func themeDidChange(_ theme: Theme) {
        niggly?.theme = theme
        niggly?.backgroundColor = theme[uicolor: "backgroundColor"]
    }

    public func endRefreshing() {
        scrollView?.endRefreshing(at: .top)
    }
}
