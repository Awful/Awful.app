//  PostsPageView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import os
import ScrollViewDelegateMultiplexer
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PostsPageView")

/**
 Manages a posts page's render view, top bar, refresh control, and toolbar.

 Since both the top bar and refresh control depend on scroll view shenanigans, it makes sense to manage them in the same place (mostly so we can mediate any conflict between them). And since our supported iOS versions include several different approaches to safe areas, top/bottom anchors, and layout margins, we can deal with some of that here too. For more about the layout margins, see commentary in `PostsPageViewController.viewDidLoad()`.
 */
final class PostsPageView: UIView {

    @FoilDefaultStorage(Settings.darkMode) private var darkMode
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    @FoilDefaultStorage(Settings.immersionModeEnabled) private var immersionModeEnabled
    var viewHasBeenScrolledOnce: Bool = false
    
    // MARK: Immersion mode
    
    /// Callback to hide/show the navigation bar (set by PostsPageViewController)
    var setNavigationBarHidden: ((Bool, Bool) -> Void)?
    
    private var immersionModeState: ImmersionModeState = .normal {
        didSet {
            let oldDescription = "\(oldValue)"
            let newDescription = "\(immersionModeState)"
            logger.debug("immersion mode transitioned from \(oldDescription) to \(newDescription)")
            
            switch immersionModeState {
            case .normal:
                showBarsAnimated(true)
            case .immersed:
                hideBarsAnimated(true)
            case .transitioning:
                break
            }
        }
    }
    
    // MARK: Loading view

    var loadingView: UIView? {
        get { return loadingViewContainer.subviews.first }
        set {
            loadingViewContainer.subviews.forEach { $0.removeFromSuperview() }
            if let newValue = newValue {
                loadingViewContainer.addSubview(newValue, constrainEdges: .all)
            }
            loadingViewContainer.isHidden = newValue == nil
        }
    }

    private lazy var loadingViewContainer = LoadingViewContainer()

    /// Trivial subclass to identify the view when debugging.
    final class LoadingViewContainer: UIView {}

    // MARK: Refresh control

    var didStartRefreshing: (() -> Void)?

    var refreshControl: (UIView & PostsPageRefreshControlContent)? {
        didSet {
            oldValue?.removeFromSuperview()

            if let refreshControl = refreshControl {
                if refreshControlContainer.frame.height == 0 {
                    refreshControlContainer.frame.size.height = 44 // avoid unhelpful unsatisfiable constraint console messages
                }

                refreshControl.translatesAutoresizingMaskIntoConstraints = false
                refreshControlContainer.addSubview(refreshControl)
                
                let containerMargins = refreshControlContainer.layoutMarginsGuide
                
                if frogAndGhostEnabled == false {
                    NSLayoutConstraint.activate([
                        refreshControl.leftAnchor.constraint(equalTo: containerMargins.leftAnchor),
                        containerMargins.rightAnchor.constraint(equalTo: refreshControl.rightAnchor),
                        refreshControl.topAnchor.constraint(equalTo: containerMargins.topAnchor),
                        containerMargins.bottomAnchor.constraint(equalTo: refreshControl.bottomAnchor)])
                } else {
                    // arrow view is hidden behind the toolbar and revealed when pulled up
                    if refreshControl is PostsPageRefreshArrowView {
                        NSLayoutConstraint.activate([
                            refreshControl.leftAnchor.constraint(equalTo: containerMargins.leftAnchor),
                            refreshControl.topAnchor.constraint(equalTo: containerMargins.topAnchor),
                            containerMargins.rightAnchor.constraint(equalTo: refreshControl.rightAnchor),
                            containerMargins.bottomAnchor.constraint(equalTo: refreshControl.bottomAnchor)
                        ])
                    }
                    // spinner view is visible above the toolbar, before any scroll triggers occur
                    if refreshControl is GetOutFrogRefreshSpinnerView {
                        NSLayoutConstraint.activate([
                            refreshControl.leftAnchor.constraint(equalTo: containerMargins.leftAnchor),
                            containerMargins.rightAnchor.constraint(equalTo: refreshControl.rightAnchor),
                            containerMargins.bottomAnchor.constraint(equalTo: refreshControl.bottomAnchor)
                        ])
                    }
                }
   
                refreshControl.state = refreshControlState
            }

            if refreshControl == nil {
                refreshControlState = .disabled
            } else {
                if refreshControlState == .disabled {
                    refreshControlState = .ready
                }
            }
        }
    }

