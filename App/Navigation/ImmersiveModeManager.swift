//  ImmersiveModeManager.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Combine
import Foundation
import UIKit
import AwfulSettings

// MARK: - ImmersiveModeManager

/// Hides and shows the navigation bar, top-bar container, and toolbar in
/// response to scrolling on the posts page. Bars slide off-screen during
/// normal scroll (transform-driven) and fade in via alpha when the user
/// nears the bottom of the webview.
@MainActor
final class ImmersiveModeManager: NSObject {

    // MARK: - Constants

    /// Extra upward travel beyond the nav bar height so it fully clears the status bar
    /// and doesn't peek when the user scrolls near the top.
    private static let navBarHideOvertravel: CGFloat = 30
    /// Extra downward travel so the toolbar fully clears the bottom safe area
    /// and doesn't leave a few pixels peeking at the bottom of the screen.
    private static let toolbarHideOvertravel: CGFloat = 20
    private static let topProximityThreshold: CGFloat = 20
    private static let minScrollDelta: CGFloat = 0.5
    private static let snapToHiddenThreshold: CGFloat = 0.9
    private static let snapToVisibleThreshold: CGFloat = 0.1
    private static let progressiveRevealMultiplier: CGFloat = 2.0

    // MARK: - Dependencies

    weak var postsView: PostsPageView?
    weak var navigationController: UINavigationController?
    weak var renderView: RenderView?
    weak var toolbar: UIToolbar?
    weak var topBarContainer: UIView?

    // MARK: - Configuration

    @FoilDefaultStorage(Settings.immersiveModeEnabled) private var immersiveModeEnabled
    private var cancellables: Set<AnyCancellable> = []
    private var lastImmersiveModeEnabled: Bool = false

