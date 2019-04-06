//  PostsPageView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

private let Log = Logger.get()

/**
 Manages a posts page's render view, top bar, refresh control, and toolbar.

 Since both the top bar and refresh control depend on scroll view shenanigans, it makes sense to manage them in the same place (mostly so we can mediate any conflict between them). And since our supported iOS versions include several different approaches to safe areas, top/bottom anchors, and layout margins, we can deal with some of that here too. For more about the layout margins, see commentary in `PostsPageViewController.viewDidLoad()`.
 */
final class PostsPageView: UIView {

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
                refreshControl.translatesAutoresizingMaskIntoConstraints = false
                refreshControlContainer.addSubview(refreshControl)
                let containerMargins = refreshControlContainer.layoutMarginsGuide
                NSLayoutConstraint.activate([
                    refreshControl.leftAnchor.constraint(equalTo: containerMargins.leftAnchor),
                    containerMargins.rightAnchor.constraint(equalTo: refreshControl.rightAnchor),
                    refreshControl.topAnchor.constraint(equalTo: containerMargins.topAnchor),
                    containerMargins.bottomAnchor.constraint(equalTo: refreshControl.bottomAnchor)])

                refreshControl.state = refreshControlState
            }
        }
    }

    private let refreshControlContainer: RefreshControlContainer = {
        let refreshControlContainer = RefreshControlContainer()
        if #available(iOS 11.0, *) {
            refreshControlContainer.insetsLayoutMarginsFromSafeArea = false
        }
        refreshControlContainer.layoutMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        return refreshControlContainer
    }()

    private var refreshControlContainerTopConstraint: NSLayoutConstraint?

    private var refreshControlState: RefreshControlState = .ready {
        willSet {
            switch (refreshControlState, newValue) {
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

            case (.ready, _),
                 (.armed, _),
                 (.awaitingScrollEnd, _),
                 (.triggered, _),
                 (.refreshing, _):
                assertionFailure("attempted invalid state transition from \(refreshControlState) to \(newValue)")
            }
        }
        didSet {
            Log.d("transitioned from \(oldValue) to \(refreshControlState)")

            refreshControl?.state = refreshControlState

            switch refreshControlState {
            case .ready, .awaitingScrollEnd:
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
                        + refreshControlContainer.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
                    scrollView.setContentOffset(contentOffset, animated: true)
                }

            case .armed, .triggered:
                break
            }
        }
    }

    // MARK: Remaining subviews

    private(set) lazy var renderView: RenderView = {
        let renderView = RenderView()
        renderView.scrollView.delegate = self
        return renderView
    }()

    private let toolbar = Toolbar()

    var toolbarItems: [UIBarButtonItem] {
        get { return toolbar.items ?? [] }
        set { toolbar.items = newValue }
    }

    var topBar: PostsPageTopBar {
        return topBarContainer.topBar
    }

    private let topBarContainer = TopBarContainer()

    // MARK: Layout
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(renderView, constrainEdges: .all)
        addSubview(topBarContainer, constrainEdges: [.left, .right])
        addSubview(loadingViewContainer, constrainEdges: .all)
        addSubview(toolbar, constrainEdges: [.left, .right])

        // See commentary in `PostsPageViewController.viewDidLoad()` about our layout strategy here. tl;dr layout margins are the highest-level approach available on all versions of iOS that Awful supports, so we'll use them exclusively to represent the safe area.
        NSLayoutConstraint.activate([
            topBarContainer.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            layoutMarginsGuide.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor)])

        refreshControlContainer.translatesAutoresizingMaskIntoConstraints = false
        renderView.scrollView.addSubview(refreshControlContainer)
        refreshControlContainerTopConstraint = refreshControlContainer.topAnchor.constraint(equalTo: renderView.scrollView.topAnchor)
        NSLayoutConstraint.activate([
            refreshControlContainerTopConstraint!,
            leftAnchor.constraint(equalTo: refreshControlContainer.leftAnchor),
            refreshControlContainer.rightAnchor.constraint(equalTo: rightAnchor)])
    }

    override func layoutSubviews() {

        // Let Auto Layout do its thing first, so we can use bar frames to figure out content insets.
        super.layoutSubviews()

        let scrollView = renderView.scrollView

        refreshControlContainerTopConstraint?.constant = max(scrollView.contentSize.height, scrollView.bounds.height)

        /*
         I'm assuming `layoutSubviews()` will get called (among other times) whenever `layoutMarginsDidChange()` gets called, so there's no point overriding `layoutMarginsDidChange()` to do the same work we're doing here. But I haven't yet convinced myself that this is how things work.

         See commentary in `PostsPageViewController.viewDidLoad()` about our layout strategy here. tl;dr layout margins are the highest-level approach available on all versions of iOS that Awful supports, so we'll use them exclusively to represent the safe area.
         */

        var contentInset = UIEdgeInsets(top: topBarContainer.frame.maxY, left: 0, bottom: bounds.maxY - toolbar.frame.minY, right: 0)
        if case .refreshing = refreshControlState {
            contentInset.bottom += refreshControlContainer.bounds.height
        }
        scrollView.contentInset = contentInset

        var indicatorInsets = UIEdgeInsets(top: topBarContainer.frame.maxY, left: 0, bottom: bounds.maxY - toolbar.frame.minY, right: 0)
        if #available(iOS 12.0, *) {
            // I'm not sure if this is a bug or if I'm misunderstanding something, but on iOS 12 it seems that the indicator insets have already taken the layout margins into consideration? That's my guess based on observing their positioning when the indicator insets are set to zero.
            indicatorInsets.top -= layoutMargins.top
            indicatorInsets.bottom -= layoutMargins.bottom
        }
        scrollView.scrollIndicatorInsets = indicatorInsets
    }

    // MARK: Theming

    func themeDidChange(_ theme: Theme) {
        refreshControlContainer.tintColor = theme["postsPullForNextColor"]

        renderView.scrollView.indicatorStyle = theme.scrollIndicatorStyle
        renderView.setThemeStylesheet(theme["postsViewCSS"] ?? "")

        toolbar.barTintColor = theme["toolbarTintColor"]
        toolbar.tintColor = theme["toolbarTextColor"]
        toolbar.topBorderColor = theme["bottomBarTopBorderColor"]
        toolbar.isTranslucent = theme[bool: "tabBarIsTranslucent"] ?? true

        topBar.themeDidChange(theme)
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
            topBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            return topBar
        }()


        override init(frame: CGRect) {
            super.init(frame: frame)

            clipsToBounds = true

            addSubview(topBar, constrainEdges: [.bottom, .left, .right])

            // When we want to hide the bar, the posts page view will add a higher-priority constraint to do so.
            let showBarByDefault = topBar.topAnchor.constraint(equalTo: topAnchor)
            showBarByDefault.priority = 500
            NSLayoutConstraint.activate([
                topBar.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
                showBarByDefault])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

// MARK: - Refresh control

/// A type that can react to changes in posts page refresh control state.
protocol PostsPageRefreshControlContent: class {
    var state: PostsPageView.RefreshControlState { get set }
}

extension PostsPageView {

    /// Trivial subclass to identify the view when debugging.
    final class RefreshControlContainer: UIView {}

    enum RefreshControlState: Equatable {

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

    private struct ScrollViewInfo {
        let effectiveContentHeight: CGFloat
        let refreshControlHeight: CGFloat
        let targetScrollViewBoundsMaxY: CGFloat

        init(refreshControlHeight: CGFloat, scrollView: UIScrollView, targetContentOffset: CGPoint? = nil) {
            var contentInsetBottom: CGFloat {
                if #available(iOS 11.0, *) {
                    return scrollView.adjustedContentInset.bottom
                } else {
                    return scrollView.contentInset.bottom
                }
            }

            effectiveContentHeight = max(scrollView.contentSize.height + contentInsetBottom, scrollView.bounds.height)
            self.refreshControlHeight = refreshControlHeight
            targetScrollViewBoundsMaxY = (targetContentOffset?.y ?? scrollView.contentOffset.y) + scrollView.bounds.height
        }

        static let closeEnoughToBottom: CGFloat = -50

        var visibleBottom: CGFloat {
            return targetScrollViewBoundsMaxY - effectiveContentHeight
        }

        var triggeredFraction: CGFloat {
            let effectiveControlHeight = refreshControlHeight + Tweaks.assign(Tweaks.posts.pullForNextExtraDistance)
            return (visibleBottom / effectiveControlHeight).clamp(0 ... .greatestFiniteMagnitude)
        }
    }

    func endRefreshing() {
        switch refreshControlState {
        case .armed, .awaitingScrollEnd, .triggered, .refreshing:
            refreshControlState = .ready

        case .ready:
            break
        }
    }
}

// MARK: - UIScrollViewDelegate and ScrollViewDelegateContentSize

extension PostsPageView: ScrollViewDelegateContentSize {
    func scrollViewDidChangeContentSize(_ scrollView: UIScrollView) {
        setNeedsLayout()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        let info = ScrollViewInfo(refreshControlHeight: refreshControlContainer.bounds.height, scrollView: scrollView)

        switch refreshControlState {
        case .ready:
            // Don't want to trigger if the user is doing mad successive drags to get quickly to the bottom.
            guard !scrollView.isDecelerating else { break }

            var adjustedBottomInset: CGFloat {
                if #available(iOS 11.0, *) {
                    return scrollView.adjustedContentInset.bottom
                } else {
                    return scrollView.contentInset.bottom
                }
            }

            if info.visibleBottom >= ScrollViewInfo.closeEnoughToBottom - adjustedBottomInset {
                refreshControlState = .armed(triggeredFraction: info.triggeredFraction)
            } else {
                refreshControlState = .awaitingScrollEnd
            }

        case .armed:
            if info.triggeredFraction >= 1 {
                refreshControlState = .triggered
            } else {
                refreshControlState = .armed(triggeredFraction: info.triggeredFraction)
            }

        case .awaitingScrollEnd, .triggered, .refreshing:
            break
        }

        // TODO: decide if it's ok to hide the top bar if we drag in the right direction?
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // based on direction, figure out whether top bar or refresh control need fiddling.
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
        switch refreshControlState {
        case .awaitingScrollEnd where !willDecelerate:
            refreshControlState = .ready

        case .armed where !willDecelerate:
            refreshControlState = .awaitingScrollEnd

        case .triggered:
            refreshControlState = .refreshing

        case .ready, .armed, .awaitingScrollEnd, .refreshing:
            break
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        switch refreshControlState {
        case .awaitingScrollEnd:
            refreshControlState = .ready

        case .ready, .armed, .triggered, .refreshing:
            break
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let info = ScrollViewInfo(refreshControlHeight: refreshControlContainer.bounds.height, scrollView: scrollView)

        switch refreshControlState {
        case .armed(let triggeredFraction):
            if info.triggeredFraction >= 1 {
                refreshControlState = .triggered
            } else if info.triggeredFraction != triggeredFraction {
                refreshControlState = .armed(triggeredFraction: info.triggeredFraction)
            }

        case .triggered:
            if info.triggeredFraction < 1 {
                refreshControlState = .armed(triggeredFraction: info.triggeredFraction)
            }

        case .ready, .awaitingScrollEnd, .refreshing:
            break
        }

        // TODO: fiddle with top bar if warranted
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        // note that we're jumping to the top; turn off refresh control and don't change the top bar state
        return true
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        // unfreeze the top bar if it was frozen in shouldScrollToTop
        // reenable the refresh control
    }
}