    private let refreshControlContainer: RefreshControlContainer = {
        let refreshControlContainer = RefreshControlContainer()
        refreshControlContainer.insetsLayoutMarginsFromSafeArea = false
        refreshControlContainer.layoutMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        return refreshControlContainer
    }()

    private var refreshControlState: RefreshControlState = .ready {
        willSet {
            switch (refreshControlState, newValue) {
            case (_, .disabled),
                 (.disabled, .ready):
                break

            case (.ready, .armed),
                 (.ready, .awaitingScrollEnd),
                 (.ready, .triggered):
                break

            case (.armed, .armed),
                 (.armed, .awaitingScrollEnd),
                 (.armed, .triggered),
                 (.armed, .ready):
                break

            case (.awaitingScrollEnd, .ready):
                break

            case (.triggered, .armed),
                 (.triggered, .awaitingScrollEnd),
                 (.triggered, .refreshing):
                break

            case (.refreshing, .ready):
                break

            case (.disabled, _),
                 (.ready, _),
                 (.armed, _),
                 (.awaitingScrollEnd, _),
                 (.triggered, _),
                 (.refreshing, _):
                assertionFailure("attempted invalid state transition from \(refreshControlState) to \(newValue)")
            }
        }
        didSet {
            let oldDescription = "\(oldValue)"
            let newDescription = "\(refreshControlState)"
            logger.debug("refresh control transitioned from \(oldDescription) to \(newDescription)")

            refreshControl?.state = refreshControlState

            switch refreshControlState {
            case .ready, .awaitingScrollEnd, .disabled:
                setNeedsLayout()

            case .refreshing:
                setNeedsLayout()
                layoutIfNeeded()
                didStartRefreshing?()

                let scrollView = renderView.scrollView
                if !scrollView.isDragging {
                    var contentOffset = scrollView.contentOffset
                    contentOffset.y = max(scrollView.contentSize.height, scrollView.bounds.height)
                        - scrollView.bounds.height
                        + refreshControlContainer.layoutFittingCompressedHeight(targetWidth: bounds.width)
                    scrollView.setContentOffset(contentOffset, animated: true)
                }

            case .armed, .triggered:
                break
            }
        }
    }

    // MARK: Top bar

    var topBar: PostsPageTopBar {
        return topBarContainer.topBar
    }

