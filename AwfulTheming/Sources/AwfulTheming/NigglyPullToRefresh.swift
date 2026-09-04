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
        // A deinit is never actor-isolated, so get back onto the main actor to do it. The strong
        // capture keeps the scroll view (and its observer) alive until the detach has run.
        guard let scrollView else { return }
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                scrollView.removePullToRefresh(at: .top)
            }
        } else {
            Task { @MainActor in
                scrollView.removePullToRefresh(at: .top)
            }
        }
    }

    public func install(on scrollView: UIScrollView, theme: Theme, action: @escaping () -> Void) {
        guard scrollView.topPullToRefresh == nil else { return }
        self.scrollView = scrollView

        let niggly = NigglyRefreshLottieView(theme: theme)
        let targetSize = CGSize(width: scrollView.bounds.width, height: 0)
        niggly.bounds.size = niggly.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        niggly.autoresizingMask = .flexibleWidth
        niggly.backgroundColor = Self.backgroundColor(for: theme)
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
        niggly?.backgroundColor = Self.backgroundColor(for: theme)
    }

    /// Under Liquid Glass the refresh view stays transparent: it sits in the scroll view's top
    /// inset, which `UIScrollView.applyNavigationBarPlatterBackdrop` paints the bar colour so the
    /// glass bar buttons read as dark on a dark bar, and an opaque refresh view there would be
    /// sampled instead. The view behind is the same theme background, so nothing looks different.
    private static func backgroundColor(for theme: Theme) -> UIColor? {
        LiquidGlass.isEnabled ? nil : theme[uicolor: "backgroundColor"]
    }

    public func endRefreshing() {
        scrollView?.endRefreshing(at: .top)
    }
}
