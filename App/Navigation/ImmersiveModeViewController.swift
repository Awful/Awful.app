//  ImmersiveModeViewController.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import UIKit
import AwfulSettings

/// Protocol for view controllers that support immersion mode
/// This allows NavigationController to properly handle transitions
@MainActor
protocol ImmersiveModeViewController {
    /// Called when the view controller should exit immersion mode
    /// This is typically called when transitioning away from the view controller
    func exitImmersionMode()
}

// MARK: - ImmersionModeManager

/// Manages immersion mode behavior for posts view
/// Handles hiding/showing navigation bars and toolbars with scroll gestures
final class ImmersionModeManager: NSObject {

    // MARK: - Dependencies

    /// The posts view that contains the bars to be transformed
    weak var postsView: PostsPageView?

    /// The navigation controller for accessing the navigation bar
    weak var navigationController: UINavigationController?

    /// The render view containing the scroll view
    weak var renderView: RenderView?

    /// The toolbar to be transformed
    weak var toolbar: UIToolbar?

    /// The top bar container to be transformed
    weak var topBarContainer: UIView?

    // MARK: - Configuration

    /// Whether immersion mode is enabled in settings
    @FoilDefaultStorage(Settings.immersionModeEnabled) private var immersionModeEnabled {
        didSet {
            if immersionModeEnabled && !oldValue {
                // Just enabled - may need to update layout
                postsView?.setNeedsLayout()
                postsView?.layoutIfNeeded()
            } else if !immersionModeEnabled && oldValue {
                // Just disabled - reset everything
                immersionProgress = 0.0
                resetAllTransforms()
                safeAreaGradientView.alpha = 0.0
                postsView?.setNeedsLayout()
            }
        }
    }

    // MARK: - State Properties

    /// Progress of immersion mode (0.0 = bars fully visible, 1.0 = bars fully hidden)
    private var immersionProgress: CGFloat = 0.0 {
        didSet {
            guard immersionModeEnabled && !UIAccessibility.isVoiceOverRunning else {
                immersionProgress = 0.0
                return
            }
            let oldProgress = oldValue
            immersionProgress = immersionProgress.clamp(0...1)
            if oldProgress != immersionProgress {
                updateBarsForImmersionProgress()
            }
        }
    }

    /// Last scroll offset to calculate delta
    private var lastScrollOffset: CGFloat = 0

    /// Cached navigation bar reference for performance
    private weak var cachedNavigationBar: UINavigationBar?

    /// Flag to prevent recursive updates
    private var isUpdatingBars = false

    // MARK: - UI Elements