    private let topBarContainer = TopBarContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 44) /* somewhat arbitrary size to avoid unhelpful unsatisfiable constraints console messages */)

    private var topBarState: TopBarState {
        didSet {
            let oldDescription = "\(oldValue)"
            let newDescription = "\(topBarState)"
            logger.debug("top bar transitioned from \(oldDescription) to \(newDescription)")

            switch (oldValue, topBarState) {
            case (.hidden, .appearing),
                 (.hidden, .visible),
                 (.visible, .hidden),
                 (_, .appearing),
                 (.appearing, _),
                 (_, .disappearing),
                 (.disappearing, _),
                 (.hidden, .alwaysVisible),
                 (.alwaysVisible, .hidden):
                updateTopBarContainerFrameAndScrollViewInsets()

            case (.hidden, _),
                 (.visible, _),
                 (.alwaysVisible, _):
                break
            }
        }
    }

    // MARK: Remaining subviews

    private var willBeginDraggingContentOffset: CGPoint?

    private(set) lazy var renderView = RenderView()

    private var scrollViewDelegateMux: ScrollViewDelegateMultiplexer?

    private lazy var toolbar: UIView = {
        return Toolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
    }()
    
    /// Provides access to the toolbar for PostsPageViewController
    var toolbarView: UIView {
        return toolbar
    }
    
    /// Returns true if the toolbar is translucent (only available for standard UIToolbar)
    var isToolbarTranslucent: Bool {
        if let standardToolbar = toolbar as? Toolbar {
            return standardToolbar.isTranslucent
        }
        return false // Custom toolbar is never translucent
    }
    
    /// Sets toolbar appearance (only available for standard UIToolbar)
    func setToolbarAppearance(_ appearance: UIToolbarAppearance) {
        guard let standardToolbar = toolbar as? Toolbar else { return }
        standardToolbar.standardAppearance = appearance
        standardToolbar.compactAppearance = appearance
    }
    
    /// Sets toolbar scroll edge appearance (only available for standard UIToolbar) 
    func setToolbarScrollEdgeAppearance(_ appearance: UIToolbarAppearance) {
        guard let standardToolbar = toolbar as? Toolbar else { return }
        if #available(iOS 15.0, *) {
            standardToolbar.scrollEdgeAppearance = appearance
            standardToolbar.compactScrollEdgeAppearance = appearance
        }
    }
    
    /// Sets toolbar user interface style
    func setToolbarUserInterfaceStyle(_ style: UIUserInterfaceStyle) {
        if let standardToolbar = toolbar as? Toolbar {
            standardToolbar.overrideUserInterfaceStyle = style
        }
        // Custom toolbar doesn't support overrideUserInterfaceStyle
    }

    var toolbarItems: [UIBarButtonItem] {
        get { 
            if let standardToolbar = toolbar as? Toolbar {
                return standardToolbar.items ?? []
            }
            return []
        }
        set { 
            if let standardToolbar = toolbar as? Toolbar {
                standardToolbar.items = newValue
            }
        }
    }

    // MARK: Layout
    
    override init(frame: CGRect) {
        topBarState = UIAccessibility.isVoiceOverRunning ? .alwaysVisible : .hidden

        super.init(frame: frame)

        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverStatusDidChange), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)

        if let standardToolbar = toolbar as? Toolbar {
            standardToolbar.overrideUserInterfaceStyle = Theme.defaultTheme()["mode"] == "light" ? .light : .dark
            
            // Apply initial appearance based on liquid glass setting
            configureToolbarAppearance(standardToolbar)
        }
        
        addSubview(renderView)
        addSubview(topBarContainer)
        addSubview(loadingViewContainer)
        addSubview(toolbar)
        renderView.scrollView.addSubview(refreshControlContainer)

        scrollViewDelegateMux = ScrollViewDelegateMultiplexer(scrollView: renderView.scrollView)
        scrollViewDelegateMux?.addDelegate(self)
    }

    override func layoutSubviews() {
        /*
         See commentary in `PostsPageViewController.viewDidLoad()` about our layout strategy here. tl;dr layout margins are the highest-level approach available on all versions of iOS that Awful supports, so we'll use them exclusively to represent the safe area.
         */

        renderView.frame = bounds
        loadingViewContainer.frame = bounds

        let toolbarHeight = toolbar.sizeThatFits(bounds.size).height
        let toolbarY: CGFloat
        
        if immersionModeEnabled && immersionModeState == .immersed {
            // Position toolbar off-screen when in immersion mode
            toolbarY = bounds.maxY
        } else {
            toolbarY = bounds.maxY - layoutMargins.bottom - toolbarHeight
        }
        
        toolbar.frame = CGRect(
            x: safeAreaInsets.left,
            y: toolbarY,
            width: bounds.width - safeAreaInsets.left - safeAreaInsets.right,
            height: toolbarHeight)

        let scrollView = renderView.scrollView

        let refreshControlHeight = refreshControlContainer.layoutFittingCompressedHeight(targetWidth: bounds.width - safeAreaInsets.left - safeAreaInsets.right)
        refreshControlContainer.frame = CGRect(
            x: safeAreaInsets.left,
            y: max(scrollView.contentSize.height, scrollView.bounds.height - layoutMargins.bottom),
            width: bounds.width - safeAreaInsets.left - safeAreaInsets.right,
            height: refreshControlHeight)

        let topBarHeight = topBarContainer.layoutFittingCompressedHeight(targetWidth: bounds.width - safeAreaInsets.left - safeAreaInsets.right)
        topBarContainer.frame = CGRect(
            x: safeAreaInsets.left,
            y: bounds.minY + layoutMargins.top,
            width: bounds.width - safeAreaInsets.left - safeAreaInsets.right,
            height: topBarHeight)
        updateTopBarContainerFrameAndScrollViewInsets()
    }

    /// Assumes that various views (top bar container, refresh control container, toolbar) have been laid out.
    private func updateScrollViewInsets() {
        let scrollView = renderView.scrollView

        let bottomInset: CGFloat
        if immersionModeEnabled && immersionModeState == .immersed {
            // When in immersion mode, use full screen for content
            bottomInset = layoutMargins.bottom
        } else {
            bottomInset = bounds.maxY - toolbar.frame.minY
        }
        
        var contentInset = UIEdgeInsets(top: topBarContainer.frame.maxY, left: 0, bottom: bottomInset, right: 0)
        if case .refreshing = refreshControlState {
            contentInset.bottom += refreshControlContainer.bounds.height
        }
        scrollView.contentInset = contentInset

        let indicatorBottomInset: CGFloat
        if immersionModeEnabled && immersionModeState == .immersed {
            indicatorBottomInset = layoutMargins.bottom
        } else {
            indicatorBottomInset = bounds.maxY - toolbar.frame.minY
        }
        
        var indicatorInsets = UIEdgeInsets(top: topBarContainer.frame.maxY, left: 0, bottom: indicatorBottomInset, right: 0)
        // I'm not sure if this is a bug or if I'm misunderstanding something, but as of iOS 12 it seems that the indicator insets have already taken the layout margins into consideration? That's my guess based on observing their positioning when the indicator insets are set to zero.
        indicatorInsets.top -= layoutMargins.top
        indicatorInsets.bottom -= layoutMargins.bottom
        scrollView.scrollIndicatorInsets = indicatorInsets
    }

    @objc private func voiceOverStatusDidChange(_ notification: Notification) {
        if UIAccessibility.isVoiceOverRunning {
            topBarState = .alwaysVisible
        } else {
            switch topBarState {
            case .alwaysVisible:
                topBarState = .visible
            case .hidden, .appearing, .disappearing, .visible:
                break
            }
        }
    }

    override func layoutMarginsDidChange() {
        super.layoutMarginsDidChange()
        setNeedsLayout()
    }

    // MARK: Theming

    func themeDidChange(_ theme: Theme) {
        /**
         A theme is being passed in here but this conflicts with the chrome objects when the posts page view theme differs from the main default theme. e.g. if SpankyKong Light is the default theme, the top and bottom buttons were being affected by a forum-specific theme, such as YOSPOS.
         
         Now Theme.defaultTheme() is used in most places to avoid this issue. The scroll thumb and actual posts view stylesheet remains dynamic based on the theme passed in.
         */
        refreshControlContainer.tintColor = theme["postsPullForNextColor"]
        renderView.scrollView.indicatorStyle = theme.scrollIndicatorStyle
        renderView.setThemeStylesheet(theme["postsViewCSS"] ?? "")

        if let standardToolbar = toolbar as? Toolbar {
            standardToolbar.tintColor = Theme.defaultTheme()["toolbarTextColor"]!
            configureToolbarAppearance(standardToolbar)
        }

        topBar.themeDidChange(Theme.defaultTheme())
    }
    
    // MARK: - Toolbar Configuration
    
    private func configureToolbarAppearance(_ toolbar: Toolbar) {
        // Modern iOS 26 appearance: translucent with hidden hairline border
        toolbar.topBorderColor = UIColor.clear
        toolbar.isTranslucent = Theme.defaultTheme()[bool: "tabBarIsTranslucent"] ?? false
    }
    
    // MARK: Immersion mode helpers
    
    /// Force exit immersion mode (useful for scroll-to-top/bottom actions)
    func exitImmersionMode() {
        guard immersionModeEnabled && immersionModeState == .immersed else { return }
        immersionModeState = .normal
    }
    
    private func showBarsAnimated(_ animated: Bool) {
        guard immersionModeEnabled else { return }
        
        logger.debug("showBarsAnimated called - showing navigation, top bar, and toolbar")
        
        // Show top bar
        topBarState = .visible
        
        UIView.animate(withDuration: animated ? 0.25 : 0) {
            // Show toolbar
            self.toolbar.alpha = 1.0
            self.toolbar.transform = .identity
            
            // Update top bar frame and scroll view insets
            self.updateTopBarContainerFrameAndScrollViewInsets()
            
            // Update layout margins to account for visible toolbar
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
        
        // Show navigation bar
        setNavigationBarHidden?(false, animated)
    }
    
    private func hideBarsAnimated(_ animated: Bool) {
        guard immersionModeEnabled else { return }
        
        logger.debug("hideBarsAnimated called - hiding navigation, top bar, and toolbar")
        
        // Hide top bar
        topBarState = .hidden
        
        UIView.animate(withDuration: animated ? 0.25 : 0) {
            // Hide toolbar by moving it down and fading it
            let toolbarHeight = self.toolbar.bounds.height
            self.toolbar.alpha = 0.0
            self.toolbar.transform = CGAffineTransform(translationX: 0, y: toolbarHeight)
            
            // Update top bar frame and scroll view insets
            self.updateTopBarContainerFrameAndScrollViewInsets()
            
            // Update layout margins to account for hidden toolbar
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
        
        // Hide navigation bar
        setNavigationBarHidden?(true, animated)
    }
    
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Immersion Mode

extension PostsPageView {
    enum ImmersionModeState {
        /// Normal state with bars visible
        case normal
        /// Immersed state with bars hidden
        case immersed  
        /// Transitioning between states
        case transitioning
    }
}

// MARK: - Top bar

extension PostsPageView {

    /// Holds the top bar and clips to bounds, so the top bar doesn't sit behind a possibly-translucent navigation bar and obscure the underlying content.
    final class TopBarContainer: UIView {

        fileprivate lazy var topBar: PostsPageTopBar = {
            let topBar = PostsPageTopBar()
            topBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            return topBar
        }()


        override init(frame: CGRect) {
            super.init(frame: frame)

            clipsToBounds = true

            addSubview(topBar, constrainEdges: [.bottom, .left, .right])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    enum TopBarState {

        /// The top bar is not visible, but will appear when the user scrolls up.
        case hidden

        /// The top bar is visible, and may disappear when the user scrolls down.
        case visible

        /// The top bar was hidden but is now "scrolling" into view. `fromContentOffset` is the content offset from when this started, used to calculate its current progress.
        case appearing(fromContentOffset: CGPoint)

        /// The top bar was visible but is now "scrolling" out of view. `fromContentOffset` is the content offset from when this started, used to calculate its current progress.
        case disappearing(fromContentOffset: CGPoint)

        /// The top bar is visible and will not disappear when the user scrolls.
        case alwaysVisible
    }

    /// Assumes the top bar container has already been laid out as if it was fully visible.
    @discardableResult
    private func updateTopBarContainerFrameAndScrollViewInsets() -> TopBarUpdateResult {
        let result: TopBarUpdateResult
        switch topBarState {
        case .hidden:
            topBarContainer.frame.size.height = 0
            result = .init(progress: 1)

        case .appearing(fromContentOffset: let initialContentOffset):
            let distance = initialContentOffset.y - renderView.scrollView.contentOffset.y
            let upperBound = topBar.bounds.height
            let clamped = distance.clamp(0...upperBound)
            topBarContainer.frame.size.height = clamped
            result = .init(progress: clamped / upperBound)

        case .disappearing(fromContentOffset: let initialContentOffset):
            let distance = renderView.scrollView.contentOffset.y - initialContentOffset.y
            let upperBound = topBar.bounds.height
            let clamped = distance.clamp(0...upperBound)
            topBarContainer.frame.size.height = upperBound - clamped
            result = .init(progress: clamped / upperBound)

        case .visible, .alwaysVisible:
            topBarContainer.layoutIfNeeded()
            topBarContainer.frame.size.height = topBarContainer.topBar.bounds.height
            result = .init(progress: 1)
        }

        updateScrollViewInsets()
        return result
    }

    private struct TopBarUpdateResult {
        let progress: CGFloat
    }
}

// MARK: - Refresh control

/// A type that can react to changes in posts page refresh control state.
protocol PostsPageRefreshControlContent: AnyObject {
    var state: PostsPageView.RefreshControlState { get set }
}

extension PostsPageView {

    /// Trivial subclass to identify the view when debugging.
    final class RefreshControlContainer: UIView {}

    enum RefreshControlState: Equatable {

        /// The refresh control is unseen and does nothing.
        case disabled

        /// The refresh control may spring to life if an appropriate drag begins.
        case ready

        /**
         The refresh control is reacting to continued dragging and may end up triggering a refresh.

         `triggeredFraction` is how close the control is to triggering a refresh. It is for the benefit of the content view (e.g. to spin an arrow in time with the scrolling).
         */
        case armed(triggeredFraction: CGFloat)

        /**
         A drag began too far away for the refresh control to spring to life, so we'll wait for dragging to finish before getting ready for the next one.

         This state avoids accidentally triggering a refresh when the user is rapidly (and probably coarsely) scrolling down.
         */
        case awaitingScrollEnd

        /// If the drag stops here, a refresh is triggered.
        case triggered

        /// A refresh has been triggered, the handler has been called, and a refreshing animation should continue until `endRefreshing()` is called.
        case refreshing
        
        /// Helper to check if refresh control is in armed or triggered state
        var isArmedOrTriggered: Bool {
            switch self {
            case .armed, .triggered:
                return true
            case .disabled, .ready, .awaitingScrollEnd, .refreshing:
                return false
            }
        }
    }

    private struct ScrollViewInfo {
        let effectiveContentHeight: CGFloat
        let refreshControlHeight: CGFloat
        let targetScrollViewBoundsMaxY: CGFloat

        init(refreshControlHeight: CGFloat, scrollView: UIScrollView, targetContentOffset: CGPoint? = nil) {
            let contentInsetBottom = scrollView.adjustedContentInset.bottom
            effectiveContentHeight = max(scrollView.contentSize.height + contentInsetBottom, scrollView.bounds.height)
            self.refreshControlHeight = refreshControlHeight
            targetScrollViewBoundsMaxY = (targetContentOffset?.y ?? scrollView.contentOffset.y) + scrollView.bounds.height
        }

        static let closeEnoughToBottom: CGFloat = -10

        var visibleBottom: CGFloat {
            return targetScrollViewBoundsMaxY - effectiveContentHeight
        }

        var triggeredFraction: CGFloat {
            let effectiveControlHeight = refreshControlHeight + 45
            return (visibleBottom / effectiveControlHeight).clamp(0 ... .greatestFiniteMagnitude)
        }
    }

    func endRefreshing() {
        switch refreshControlState {
        case .armed, .awaitingScrollEnd, .triggered, .refreshing:
            refreshControlState = .ready

        case .ready, .disabled:
            break
        }
    }
}

// MARK: - UIScrollViewDelegate and ScrollViewDelegateContentSize

extension PostsPageView: ScrollViewDelegateExtras {
    func scrollViewDidChangeContentSize(_ scrollView: UIScrollView) {
        setNeedsLayout()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        willBeginDraggingContentOffset = scrollView.contentOffset
        
        // disable transparency so that scroll thumbs work in dark mode
        if darkMode, !viewHasBeenScrolledOnce {
            renderView.toggleOpaqueToFixIOS15ScrollThumbColor(setOpaqueTo: true)
            viewHasBeenScrolledOnce = true
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Handle immersion mode transitions
        if immersionModeEnabled && !refreshControlState.isArmedOrTriggered {
            let velocityThreshold: CGFloat = 0.5
            
            if velocity.y > velocityThreshold && immersionModeState == .normal {
                // Scrolling down fast enough to enter immersion mode
                immersionModeState = .immersed
            } else if velocity.y < -velocityThreshold && immersionModeState == .immersed {
                // Scrolling up fast enough to exit immersion mode
                immersionModeState = .normal
            }
        }
        
        switch refreshControlState {
        case .armed, .triggered:
            // Top bar shouldn't fight with refresh control.
            break

        case .ready, .awaitingScrollEnd, .refreshing, .disabled:
            // Only handle regular top bar logic if not in immersion mode
            if !immersionModeEnabled || immersionModeState == .normal {
                switch topBarState {
                case .hidden where velocity.y < 0:
                    topBarState = .appearing(fromContentOffset: scrollView.contentOffset)

                case .visible where velocity.y > 0:
                    topBarState = .disappearing(fromContentOffset: scrollView.contentOffset)

                case .hidden, .visible, .appearing, .disappearing, .alwaysVisible:
                    break
                }
            }
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
        switch refreshControlState {
        case .awaitingScrollEnd where !willDecelerate:
            refreshControlState = .ready

        case .armed where !willDecelerate:
            refreshControlState = .awaitingScrollEnd

        case .triggered:
            refreshControlState = .refreshing

        case .ready, .armed, .awaitingScrollEnd, .refreshing, .disabled:
            break
        }

        if !willDecelerate {
            updateTopBarDidEndDecelerating()
        }

        willBeginDraggingContentOffset = nil
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        switch refreshControlState {
        case .awaitingScrollEnd:
            refreshControlState = .ready

        case .ready, .armed, .triggered, .refreshing, .disabled:
            break
        }

        updateTopBarDidEndDecelerating()
    }

    private func updateTopBarDidEndDecelerating() {
        let result = updateTopBarContainerFrameAndScrollViewInsets()
        switch topBarState {
        case .appearing:
            topBarState = result.progress >= 0.75 ? .visible : .hidden

        case .disappearing:
            topBarState = result.progress >= 0.75 ? .hidden : .visible

        case .hidden, .visible, .alwaysVisible:
            break
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let info = ScrollViewInfo(refreshControlHeight: refreshControlContainer.bounds.height, scrollView: scrollView)

        // Update refreshControlState first, then decide if we care about topBarState.
        switch (refreshControlState, willBeginDraggingContentOffset) {
        case (.ready, let initialContentOffset?)
            where initialContentOffset.y < scrollView.contentOffset.y
                && !scrollView.isDecelerating:

            if info.visibleBottom >= ScrollViewInfo.closeEnoughToBottom - scrollView.contentInset.bottom {
                refreshControlState = .armed(triggeredFraction: info.triggeredFraction)
            } else {
                refreshControlState = .awaitingScrollEnd
            }


        case (.armed(let triggeredFraction), _):
            if info.triggeredFraction >= 1 {
                refreshControlState = .triggered
            } else if info.triggeredFraction != triggeredFraction {
                refreshControlState = .armed(triggeredFraction: info.triggeredFraction)
            }

        case (.triggered, _):
            if info.triggeredFraction < 1 {
                refreshControlState = .armed(triggeredFraction: info.triggeredFraction)
            }

        case (.disabled, _), (.ready, _), (.awaitingScrollEnd, _), (.refreshing, _):
            break
        }

        switch topBarState {
        case .appearing, .disappearing:
            updateTopBarContainerFrameAndScrollViewInsets()

        case .hidden, .visible, .alwaysVisible:
            break
        }

        switch refreshControlState {
        case .armed, .triggered:
            // Top bar shouldn't fight with refresh control.
            break

        case .disabled, .ready, .awaitingScrollEnd, .refreshing:
            // Only handle regular top bar logic if not in immersion mode
            if !immersionModeEnabled || immersionModeState == .normal {
                switch (topBarState, willBeginDraggingContentOffset)  {
                case (.hidden, let willBeginDraggingContentOffset?):
                    topBarState = .appearing(fromContentOffset: willBeginDraggingContentOffset)

                case (.visible, let willBeginDraggingContentOffset?):
                    // Without this check, when the refresh control is disabled, it's impossible to scroll content up when at the bottom of the page and the top bar is visible (i.e. after tapping "Scroll to Bottom"). There's surely a better approach, but this gets us working again.
                    let contentOffsetYAtBottom = max(scrollView.contentSize.height + scrollView.contentInset.bottom, scrollView.bounds.height) - scrollView.bounds.height
                    let isVeryCloseToBottom = abs(willBeginDraggingContentOffset.y - contentOffsetYAtBottom) < 5
                    if !isVeryCloseToBottom {
                        topBarState = .disappearing(fromContentOffset: willBeginDraggingContentOffset)
                    }

                case (.hidden, _), (.visible, _), (.appearing, _), (.disappearing, _), (.alwaysVisible, _):
                    break
                }
            }
        }

        // If immersed, automatically reveal bars when reaching very top or bottom of content
        if immersionModeEnabled && immersionModeState == .immersed {
            let threshold: CGFloat = 20
            // Near top: contentOffset.y approaches -contentInset.top
            let isNearTop = scrollView.contentOffset.y <= -scrollView.contentInset.top + threshold
            // Near bottom: contentOffset.y approaches the maximum offset considering insets
            let maxOffsetY = max(scrollView.contentSize.height + scrollView.contentInset.bottom, scrollView.bounds.height) - scrollView.bounds.height
            let isNearBottom = scrollView.contentOffset.y >= maxOffsetY - threshold

            if isNearTop || isNearBottom {
                exitImmersionMode()
            }
        }
    }
}

// (progressive immersive reveal helpers removed)
