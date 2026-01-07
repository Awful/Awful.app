//  ImmersiveModeManager.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import UIKit
import AwfulSettings

// MARK: - ImmersiveModeManager

/// Manages immersive mode behavior for posts view
/// Handles hiding/showing navigation bars and toolbars with scroll gestures
@MainActor
final class ImmersiveModeManager: NSObject {

    // MARK: - Constants

    private static let bottomProximityDistance: CGFloat = 30
    private static let topProximityThreshold: CGFloat = 20
    private static let minScrollDelta: CGFloat = 0.5
    private static let snapToHiddenThreshold: CGFloat = 0.9
    private static let snapToVisibleThreshold: CGFloat = 0.1
    private static let bottomSnapThreshold: CGFloat = 0.15
    private static let bottomDistanceThreshold: CGFloat = 5.0
    private static let progressiveRevealMultiplier: CGFloat = 2.0

    // MARK: - Dependencies

    weak var postsView: PostsPageView?
    weak var navigationController: UINavigationController?
    weak var renderView: RenderView?
    weak var toolbar: UIToolbar?
    weak var topBarContainer: UIView?

    // MARK: - Configuration

    /// Whether immersive mode is enabled in settings
    @FoilDefaultStorage(Settings.immersiveModeEnabled) private var immersiveModeEnabled {
        didSet {
            if immersiveModeEnabled && !oldValue {
                postsView?.setNeedsLayout()
                postsView?.layoutIfNeeded()
            } else if !immersiveModeEnabled && oldValue {
                immersiveProgress = 0.0
                isInBottomFadeMode = false
                bottomFadeProgress = 0.0
                resetAllTransforms()
                restoreBarAlphas()
                safeAreaGradientView.alpha = 0.0
                postsView?.setNeedsLayout()
            }
        }
    }

    // MARK: - State Properties

    /// Whether scroll events should be processed for immersive mode
    private var shouldProcessScroll: Bool {
        immersiveModeEnabled
        && !UIAccessibility.isVoiceOverRunning
    }

    /// Immersive mode progress (0.0 = bars fully visible, 1.0 = bars fully hidden)
    private var _immersiveProgress: CGFloat = 0.0
    private var immersiveProgress: CGFloat {
        get { _immersiveProgress }
        set {
            let clampedValue = newValue.clamp(0...1)

            guard immersiveModeEnabled && !UIAccessibility.isVoiceOverRunning else {
                _immersiveProgress = 0.0
                return
            }

            guard _immersiveProgress != clampedValue else { return }

            _immersiveProgress = clampedValue
            updateBarsForImmersiveProgress()
        }
    }

    private var lastScrollOffset: CGFloat = 0
    private weak var cachedNavigationBar: UINavigationBar?
    private var isUpdatingBars = false
    private var cachedTotalBarTravelDistance: CGFloat?

    // Bottom fade mode state - used instead of sliding when at bottom of scroll
    private var isInBottomFadeMode = false
    private var bottomFadeProgress: CGFloat = 0.0  // 0 = transparent, 1 = opaque

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
        if let cached = cachedTotalBarTravelDistance {
            return cached
        }

        guard let postsView = postsView,
              let window = postsView.window else { return 100 }

        let toolbarHeight = toolbar?.bounds.height ?? 44
        let deviceSafeAreaBottom = window.safeAreaInsets.bottom
        let bottomDistance = toolbarHeight + deviceSafeAreaBottom

        if let navBar = findNavigationBar() {
            let navBarHeight = navBar.bounds.height
            let deviceSafeAreaTop = window.safeAreaInsets.top
            let topDistance = navBarHeight + deviceSafeAreaTop + Self.bottomProximityDistance
            cachedTotalBarTravelDistance = max(bottomDistance, topDistance)
        } else {
            cachedTotalBarTravelDistance = bottomDistance
        }

