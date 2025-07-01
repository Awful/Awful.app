//  PostsPageView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import os
import ScrollViewDelegateMultiplexer
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PostsPageView")

private let TopBarAppearanceAnimationDuration: TimeInterval = 0.2

/**
 Manages a posts page's render view, top bar, refresh control, and toolbar.

 Since both the top bar and refresh control depend on scroll view shenanigans, it makes sense to manage them in the same place (mostly so we can mediate any conflict between them). And since our supported iOS versions include several different approaches to safe areas, top/bottom anchors, and layout margins, we can deal with some of that here too. For more about the layout margins, see commentary in `PostsPageViewController.viewDidLoad()`.
 */
final class PostsPageView: UIView {

    @FoilDefaultStorage(Settings.darkMode) private var darkMode
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    var viewHasBeenScrolledOnce: Bool = false
    
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
    var didScroll: ((UIScrollView) -> Void)?

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
            
            case (.awaitingScrollEnd, .armed):
                break
            
            case (.awaitingScrollEnd, .awaitingScrollEnd):
                break
            
            case (.awaitingScrollEnd, .triggered):
                break

            case (.triggered, .armed),
                 (.triggered, .awaitingScrollEnd),
                 (.triggered, .refreshing):
                break

            case (.refreshing, .ready):
                break
            