    override init() {
        super.init()
        lastImmersiveModeEnabled = immersiveModeEnabled

        $immersiveModeEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                let oldValue = lastImmersiveModeEnabled
                guard newValue != oldValue else { return }
                lastImmersiveModeEnabled = newValue
                if newValue {
                    postsView?.setNeedsLayout()
                    postsView?.layoutIfNeeded()
                } else {
                    immersiveProgress = 0.0
                    isInBottomFadeMode = false
                    bottomFadeProgress = 0.0
                    resetAllTransforms()
                    restoreBarAlphas()
                    safeAreaGradientView.alpha = 0.0
                    postsView?.setNeedsLayout()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - State Properties

    private var shouldProcessScroll: Bool {
        immersiveModeEnabled
        && !UIAccessibility.isVoiceOverRunning
    }

    /// 0.0 = bars fully visible, 1.0 = bars fully hidden.
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

    /// Bottom fade mode: when the user nears the bottom of the webview we
    /// reveal the bars via alpha (0 → 1) instead of the slide transform, so
    /// the final reveal doesn't snap while the scroll view is settling.
    private var isInBottomFadeMode = false
    private var bottomFadeProgress: CGFloat = 0.0

    /// True while `animateIntoBottomFade()`'s UIView.animate is still running.
    /// `updateBarsForBottomFade` checks this so later scroll ticks (e.g. from
    /// `snapToVisibleIfAtBottom` on `didEndDecelerating`) don't cancel the
    /// in-flight CAAnimation by hammering alpha to 1 via a disabled-actions
    /// transaction.
    private var isFadingIntoBottom = false

    // MARK: - UI Elements

    lazy var safeAreaGradientView: GradientView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        view.alpha = 0.0
        return view
    }()

    // MARK: - Computed Properties

    private var totalBarTravelDistance: CGFloat {
        if let cached = cachedTotalBarTravelDistance {
            return cached
        }

        guard let postsView = postsView,
              let window = postsView.window else { return 100 }

        let toolbarHeight = toolbar?.bounds.height ?? 44
        let bottomDistance = toolbarHeight + postsView.effectiveBottomInset

        if let navBar = findNavigationBar() {
            let navBarHeight = navBar.bounds.height
            let deviceSafeAreaTop = window.safeAreaInsets.top
            let topDistance = navBarHeight + deviceSafeAreaTop + Self.navBarHideOvertravel
            cachedTotalBarTravelDistance = max(bottomDistance, topDistance)
        } else {
            cachedTotalBarTravelDistance = bottomDistance
        }

        return cachedTotalBarTravelDistance ?? 100
    }

    private var isContentScrollableEnoughForImmersive: Bool {
        guard let scrollView = renderView?.scrollView else { return false }
        let scrollableHeight = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        return scrollableHeight > (totalBarTravelDistance * 2)
    }

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

    /// Force-reveal bars (e.g. when leaving the posts view).
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

    /// Bottom scroll inset to use while immersive mode is enabled. Computes the static
    /// (pre-transform) toolbar position so insets stay stable as the toolbar slides away.
    /// - Parameter fallbackInset: Value to return when refs are unavailable.
    func calculateBottomInset(fallbackInset: CGFloat) -> CGFloat {
        guard immersiveModeEnabled,
              let toolbar = toolbar,
              let postsView = postsView else {
            return fallbackInset
        }

        return postsView.effectiveBottomInset + toolbar.bounds.height
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

    func reapplyTransformsAfterLayout() {
        // Layout may have changed bar sizes, so invalidate the cached distance.
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

    func handleScrollViewDidScroll(
        _ scrollView: UIScrollView,
        isDragging: Bool,
        isDecelerating: Bool,
        isRefreshControlArmedOrTriggered: Bool
    ) {
        guard shouldProcessScroll,
              !isRefreshControlArmedOrTriggered else { return }

        // Check for bottom proximity even when not actively scrolling so the
        // reveal fires during momentum scrolling too.
        let distanceFromBottom = calculateDistanceFromBottom(scrollView)
        let barTravelDistance = totalBarTravelDistance
        let bottomFadeZone = barTravelDistance * Self.progressiveRevealMultiplier
        let isNearBottom = distanceFromBottom <= bottomFadeZone

        if isNearBottom {
            if !isInBottomFadeMode {
                isInBottomFadeMode = true
                bottomFadeProgress = 1.0
                animateIntoBottomFade()
            }
            lastScrollOffset = scrollView.contentOffset.y
            return
        }

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

        // Ignore tiny scroll deltas so tap-to-stop and minor rubber-band wobble
        // don't tick progress forward.
        guard abs(scrollDelta) > Self.minScrollDelta else {
            return
        }

        let incrementalProgress = immersiveProgress + (scrollDelta / barTravelDistance)
        immersiveProgress = incrementalProgress.clamp(0...1)

        lastScrollOffset = currentOffset
    }

    // MARK: - Private Methods

    /// Drives the slide transforms during normal scroll. Wrapped in a
    /// disabled-actions transaction so implicit CA animations don't lag the
    /// transforms behind the scroll gesture.
    private func updateBarsForImmersiveProgress() {
        guard !isUpdatingBars else { return }

        // Don't apply transforms when in bottom fade mode - alpha controls visibility instead
        guard !isInBottomFadeMode else { return }

        isUpdatingBars = true
        defer { isUpdatingBars = false }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        guard immersiveModeEnabled && immersiveProgress > 0 else {
            safeAreaGradientView.alpha = 0.0
            resetAllTransforms()
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
    }

    /// Fades bars back in when entering bottom fade mode. Snaps to
    /// "invisible at natural position" first (alphas to 0, transforms to
    /// identity, implicit actions suppressed) then animates alpha to 1 on
    /// the next runloop tick so the render server has observed the 0-alpha
    /// state before the CAAnimation starts interpolating from it.
    private func animateIntoBottomFade() {
        guard !isUpdatingBars else { return }
        isUpdatingBars = true
        defer { isUpdatingBars = false }

        let navBar = findNavigationBar()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        navBar?.alpha = 0
        topBarContainer?.alpha = 0
        toolbar?.alpha = 0
        resetAllTransforms()
        safeAreaGradientView.alpha = 0.0
        CATransaction.commit()

        // `isFadingIntoBottom` blocks concurrent `updateBarsForBottomFade`
        // calls (e.g. from `didEndDecelerating`) that would otherwise snap
        // alpha to 1 mid-animation and cancel the CAAnimation.
        isFadingIntoBottom = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                options: [.allowUserInteraction],
                animations: {
                    navBar?.alpha = 1
                    self.topBarContainer?.alpha = 1
                    self.toolbar?.alpha = 1
                },
                completion: { [weak self] _ in
                    self?.isFadingIntoBottom = false
                }
            )
        }
    }

    /// Scroll-driven alpha update while in bottom fade mode. Used for the
    /// fade-out as the user scrolls away from the bottom; the fade-in entry
    /// is handled by `animateIntoBottomFade()`.
    private func updateBarsForBottomFade() {
        guard !isUpdatingBars else { return }

        // Don't clobber the entry fade-in animation with a direct alpha=1
        // write.
        if isFadingIntoBottom && bottomFadeProgress >= 1.0 {
            return
        }

        isUpdatingBars = true
        defer { isUpdatingBars = false }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        resetAllTransforms()

        let alpha = bottomFadeProgress

        if let navBar = findNavigationBar() {
            navBar.alpha = alpha
        }
        topBarContainer?.alpha = alpha
        toolbar?.alpha = alpha

        // Gradient is only shown when bars are hidden via slide.
        safeAreaGradientView.alpha = 0.0
    }

    /// Leaves bottom fade mode and hands visibility back to the slide transforms.
    private func exitBottomFadeMode() {
        guard isInBottomFadeMode else { return }

        isInBottomFadeMode = false
        bottomFadeProgress = 0.0

        // Restore alpha to 1 so the transform (not alpha) drives visibility.
        restoreBarAlphas()

        _immersiveProgress = 1.0
        updateBarsForImmersiveProgress()
    }

    private func calculateNavigationBarTransform() -> CGFloat {
        guard let navBar = findNavigationBar() else { return 0 }

        let navBarHeight = navBar.bounds.height
        let deviceSafeAreaTop = postsView?.window?.safeAreaInsets.top ?? 44
        let totalUpwardDistance = navBarHeight + deviceSafeAreaTop + Self.navBarHideOvertravel
        return -totalUpwardDistance * immersiveProgress
    }

    private func calculateToolbarTransform() -> CGFloat {
        guard let toolbar = toolbar else { return 0 }

        let toolbarHeight = toolbar.bounds.height + Self.toolbarHideOvertravel
        // Match the inset the toolbar was laid out with — on iOS 26+ iPad this
        // can be larger than the system safe area (see `effectiveBottomInset`),
        // and translating by just the safe area would leave the top of the
        // toolbar visible.
        let bottomInset = postsView?.effectiveBottomInset ?? postsView?.window?.safeAreaInsets.bottom ?? 34
        let totalDownwardDistance = toolbarHeight + bottomInset
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

    /// Remaining scroll distance to the effective bottom of content. Handles
    /// content shorter than the scroll view (uses bounds height as the floor)
    /// and accounts for the adjusted bottom inset (typically the toolbar).
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

        if distanceFromBottom <= bottomFadeZone {
            let wasInBottomFadeMode = isInBottomFadeMode
            isInBottomFadeMode = true
            bottomFadeProgress = 1.0
            if wasInBottomFadeMode {
                updateBarsForBottomFade()
            } else {
                animateIntoBottomFade()
            }
        }
    }

    private func findNavigationBar() -> UINavigationBar? {
        if let cached = cachedNavigationBar {
            return cached
        }

        if let navBar = navigationController?.navigationBar {
            cachedNavigationBar = navBar
            return navBar
        }

        var responder: UIResponder? = postsView?.next
        while responder != nil {
            if let viewController = responder as? UIViewController,
               let navBar = viewController.navigationController?.navigationBar {
                cachedNavigationBar = navBar
                return navBar
            }
            responder = responder?.next
        }

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