        return cachedTotalBarTravelDistance ?? 100
    }

    /// Check if content is scrollable enough to warrant immersive mode
    private var isContentScrollableEnoughForImmersive: Bool {
        guard let scrollView = renderView?.scrollView else { return false }
        let scrollableHeight = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        return scrollableHeight > (totalBarTravelDistance * 2)
    }

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
        cachedNavigationBar = nil
    }

    // MARK: - Public Methods

    /// Force exit immersive mode (useful for scroll-to-top/bottom actions)
    func exitImmersiveMode() {
        guard immersiveModeEnabled else { return }

        if isInBottomFadeMode {
            isInBottomFadeMode = false
            bottomFadeProgress = 0.0
            restoreBarAlphas()
        }

        guard immersiveProgress > 0 else { return }
        immersiveProgress = 0.0
    }

    func shouldAdjustScrollInsets() -> Bool {
        return immersiveModeEnabled
    }

    func calculateBottomInset(normalBottomInset: CGFloat) -> CGFloat {
        guard immersiveModeEnabled,
              let toolbar = toolbar,
              let postsView = postsView else {
            return normalBottomInset
        }

        let toolbarHeight = toolbar.sizeThatFits(postsView.bounds.size).height
        let staticToolbarY = postsView.bounds.maxY - postsView.layoutMargins.bottom - toolbarHeight
        return max(postsView.layoutMargins.bottom, postsView.bounds.maxY - staticToolbarY)
    }

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

    /// Apply immersive transforms after layout if needed
    func reapplyTransformsAfterLayout() {
        // Invalidate cached distance as layout may have changed bar sizes
        cachedTotalBarTravelDistance = nil

        if immersiveModeEnabled && immersiveProgress > 0 {
            updateBarsForImmersiveProgress()
        }
    }

    func shouldPositionTopBarForImmersive() -> Bool {
        return immersiveModeEnabled
    }

    func calculateTopBarY(normalY: CGFloat) -> CGFloat {
        guard immersiveModeEnabled else { return normalY }

        if let navBar = findNavigationBar() {
            return navBar.frame.maxY
        } else {
            return (postsView?.bounds.minY ?? 0) + (postsView?.layoutMargins.top ?? 0) + 44
        }
    }

    // MARK: - Scroll View Delegate Methods

    func handleScrollViewDidChangeContentSize(_ scrollView: UIScrollView) {
        if immersiveModeEnabled && !isContentScrollableEnoughForImmersive {
            immersiveProgress = 0
        }
    }

    func handleScrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastScrollOffset = scrollView.contentOffset.y

        if immersiveModeEnabled && scrollView.contentOffset.y < Self.topProximityThreshold {
            immersiveProgress = 0
        }
    }

    func handleScrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>,
        isRefreshControlArmedOrTriggered: Bool
    ) {
        if immersiveModeEnabled && !isRefreshControlArmedOrTriggered {
            if immersiveProgress > Self.snapToHiddenThreshold {
                immersiveProgress = 1.0
            } else if immersiveProgress < Self.snapToVisibleThreshold {
                immersiveProgress = 0.0
            }
        }
    }

    func handleScrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate: Bool,
        isRefreshControlArmedOrTriggered: Bool
    ) {
        guard !willDecelerate else { return }
        snapToVisibleIfAtBottom(scrollView, isRefreshControlArmedOrTriggered: isRefreshControlArmedOrTriggered)
    }

    func handleScrollViewDidEndDecelerating(
        _ scrollView: UIScrollView,
        isRefreshControlArmedOrTriggered: Bool
    ) {
        snapToVisibleIfAtBottom(scrollView, isRefreshControlArmedOrTriggered: isRefreshControlArmedOrTriggered)
    }

    /// Main scroll handling logic for immersive mode
    func handleScrollViewDidScroll(
        _ scrollView: UIScrollView,
        isDragging: Bool,
        isDecelerating: Bool,
        isRefreshControlArmedOrTriggered: Bool
    ) {
        guard shouldProcessScroll,
              !isRefreshControlArmedOrTriggered else { return }

        // Always check for bottom, even when not actively scrolling
        let distanceFromBottom = calculateDistanceFromBottom(scrollView)
        let barTravelDistance = totalBarTravelDistance
        let bottomFadeZone = barTravelDistance * Self.progressiveRevealMultiplier
        let isNearBottom = distanceFromBottom <= bottomFadeZone

        if isNearBottom {
            if !isInBottomFadeMode {
                isInBottomFadeMode = true
                bottomFadeProgress = 1.0
                updateBarsForBottomFade()
            }
            lastScrollOffset = scrollView.contentOffset.y
            return
        }

        // For everything else, require active scrolling
        guard isDragging || isDecelerating else { return }

        let currentOffset = scrollView.contentOffset.y
        let scrollDelta = currentOffset - lastScrollOffset

        guard isContentScrollableEnoughForImmersive else {
            if isInBottomFadeMode {
                exitBottomFadeMode()
            }
            immersiveProgress = 0
            lastScrollOffset = currentOffset
            return
        }

        if currentOffset < Self.topProximityThreshold {
            if isInBottomFadeMode {
                exitBottomFadeMode()
            }
            immersiveProgress = 0
            lastScrollOffset = currentOffset
            return
        }

        // Handle fading out when scrolling away from bottom
        if isInBottomFadeMode {
            let fadeOutDistance: CGFloat = 50.0
            let distancePastThreshold = distanceFromBottom - bottomFadeZone
            let fadeProgress = 1.0 - (distancePastThreshold / fadeOutDistance)
            bottomFadeProgress = fadeProgress.clamp(0...1)

            if bottomFadeProgress > 0 {
                updateBarsForBottomFade()
                lastScrollOffset = currentOffset
                return
            } else {
                exitBottomFadeMode()
            }
        }

        // For normal sliding behavior, ignore tiny scroll deltas
        guard abs(scrollDelta) > Self.minScrollDelta else {
            return
        }

        let incrementalProgress = immersiveProgress + (scrollDelta / barTravelDistance)
        immersiveProgress = incrementalProgress.clamp(0...1)

        lastScrollOffset = currentOffset
    }

    // MARK: - Private Methods

    /// Updates the visual state of navigation bars and toolbar based on current immersive progress
    /// Uses CATransaction.setDisableActions to prevent implicit animations during scroll-driven transforms
    private func updateBarsForImmersiveProgress() {
        guard !isUpdatingBars else { return }

        // Don't apply transforms when in bottom fade mode - alpha controls visibility instead
        guard !isInBottomFadeMode else { return }

        isUpdatingBars = true
        defer { isUpdatingBars = false }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        guard immersiveModeEnabled && immersiveProgress > 0 else {
            safeAreaGradientView.alpha = 0.0
            resetAllTransforms()
            CATransaction.commit()
            return
        }

        safeAreaGradientView.alpha = immersiveProgress

        let navBarTransform = calculateNavigationBarTransform()
        if let navBar = findNavigationBar() {
            navBar.transform = CGAffineTransform(translationX: 0, y: navBarTransform)
        }

        topBarContainer?.transform = CGAffineTransform(translationX: 0, y: navBarTransform)

        if let toolbar = toolbar {
            let toolbarTransform = calculateToolbarTransform()
            toolbar.transform = CGAffineTransform(translationX: 0, y: toolbarTransform)
        }

        CATransaction.commit()
    }

    /// Updates bar visibility using alpha/opacity for bottom fade mode
    /// Bars remain in their normal position (no transforms) and fade in/out
    private func updateBarsForBottomFade() {
        guard !isUpdatingBars else { return }
        isUpdatingBars = true
        defer { isUpdatingBars = false }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        resetAllTransforms()

        let alpha = bottomFadeProgress

        if let navBar = findNavigationBar() {
            navBar.alpha = alpha
        }
        topBarContainer?.alpha = alpha
        toolbar?.alpha = alpha

        // Gradient view should be hidden when bars are visible via fade
        safeAreaGradientView.alpha = 0.0

        CATransaction.commit()
    }

    /// Exits bottom fade mode and restores bars to hidden state via transforms
    private func exitBottomFadeMode() {
        guard isInBottomFadeMode else { return }

        isInBottomFadeMode = false
        bottomFadeProgress = 0.0

        // Restore alpha to full before applying transforms
        restoreBarAlphas()

        // Set immersive progress to fully hidden and apply transforms
        _immersiveProgress = 1.0
        updateBarsForImmersiveProgress()
    }

    private func calculateNavigationBarTransform() -> CGFloat {
        guard let navBar = findNavigationBar() else { return 0 }

        let navBarHeight = navBar.bounds.height
        let deviceSafeAreaTop = postsView?.window?.safeAreaInsets.top ?? 44
        let totalUpwardDistance = navBarHeight + deviceSafeAreaTop + Self.bottomProximityDistance
        return -totalUpwardDistance * immersiveProgress
    }

    private func calculateToolbarTransform() -> CGFloat {
        guard let toolbar = toolbar else { return 0 }

        let toolbarHeight = toolbar.bounds.height
        let deviceSafeAreaBottom = postsView?.window?.safeAreaInsets.bottom ?? 34
        let totalDownwardDistance = toolbarHeight + deviceSafeAreaBottom
        return totalDownwardDistance * immersiveProgress
    }

    private func resetAllTransforms() {
        if let foundNavBar = findNavigationBar() {
            foundNavBar.transform = .identity
        }
        topBarContainer?.transform = .identity
        toolbar?.transform = .identity
    }

    private func restoreBarAlphas() {
        if let navBar = findNavigationBar() {
            navBar.alpha = 1.0
        }
        topBarContainer?.alpha = 1.0
        toolbar?.alpha = 1.0
    }

    /// Calculates the remaining scrollable distance from current position to the bottom of content
    ///
    /// The calculation accounts for:
    /// - Content that is shorter than the scroll view bounds (uses bounds height as minimum)
    /// - Bottom content inset (typically the toolbar height)
    /// - Current scroll offset
    ///
    /// - Returns: Distance in points from current scroll position to the effective bottom
    private func calculateDistanceFromBottom(_ scrollView: UIScrollView) -> CGFloat {
        let contentHeight = scrollView.contentSize.height
        let adjustedBottom = scrollView.adjustedContentInset.bottom
        let maxOffsetY = max(contentHeight, scrollView.bounds.height - adjustedBottom) - scrollView.bounds.height + adjustedBottom
        return maxOffsetY - scrollView.contentOffset.y
    }

    private func snapToVisibleIfAtBottom(_ scrollView: UIScrollView, isRefreshControlArmedOrTriggered: Bool) {
        guard immersiveModeEnabled && !isRefreshControlArmedOrTriggered && isContentScrollableEnoughForImmersive else { return }

        let distanceFromBottom = calculateDistanceFromBottom(scrollView)
        let bottomFadeZone = totalBarTravelDistance * Self.progressiveRevealMultiplier

        // If near bottom, ensure bars are fully visible via fade mode
        if distanceFromBottom <= bottomFadeZone {
            if !isInBottomFadeMode {
                isInBottomFadeMode = true
            }
            // Snap to fully visible when scroll stops near bottom
            bottomFadeProgress = 1.0
            updateBarsForBottomFade()
        }
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
}

// MARK: - Helper Extensions

private extension Comparable {
    func clamp(_ limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
