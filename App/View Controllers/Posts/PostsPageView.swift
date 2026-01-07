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
    var viewHasBeenScrolledOnce: Bool = false

    let immersiveModeManager = ImmersiveModeManager()

    /// Weak reference to the posts page view controller to avoid responder chain traversal
    weak var postsPageViewController: PostsPageViewController?
    
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
                    if refreshControl is PostsPageRefreshArrowView {
                        NSLayoutConstraint.activate([
                            refreshControl.leftAnchor.constraint(equalTo: containerMargins.leftAnchor),
                            refreshControl.topAnchor.constraint(equalTo: containerMargins.topAnchor),
                            containerMargins.rightAnchor.constraint(equalTo: refreshControl.rightAnchor),
                            containerMargins.bottomAnchor.constraint(equalTo: refreshControl.bottomAnchor)
                        ])
                    }
                    if refreshControl is GetOutFrogRefreshSpinnerView {
                        NSLayoutConstraint.activate([
                            refreshControl.leftAnchor.constraint(equalTo: containerMargins.leftAnchor),
                            containerMargins.rightAnchor.constraint(equalTo: refreshControl.rightAnchor),
                            containerMargins.bottomAnchor.constraint(equalTo: refreshControl.bottomAnchor),
                            // controls frog lottie position between last post and bottom toolbar
                            refreshControl.heightAnchor.constraint(equalToConstant: 90)
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

    var topBar: PostsPageTopBarProtocol {
        return topBarContainer.topBar as! PostsPageTopBarProtocol
    }

    let topBarContainer = TopBarContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 44) /* somewhat arbitrary size to avoid unhelpful unsatisfiable constraints console messages */)

    func setGoToParentForum(_ callback: (() -> Void)?) {
        if let topBar = topBarContainer.postsTopBar {
            topBar.goToParentForum = callback
        }
    }
    
    func setShowPreviousPosts(_ callback: (() -> Void)?) {
        if let topBar = topBarContainer.postsTopBar {
            topBar.showPreviousPosts = callback
        }
    }
    
    func setScrollToEnd(_ callback: (() -> Void)?) {
        if let topBar = topBarContainer.postsTopBar {
            topBar.scrollToEnd = callback
        }
    }

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

    let toolbar = Toolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44) /* somewhat arbitrary size to avoid unhelpful unsatisfiable constraints console messages */)

    private var safeAreaGradientView: GradientView {
        return immersiveModeManager.safeAreaGradientView
    }

    private lazy var fallbackSafeAreaGradientView: GradientView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        if #available(iOS 26.0, *) {
            view.alpha = 1.0
            view.isHidden = false
        } else {
            view.alpha = 0.0
            view.isHidden = true
        }
        return view
    }()

    var toolbarItems: [UIBarButtonItem] {
        get { return toolbar.items ?? [] }
        set { toolbar.items = newValue }
    }

    // MARK: Layout
    
    override init(frame: CGRect) {
        topBarState = UIAccessibility.isVoiceOverRunning ? .alwaysVisible : .hidden

        super.init(frame: frame)

        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverStatusDidChange), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)

        toolbar.overrideUserInterfaceStyle = Theme.defaultTheme()["mode"] == "light" ? .light : .dark

        addSubview(renderView)
        if #available(iOS 26.0, *) {
            addSubview(immersiveModeManager.safeAreaGradientView)
        } else {
            addSubview(fallbackSafeAreaGradientView)
        }
        addSubview(topBarContainer)
        addSubview(loadingViewContainer)
        addSubview(toolbar)
        renderView.scrollView.addSubview(refreshControlContainer)

        immersiveModeManager.configure(
            postsView: self,
            navigationController: nil, // Will be set from PostsPageViewController
            renderView: renderView,
            toolbar: toolbar,
            topBarContainer: topBarContainer
        )

        scrollViewDelegateMux = ScrollViewDelegateMultiplexer(scrollView: renderView.scrollView)
        scrollViewDelegateMux?.addDelegate(self)
    }

    override func layoutSubviews() {
        /*
         See commentary in `PostsPageViewController.viewDidLoad()` about our layout strategy here. tl;dr layout margins are the highest-level approach available on all versions of iOS that Awful supports, so we'll use them exclusively to represent the safe area.
         */

        renderView.frame = bounds
        loadingViewContainer.frame = bounds

        if #available(iOS 26.0, *) {
            immersiveModeManager.updateGradientLayout(in: self)
        }

        if toolbar.transform == .identity {
            let toolbarHeight = toolbar.sizeThatFits(bounds.size).height
            toolbar.frame = CGRect(
                x: bounds.minX,
                y: bounds.maxY - layoutMargins.bottom - toolbarHeight,
                width: bounds.width,
                height: toolbarHeight)
        }

        let scrollView = renderView.scrollView

        let refreshControlHeight = refreshControlContainer.layoutFittingCompressedHeight(targetWidth: bounds.width)
        refreshControlContainer.frame = CGRect(
            x: bounds.minX,
            y: max(scrollView.contentSize.height, scrollView.bounds.height - layoutMargins.bottom),
            width: bounds.width,
            height: refreshControlHeight)

        let topBarHeight = topBarContainer.layoutFittingCompressedHeight(targetWidth: bounds.width)

        let normalY = bounds.minY + layoutMargins.top
        let topBarY = immersiveModeManager.shouldPositionTopBarForImmersive()
            ? immersiveModeManager.calculateTopBarY(normalY: normalY)
            : normalY

        topBarContainer.frame = CGRect(
            x: bounds.minX,
            y: topBarY,
            width: bounds.width,
            height: topBarHeight)
        updateTopBarContainerFrameAndScrollViewInsets()

        immersiveModeManager.reapplyTransformsAfterLayout()
    }

    /// Assumes that various views (top bar container, refresh control container, toolbar) have been laid out.
    func updateScrollViewInsets() {
        let scrollView = renderView.scrollView
        let bottomInset = calculateBottomInset()

        var contentInset = UIEdgeInsets(top: topBarContainer.frame.maxY, left: 0, bottom: bottomInset, right: 0)
        if case .refreshing = refreshControlState {
            contentInset.bottom += refreshControlContainer.bounds.height
        }
        scrollView.contentInset = contentInset

        let indicatorBottomInset = calculateBottomInset()

        var indicatorInsets = UIEdgeInsets(top: topBarContainer.frame.maxY, left: 0, bottom: indicatorBottomInset, right: 0)
        // I'm not sure if this is a bug or if I'm misunderstanding something, but as of iOS 12 it seems that the indicator insets have already taken the layout margins into consideration? That's my guess based on observing their positioning when the indicator insets are set to zero.
        indicatorInsets.top -= layoutMargins.top
        indicatorInsets.bottom -= layoutMargins.bottom
        scrollView.scrollIndicatorInsets = indicatorInsets
    }

    private func calculateBottomInset() -> CGFloat {
        let normalInset = bounds.maxY - toolbar.frame.minY

        if immersiveModeManager.shouldAdjustScrollInsets() {
            return immersiveModeManager.calculateBottomInset(normalBottomInset: normalInset)
        } else {
            return normalInset
        }
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

        if #available(iOS 26.0, *) {
            toolbar.isTranslucent = Theme.defaultTheme()[bool: "tabBarIsTranslucent"] ?? false
        } else {
            toolbar.tintColor = Theme.defaultTheme()["toolbarTextColor"]!
            toolbar.topBorderColor = Theme.defaultTheme()["bottomBarTopBorderColor"]
            toolbar.isTranslucent = Theme.defaultTheme()[bool: "tabBarIsTranslucent"] ?? false
        }

        topBar.themeDidChange(Theme.defaultTheme())

        if #available(iOS 26.0, *) {
            safeAreaGradientView.themeDidChange()
        }
    }

    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Top bar