    lazy var safeAreaGradientView: GradientView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        view.alpha = 0.0
        return view
    }()

    // MARK: - Computed Properties

    /// Actual distance bars travel when hiding (calculated dynamically based on bar heights)
    private var totalBarTravelDistance: CGFloat {
        guard let postsView = postsView,
              let window = postsView.window else { return 100 }

        let toolbarHeight = toolbar?.bounds.height ?? 44
        let deviceSafeAreaBottom = window.safeAreaInsets.bottom
        let bottomDistance = toolbarHeight + deviceSafeAreaBottom

        if let navBar = findNavigationBar() {
            let navBarHeight = navBar.bounds.height
            let deviceSafeAreaTop = window.safeAreaInsets.top
            let topDistance = navBarHeight + deviceSafeAreaTop + 30
            return max(bottomDistance, topDistance)
        }

        return bottomDistance
    }

    /// Check if content is scrollable enough to warrant immersion mode
    private var isContentScrollableEnoughForImmersion: Bool {
        guard let scrollView = renderView?.scrollView else { return false }
        let scrollableHeight = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        return scrollableHeight > (totalBarTravelDistance * 2)
    }

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Configure the manager with required view references
    func configure(
        postsView: PostsPageView,
        navigationController: UINavigationController?,
        renderView: RenderView,
        toolbar: UIToolbar,
        topBarContainer: UIView
    ) {
        self.postsView = postsView
        self.navigationController = navigationController
        self.renderView = renderView
        self.toolbar = toolbar
        self.topBarContainer = topBarContainer

        // Clear cached navigation bar when configuration changes
        cachedNavigationBar = nil
    }

    // MARK: - Public Methods

    /// Force exit immersion mode (useful for scroll-to-top/bottom actions)
    func exitImmersionMode() {
        guard immersionModeEnabled && immersionProgress > 0 else { return }
        immersionProgress = 0.0

        // Explicitly reset navigation bar transform when exiting immersion mode
        // This ensures the navigation bar is visible when returning to previous view
        if let navBar = findNavigationBar() {
            navBar.transform = .identity
        }
    }

    /// Check if immersion mode should affect scroll insets
    func shouldAdjustScrollInsets() -> Bool {
        return immersionModeEnabled
    }

    /// Calculate bottom inset adjustment for immersion mode
    func calculateBottomInset(normalBottomInset: CGFloat) -> CGFloat {
        guard immersionModeEnabled,
              let toolbar = toolbar,
              let postsView = postsView else {
            return normalBottomInset
        }

        // During immersion mode, use the static toolbar position (without transforms)
        // to keep contentInset constant and prevent scroll interference
        let toolbarHeight = toolbar.sizeThatFits(postsView.bounds.size).height
        let staticToolbarY = postsView.bounds.maxY - postsView.layoutMargins.bottom - toolbarHeight
        return max(postsView.layoutMargins.bottom, postsView.bounds.maxY - staticToolbarY)
    }

    /// Update layout for gradient view
    func updateGradientLayout(in containerView: UIView) {
        guard #available(iOS 26.0, *) else { return }

        let gradientHeight: CGFloat = containerView.window?.safeAreaInsets.top ?? containerView.safeAreaInsets.top
        safeAreaGradientView.frame = CGRect(
            x: containerView.bounds.minX,
            y: containerView.bounds.minY,
            width: containerView.bounds.width,
            height: gradientHeight
        )
    }

    /// Apply immersion transforms after layout if needed
    func reapplyTransformsAfterLayout() {
        if immersionModeEnabled && immersionProgress > 0 {
            updateBarsForImmersionProgress()
        }
    }

    /// Determine if top bar should be positioned for immersion mode
    func shouldPositionTopBarForImmersion() -> Bool {
        return immersionModeEnabled
    }

    /// Calculate top bar Y position for immersion mode
    func calculateTopBarY(normalY: CGFloat) -> CGFloat {
        guard immersionModeEnabled else { return normalY }

        // In immersion mode, position it to attach directly to the bottom edge of the navigation bar
        if let navBar = findNavigationBar() {
            // Position directly at the bottom edge of the nav bar (no gap)
            return navBar.frame.maxY
        } else {
            // Fallback to estimated position
            return postsView?.bounds.minY ?? 0 + (postsView?.layoutMargins.top ?? 0) + 44
        }
    }

    // MARK: - Scroll View Delegate Methods

    /// Handle scroll view content size changes
    func handleScrollViewDidChangeContentSize(_ scrollView: UIScrollView) {
        // Check if content is still scrollable enough for immersion mode
        if immersionModeEnabled && !isContentScrollableEnoughForImmersion {
            // Reset bars to visible if content becomes too short
            immersionProgress = 0
        }
    }

    /// Handle scroll view will begin dragging
    func handleScrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastScrollOffset = scrollView.contentOffset.y

        // On first drag, ensure bars start visible if at top
        if immersionModeEnabled && scrollView.contentOffset.y < 20 {
            immersionProgress = 0
        }
    }

    /// Handle scroll view will end dragging
    func handleScrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>,
        isRefreshControlArmedOrTriggered: Bool
    ) {
        // Optional: Snap to complete if very close to fully shown/hidden
        if immersionModeEnabled && !isRefreshControlArmedOrTriggered {
            if immersionProgress > 0.9 {
                // Snap to fully hidden
                immersionProgress = 1.0
            } else if immersionProgress < 0.1 {
                // Snap to fully visible
                immersionProgress = 0.0
            }
            // Otherwise leave at current position
        }
    }

    /// Handle scroll view did end dragging
    func handleScrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate: Bool,
        isRefreshControlArmedOrTriggered: Bool
    ) {
        guard !willDecelerate else { return }

        // Handle immersion mode completion when drag ends
        if immersionModeEnabled && !isRefreshControlArmedOrTriggered && isContentScrollableEnoughForImmersion {
            // Check if we're at the very bottom
            let contentHeight = scrollView.contentSize.height
            let adjustedBottom = scrollView.adjustedContentInset.bottom
            let maxOffsetY = max(contentHeight, scrollView.bounds.height - adjustedBottom) - scrollView.bounds.height + adjustedBottom
            let distanceFromBottom = maxOffsetY - scrollView.contentOffset.y

            // Only snap to fully visible if we're at the very bottom AND bars are almost visible
            // This prevents jarring snaps and lets the progressive reveal complete naturally
            if distanceFromBottom <= 5 && immersionProgress < 0.15 {
                immersionProgress = 0
            }
        }
    }

    /// Handle scroll view did end decelerating
    func handleScrollViewDidEndDecelerating(
        _ scrollView: UIScrollView,
        isRefreshControlArmedOrTriggered: Bool
    ) {
        // Handle immersion mode completion when deceleration ends
        if immersionModeEnabled && !isRefreshControlArmedOrTriggered && isContentScrollableEnoughForImmersion {
            // Check if we're at the very bottom
            let contentHeight = scrollView.contentSize.height
            let adjustedBottom = scrollView.adjustedContentInset.bottom
            let maxOffsetY = max(contentHeight, scrollView.bounds.height - adjustedBottom) - scrollView.bounds.height + adjustedBottom
            let distanceFromBottom = maxOffsetY - scrollView.contentOffset.y

            // Only snap to fully visible if we're at the very bottom AND bars are almost visible
            // This prevents jarring snaps and lets the progressive reveal complete naturally
            if distanceFromBottom <= 5 && immersionProgress < 0.15 {
                immersionProgress = 0
            }
        }
    }

    /// Main scroll handling logic for immersion mode
    func handleScrollViewDidScroll(
        _ scrollView: UIScrollView,
        isDragging: Bool,
        isDecelerating: Bool,
        isRefreshControlArmedOrTriggered: Bool
    ) {
        // Handle immersion mode drawer-style behavior
        guard immersionModeEnabled,
              !UIAccessibility.isVoiceOverRunning,
              (isDragging || isDecelerating),
              !isRefreshControlArmedOrTriggered else { return }

        let currentOffset = scrollView.contentOffset.y
        let scrollDelta = currentOffset - lastScrollOffset

        // Only proceed if content is scrollable enough for immersion mode
        guard isContentScrollableEnoughForImmersion else {
            // Force bars visible if content is too short
            immersionProgress = 0
            lastScrollOffset = currentOffset
            return
        }

        // Dead zone at top to prevent jitter
        if currentOffset < 20 {
            // When very close to top, force bars to be fully visible
            immersionProgress = 0
            lastScrollOffset = currentOffset
            return
        }

        // Minimum scroll delta threshold to prevent micro-movement responses
        guard abs(scrollDelta) > 0.5 else {
            // Ignore tiny movements that cause jitter
            return
        }

        let contentHeight = scrollView.contentSize.height
        let adjustedBottom = scrollView.adjustedContentInset.bottom
        let maxOffsetY = max(contentHeight, scrollView.bounds.height - adjustedBottom) - scrollView.bounds.height + adjustedBottom

        let barTravelDistance = totalBarTravelDistance
        let distanceFromBottom = maxOffsetY - currentOffset
        let nearBottomThreshold = barTravelDistance * 2.0
        let isNearBottom = distanceFromBottom <= nearBottomThreshold

        if isNearBottom && scrollDelta > 0 {
            // Scrolling down toward bottom - progressively reveal bars
            let targetProgress = (distanceFromBottom / nearBottomThreshold).clamp(0...1)
            let incrementalProgress = immersionProgress + (scrollDelta / barTravelDistance)
            immersionProgress = min(incrementalProgress, targetProgress).clamp(0...1)
        } else {
            // Normal 1:1 scroll response
            let incrementalProgress = immersionProgress + (scrollDelta / barTravelDistance)
            immersionProgress = incrementalProgress.clamp(0...1)
        }

        lastScrollOffset = currentOffset
    }

    // MARK: - Private Methods

    private func updateBarsForImmersionProgress() {
        guard !isUpdatingBars else { return }
        isUpdatingBars = true
        defer { isUpdatingBars = false }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        guard immersionModeEnabled && immersionProgress > 0 else {
            safeAreaGradientView.alpha = 0.0
            resetAllTransforms()
            CATransaction.commit()
            return
        }

        safeAreaGradientView.alpha = immersionProgress

        var navBarTransform: CGFloat = 0
        if let navBar = findNavigationBar() {
            let navBarHeight = navBar.bounds.height
            let deviceSafeAreaTop = postsView?.window?.safeAreaInsets.top ?? 44
            let totalUpwardDistance = navBarHeight + deviceSafeAreaTop + 30
            navBarTransform = -totalUpwardDistance * immersionProgress
            navBar.transform = CGAffineTransform(translationX: 0, y: navBarTransform)
        }

        topBarContainer?.transform = CGAffineTransform(translationX: 0, y: navBarTransform)

        if let toolbar = toolbar {
            let toolbarHeight = toolbar.bounds.height
            let deviceSafeAreaBottom = postsView?.window?.safeAreaInsets.bottom ?? 34
            let totalDownwardDistance = toolbarHeight + deviceSafeAreaBottom
            toolbar.transform = CGAffineTransform(translationX: 0, y: totalDownwardDistance * immersionProgress)
        }

        CATransaction.commit()
    }

    /// Reset all transforms to identity
    private func resetAllTransforms() {
        if let foundNavBar = findNavigationBar() {
            foundNavBar.transform = .identity
        }
        topBarContainer?.transform = .identity
        toolbar?.transform = .identity
    }

    private func updateScrollViewInsetsIfNeeded() {
        postsView?.updateScrollViewInsets()
    }

    private func findNavigationBar() -> UINavigationBar? {
        if let cached = cachedNavigationBar {
            return cached
        }

        // Try to get it from the navigation controller we were configured with
        if let navBar = navigationController?.navigationBar {
            cachedNavigationBar = navBar
            return navBar
        }

        // Fallback: traverse responder chain from posts view
        var responder: UIResponder? = postsView?.next
        while responder != nil {
            if let viewController = responder as? UIViewController,
               let navBar = viewController.navigationController?.navigationBar {
                cachedNavigationBar = navBar
                return navBar
            }
            responder = responder?.next
        }

        // Last resort: try to get from window's root view controller
        if let window = postsView?.window,
           let rootNav = window.rootViewController as? UINavigationController {
            cachedNavigationBar = rootNav.navigationBar
            return rootNav.navigationBar
        }

        return nil
    }

    /// Clear cached navigation bar when view hierarchy changes
    func clearNavigationBarCache() {
        cachedNavigationBar = nil
    }
}

// MARK: - Helper Extensions

private extension Comparable {
    func clamp(_ limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