            case (.refreshing, .refreshing):
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
        return _topBarContainer.topBar
    }
    
    var topBarContainer: TopBarContainer {
        return _topBarContainer
    }

    private let _topBarContainer = TopBarContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 44) /* somewhat arbitrary size to avoid unhelpful unsatisfiable constraints console messages */)

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

            case (.hidden, .hidden),
                 (.visible, .visible),
                 (.alwaysVisible, .alwaysVisible):
                break
            default:
                break
            }
        }
    }

    private var topBarIsAnimatingAppearance: Bool {
        return _topBarContainer.layer.presentation()?.opacity ?? 0 > 0.001
            && _topBarContainer.layer.presentation()?.opacity ?? 0 < 0.999
    }

    // MARK: Remaining subviews

    private var willBeginDraggingContentOffset: CGPoint?

    private(set) lazy var renderView = RenderView()

    private var scrollViewDelegateMux: ScrollViewDelegateMultiplexer?

    // MARK: Layout
    
    override init(frame: CGRect) {
        topBarState = UIAccessibility.isVoiceOverRunning ? .alwaysVisible : .hidden

        super.init(frame: frame)

        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverStatusDidChange), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)

        addSubview(renderView)
        addSubview(_topBarContainer)
        addSubview(loadingViewContainer)
        renderView.scrollView.addSubview(refreshControlContainer)

        scrollViewDelegateMux = ScrollViewDelegateMultiplexer(scrollView: renderView.scrollView)
        scrollViewDelegateMux?.addDelegate(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        renderView.frame = bounds
        loadingViewContainer.frame = bounds
        
        updateTopBarContainerFrameAndScrollViewInsets()
        
        let targetSize = CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height)
        refreshControlContainer.frame.size = refreshControlContainer.systemLayoutSizeFitting(targetSize)
        refreshControlContainer.frame.origin.y = -refreshControlContainer.frame.height

        // On older iOS, the scroll view's contentInset seems to get reset to zero after a rotation. This seems to be the earliest opportunity to fix it.
        updateScrollViewInsets()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Hides the toolbar (called from SwiftUI integration)
    func hideToolbar() {
        // The toolbar is managed by the view controller, so this is a no-op for now
        // In the future, this could be used to hide any internal toolbar elements
    }

    private func updateTopBarContainerFrameAndScrollViewInsets() {
        // We're doing all this instead of using Auto Layout because we're going to be calling this from `layoutSubviews()`, and we can't be adding constraints from there.
        // See commentary in `PostsPageViewController.viewDidLoad()` about our layout strategy here. tl;dr layout margins are the highest-level approach available on all versions of iOS that Awful supports, so we'll use them exclusively to determine where things should go.
        
        var topBarFrame = CGRect.zero
        switch topBarState {
        case .hidden:
            topBarFrame.origin.y = -_topBarContainer.bounds.height
            
        case .appearing:
            let presentation = _topBarContainer.layer.presentation()
            if let presentation = presentation, topBarIsAnimatingAppearance {
                topBarFrame = presentation.frame
            } else {
                topBarFrame = _topBarContainer.frame
                topBarFrame.origin.y = -topBarFrame.height
            }
            
        case .disappearing:
            let presentation = _topBarContainer.layer.presentation()
            if let presentation = presentation, topBarIsAnimatingAppearance {
                topBarFrame = presentation.frame
            } else {
                topBarFrame = _topBarContainer.frame
            }
            
        case .visible, .alwaysVisible:
            topBarFrame.origin.y = 0
        }
        topBarFrame.size.width = bounds.width
        _topBarContainer.frame = topBarFrame
        
        updateScrollViewInsets()
    }

    private func updateScrollViewInsets() {
        var insets = UIEdgeInsets.zero
        insets.bottom = safeAreaInsets.bottom
        if topBarState == .visible || topBarState == .alwaysVisible {
            insets.top = _topBarContainer.frame.height
        }
        renderView.scrollView.contentInset = insets
        renderView.scrollView.scrollIndicatorInsets = insets
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
        renderView.setThemeStylesheet(theme[string: "postsViewCSS"] ?? "")

        topBar.themeDidChange(Theme.defaultTheme())
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

        fileprivate lazy var topBar: PostsPageTopBar = {
            let topBar = PostsPageTopBar()
            return topBar
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(topBar)
            
            topBar.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                topBar.leadingAnchor.constraint(equalTo: leadingAnchor),
                topBar.trailingAnchor.constraint(equalTo: trailingAnchor),
                topBar.topAnchor.constraint(equalTo: topAnchor),
                topBar.bottomAnchor.constraint(equalTo: bottomAnchor),
                topBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    enum TopBarState: Equatable {

        /// The top bar is not visible, but will appear when the user scrolls up.
        case hidden

        /// The top bar is visible, and may disappear when the user scrolls down.
        case visible

        /// The top bar was hidden but is now "scrolling" into view. `fromContentOffset` is the content offset from when this started, used to calculate its current progress.
        case appearing(since: Date)

        /// The top bar was visible but is now "scrolling" out of view. `fromContentOffset` is the content offset from when this started, used to calculate its current progress.
        case disappearing(since: Date)

        /// The top bar is visible and will not disappear when the user scrolls.
        case alwaysVisible
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
        switch refreshControlState {
        case .armed, .triggered:
            // Top bar shouldn't fight with refresh control.
            break

        case .ready, .awaitingScrollEnd, .refreshing, .disabled:
            switch topBarState {
            case .hidden where velocity.y < 0:
                topBarState = .appearing(since: Date())

            case .visible where velocity.y > 0:
                topBarState = .disappearing(since: Date())

            case .hidden, .visible, .appearing, .disappearing, .alwaysVisible:
                break
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
        switch topBarState {
        case .appearing:
            topBarState = .visible

        case .disappearing:
            topBarState = .hidden

        case .hidden, .visible, .alwaysVisible:
            break
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let info = ScrollViewInfo(refreshControlHeight: refreshControlContainer.bounds.height, scrollView: scrollView)
        
        // Notify delegate of scroll events
        didScroll?(scrollView)

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
            switch (topBarState, willBeginDraggingContentOffset)  {
            case (.hidden, let willBeginDraggingContentOffset?):
                if scrollView.contentOffset.y < willBeginDraggingContentOffset.y {
                    topBarState = .appearing(since: Date())
                }

            case (.visible, let willBeginDraggingContentOffset?):
                // Without this check, when the refresh control is disabled, it's impossible to scroll content up when at the bottom of the page and the top bar is visible (i.e. after tapping "Scroll to Bottom"). There's surely a better approach, but this gets us working again.
                let contentOffsetYAtBottom = max(scrollView.contentSize.height + scrollView.contentInset.bottom, scrollView.bounds.height) - scrollView.bounds.height
                let isVeryCloseToBottom = abs(willBeginDraggingContentOffset.y - contentOffsetYAtBottom) < 5
                if !isVeryCloseToBottom {
                    if scrollView.contentOffset.y > willBeginDraggingContentOffset.y {
                        topBarState = .disappearing(since: Date())
                    }
                }

            case (.hidden, _), (.visible, _), (.appearing, _), (.disappearing, _), (.alwaysVisible, _):
                break
            }
        }
    }
}

private struct ScrollViewInfo {
    let contentHeight: CGFloat
    let contentInset: UIEdgeInsets
    let contentOffsetY: CGFloat
    let refreshControlHeight: CGFloat
    let scrollViewHeight: CGFloat
    
    init(refreshControlHeight: CGFloat, scrollView: UIScrollView) {
        self.contentHeight = scrollView.contentSize.height
        self.contentInset = scrollView.contentInset
        self.contentOffsetY = scrollView.contentOffset.y
        self.refreshControlHeight = refreshControlHeight
        self.scrollViewHeight = scrollView.bounds.height
    }
    
    /// How far "into" the refresh control the scroll view has been pulled.
    /// - 0 means the refresh control isn't visible at all.
    /// - 1 means the refresh control is fully visible and the "trigger" point has been reached.
    /// - 2 means the user has pulled twice as far as necessary to trigger.
    /// - etc.
    var triggeredFraction: CGFloat {
        guard contentHeight > 0 else { return 0 }
        
        let visibleBottom = contentOffsetY + scrollViewHeight
        let unimportantHeight = scrollViewHeight - contentInset.bottom - contentHeight
        let distance = visibleBottom - unimportantHeight - contentHeight
        
        guard distance > 0 else { return 0 }
        
        return distance / refreshControlHeight
    }
    
    static let closeEnoughToBottom: CGFloat = 5
    
    var visibleBottom: CGFloat {
        return contentOffsetY + scrollViewHeight
    }
}