extension PostsPageView {

    /// Holds the top bar and clips to bounds, so the top bar doesn't sit behind a possibly-translucent navigation bar and obscure the underlying content.
    final class TopBarContainer: UIView {

        private var topBarHeightConstraint: NSLayoutConstraint?
        private var isTopBarRemoved = false
        
        fileprivate lazy var topBar: UIView = {
                let topBar: UIView & PostsPageTopBarProtocol
                if #available(iOS 26.0, *) {
                    topBar = PostsPageTopBarLiquidGlass()
                } else {
                    topBar = PostsPageTopBar()
                }
                topBarHeightConstraint = topBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
                topBarHeightConstraint?.isActive = true
                return topBar
        }()
        
        var postsTopBar: PostsPageTopBarProtocol? {
            return topBar as? PostsPageTopBarProtocol
        }


        override init(frame: CGRect) {
            super.init(frame: frame)

            clipsToBounds = true

            if #available(iOS 26.0, *) {
                backgroundColor = .clear
            }

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

        /// Helper to check if the refresh control is in an active state
        var isArmedOrTriggered: Bool {
            switch self {
            case .armed, .triggered:
                return true
            default:
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

        immersiveModeManager.handleScrollViewDidChangeContentSize(scrollView)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        willBeginDraggingContentOffset = scrollView.contentOffset

        if darkMode, !viewHasBeenScrolledOnce {
            renderView.toggleOpaqueToFixIOS15ScrollThumbColor(setOpaqueTo: true)
            viewHasBeenScrolledOnce = true
        }

        immersiveModeManager.handleScrollViewWillBeginDragging(scrollView)
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {

        immersiveModeManager.handleScrollViewWillEndDragging(
            scrollView,
            withVelocity: velocity,
            targetContentOffset: targetContentOffset,
            isRefreshControlArmedOrTriggered: refreshControlState.isArmedOrTriggered
        )

        switch refreshControlState {
        case .armed, .triggered:
            // Top bar shouldn't fight with refresh control.
            break

        case .ready, .awaitingScrollEnd, .refreshing, .disabled:
            // Only handle top bar if immersive mode is disabled
            if !immersiveModeManager.shouldPositionTopBarForImmersive() {
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

            immersiveModeManager.handleScrollViewDidEndDragging(
                scrollView,
                willDecelerate: willDecelerate,
                isRefreshControlArmedOrTriggered: refreshControlState.isArmedOrTriggered
            )
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

        immersiveModeManager.handleScrollViewDidEndDecelerating(
            scrollView,
            isRefreshControlArmedOrTriggered: refreshControlState.isArmedOrTriggered
        )
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
        // WKWebView may trigger scroll events on background threads during content loading.
        // Dispatch to main thread to ensure safe access to UI state and prevent data races.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.scrollViewDidScroll(scrollView)
            }
            return
        }

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

        immersiveModeManager.handleScrollViewDidScroll(
            scrollView,
            isDragging: scrollView.isDragging,
            isDecelerating: scrollView.isDecelerating,
            isRefreshControlArmedOrTriggered: refreshControlState.isArmedOrTriggered
        )

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

        if #available(iOS 26.0, *) {
            updateNavigationBarForScrollProgress(scrollView)
        }
    }

    @available(iOS 26.0, *)
    private func updateNavigationBarForScrollProgress(_ scrollView: UIScrollView) {
        let topInset = scrollView.adjustedContentInset.top
        let currentOffset = scrollView.contentOffset.y
        let topPosition = -topInset

        let transitionDistance: CGFloat = 30.0

        let progress: CGFloat
        if currentOffset <= topPosition {
            progress = 0.0
        } else if currentOffset >= topPosition + transitionDistance {
            progress = 1.0
        } else {
            let distanceFromTop = currentOffset - topPosition
            progress = distanceFromTop / transitionDistance
        }

        guard let viewController = postsPageViewController,
              let navController = viewController.navigationController as? NavigationController else {
            return
        }

        navController.updateNavigationBarTintForScrollProgress(NSNumber(value: Float(progress)))
        viewController.updateTitleViewTextColorForScrollProgress(progress)
    }
}
