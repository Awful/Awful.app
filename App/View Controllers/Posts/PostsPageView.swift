//  PostsPageView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import ScrollViewDelegateMultiplexer
import UIKit

/**
 Manages a posts page's render view, top bar, refresh control, and toolbar.

 Since both the top bar and refresh control depend on scroll view shenanigans, it makes sense to manage them in the same place (mostly so we can mediate any conflict between them). And since our supported iOS versions include several different approaches to safe areas, top/bottom anchors, and layout margins, we can deal with some of that here too. For more about the layout margins, see commentary in `PostsPageViewController.viewDidLoad()`.
 */
final class PostsPageView: UIView {

    @FoilDefaultStorage(Settings.darkMode) private var darkMode
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    @FoilDefaultStorage(Settings.immersionModeEnabled) private var immersionModeEnabled {
        didSet {
            // When immersion mode is disabled, reset all transforms
            if !immersionModeEnabled && oldValue {
                immersionProgress = 0.0
                // Reset all transforms immediately
                if let navBar = findNavigationBar() {
                    navBar.transform = .identity
                }
                toolbar.transform = .identity
                safeAreaGradientView.alpha = 0.0
                // Update layout to restore normal state
                setNeedsLayout()
            }
        }
    }
    var viewHasBeenScrolledOnce: Bool = false
    
    // MARK: Immersion mode
    
    /// Callback to hide/show the navigation bar (set by PostsPageViewController)
    var setNavigationBarHidden: ((Bool, Bool) -> Void)?
    
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
    
    /// Actual distance bars travel when hiding (calculated dynamically based on bar heights)
    private var totalBarTravelDistance: CGFloat {
        let toolbarHeight = toolbar.bounds.height
        let deviceSafeAreaBottom = window?.safeAreaInsets.bottom ?? 34
        let bottomDistance = toolbarHeight + deviceSafeAreaBottom
        
        if let navBar = findNavigationBar() {
            let navBarHeight = navBar.bounds.height
            let deviceSafeAreaTop = window?.safeAreaInsets.top ?? 44
            let topDistance = navBarHeight + deviceSafeAreaTop
            return max(bottomDistance, topDistance)
        }
        
        return bottomDistance
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
    
    /// Gradient overlay for better status bar readability in immersion mode
    private lazy var safeAreaGradientView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.alpha = 0.0 // Initially hidden
        return view
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
        addSubview(safeAreaGradientView)
        renderView.scrollView.addSubview(refreshControlContainer)

        scrollViewDelegateMux = ScrollViewDelegateMultiplexer(scrollView: renderView.scrollView)
        scrollViewDelegateMux?.addDelegate(self)
        
        // Configure initial gradient
        configureSafeAreaGradient()
    }

    override func layoutSubviews() {
        /*
         See commentary in `PostsPageViewController.viewDidLoad()` about our layout strategy here. tl;dr layout margins are the highest-level approach available on all versions of iOS that Awful supports, so we'll use them exclusively to represent the safe area.
         */

        renderView.frame = bounds
        loadingViewContainer.frame = bounds

        let toolbarHeight = toolbar.sizeThatFits(bounds.size).height
        let toolbarY = bounds.maxY - layoutMargins.bottom - toolbarHeight
        
        // Only update frame if toolbar doesn't have a transform applied
        // This prevents layoutSubviews from overriding immersion mode transforms
        if toolbar.transform.isIdentity {
            toolbar.frame = CGRect(
                x: safeAreaInsets.left,
                y: toolbarY,
                width: bounds.width - safeAreaInsets.left - safeAreaInsets.right,
                height: toolbarHeight)
        }

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
        
        // Position gradient view to cover only the top safe area (status bar/notch)
        // Use actual device safe area top instead of layoutMargins to prevent extending into content
        let gradientHeight: CGFloat = window?.safeAreaInsets.top ?? safeAreaInsets.top
        safeAreaGradientView.frame = CGRect(
            x: 0,
            y: bounds.minY,
            width: bounds.width,
            height: gradientHeight)
        
        // Update gradient layer frame to match view bounds
        if let gradientLayer = safeAreaGradientView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = safeAreaGradientView.bounds
        }
        
        // Skip updating scroll view insets during immersion mode to prevent shudder
        if immersionModeEnabled {
            // Don't update top bar frame/insets during immersion mode
            // The bars are positioned via transforms, not frame changes
            // But we still need to set initial insets if they haven't been set yet
            if renderView.scrollView.contentInset.top == 0 {
                updateScrollViewInsets()
            }
        } else {
            updateTopBarContainerFrameAndScrollViewInsets()
        }
        
        // Reapply immersion transforms after layout (in case layout reset them)
        if immersionModeEnabled && immersionProgress > 0 {
            updateBarsForImmersionProgress()
        }
    }

    /// Assumes that various views (top bar container, refresh control container, toolbar) have been laid out.
    private func updateScrollViewInsets() {
        let scrollView = renderView.scrollView

        // For drawer-style behavior, use static insets - transforms handle the visual movement
        let bottomInset: CGFloat
        if immersionModeEnabled {
            // During immersion mode, use the static toolbar position (without transforms)
            // to keep contentInset constant and prevent scroll interference
            let toolbarHeight = toolbar.sizeThatFits(bounds.size).height
            let staticToolbarY = bounds.maxY - layoutMargins.bottom - toolbarHeight
            bottomInset = max(layoutMargins.bottom, bounds.maxY - staticToolbarY)
        } else {
            // Normal mode: use actual toolbar frame position
            bottomInset = max(layoutMargins.bottom, bounds.maxY - toolbar.frame.minY)
        }
        
        var contentInset = UIEdgeInsets(top: topBarContainer.frame.maxY, left: 0, bottom: bottomInset, right: 0)
        if case .refreshing = refreshControlState {
            contentInset.bottom += refreshControlContainer.bounds.height
        }
        scrollView.contentInset = contentInset

        // Use the same logic for scroll indicator insets
        let indicatorBottomInset: CGFloat
        if immersionModeEnabled {
            // During immersion mode, use the static toolbar position (without transforms)
            let toolbarHeight = toolbar.sizeThatFits(bounds.size).height
            let staticToolbarY = bounds.maxY - layoutMargins.bottom - toolbarHeight
            indicatorBottomInset = max(layoutMargins.bottom, bounds.maxY - staticToolbarY)
        } else {
            // Normal mode: use actual toolbar frame position
            indicatorBottomInset = max(layoutMargins.bottom, bounds.maxY - toolbar.frame.minY)
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
        
        // Update safe area gradient colors for new theme
        configureSafeAreaGradient()
    }
    
    // MARK: - Toolbar Configuration
    
    private func configureToolbarAppearance(_ toolbar: Toolbar) {
        // Modern iOS 26 appearance: translucent with hidden hairline border
        toolbar.topBorderColor = UIColor.clear
        toolbar.isTranslucent = Theme.defaultTheme()[bool: "tabBarIsTranslucent"] ?? false
    }
    
    // MARK: - Safe Area Gradient Configuration
    
    private func configureSafeAreaGradient() {
        // Remove existing gradient layer if any
        safeAreaGradientView.layer.sublayers?.removeAll()
        
        let gradientLayer = CAGradientLayer()
        let isDarkMode = Theme.defaultTheme()[string: "mode"] == "dark"
        
        if isDarkMode {
            // Black to clear gradient for dark themes
            gradientLayer.colors = [
                UIColor.black.cgColor,
                UIColor.black.withAlphaComponent(0.8).cgColor,
                UIColor.black.withAlphaComponent(0.4).cgColor,
                UIColor.clear.cgColor
            ]
            // Gradient locations - stronger at the top, fade to clear
            gradientLayer.locations = [0.0, 0.3, 0.7, 1.0]
        } else {
            // For light mode, use a very subtle white gradient that blends seamlessly
            gradientLayer.colors = [
                UIColor.white.withAlphaComponent(0.8).cgColor,
                UIColor.white.withAlphaComponent(0.6).cgColor,
                UIColor.white.withAlphaComponent(0.2).cgColor,
                UIColor.white.withAlphaComponent(0.02).cgColor,
                UIColor.clear.cgColor
            ]
            // Fade more quickly to maintain subtlety
            gradientLayer.locations = [0.0, 0.4, 0.7, 0.9, 1.0]
        }
        
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        
        safeAreaGradientView.layer.addSublayer(gradientLayer)
    }
    
    // MARK: Immersion mode helpers
    
    /// Force exit immersion mode (useful for scroll-to-top/bottom actions)
    func exitImmersionMode() {
        guard immersionModeEnabled && immersionProgress > 0 else { return }
        immersionProgress = 0.0
    }
    
    private var isUpdatingBars = false
    
    /// Update bars position based on immersion progress (no animation)
    private func updateBarsForImmersionProgress() {
        // Prevent recursive calls
        guard !isUpdatingBars else { return }
        isUpdatingBars = true
        defer { isUpdatingBars = false }
        
        // IMPORTANT: Disable any implicit animations during transform application
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        guard immersionModeEnabled else {
            // Reset everything to visible state
            safeAreaGradientView.alpha = 0.0
            
            // Reset navigation bar transform if found
            if let foundNavBar = findNavigationBar() {
                foundNavBar.transform = .identity
            }
            
            // Reset bottom toolbar transform
            toolbar.transform = .identity
            
            updateScrollViewInsets()
            CATransaction.commit()
            return
        }
        
        // Update safe area gradient
        safeAreaGradientView.alpha = immersionProgress
        
        // NOTE: Top bar container (subtoolbar) should NOT be affected by immersion mode
        // It should remain visible and functional
        
        // Apply transform to navigation bar if found - NO SYSTEM HIDE/SHOW
        if let navBar = findNavigationBar() {
            let navBarHeight = navBar.bounds.height
            
            // Use device safe area top (status bar/notch area), not layout margins
            let deviceSafeAreaTop = window?.safeAreaInsets.top ?? 44
            let totalUpwardDistance = navBarHeight + deviceSafeAreaTop
            navBar.transform = CGAffineTransform(translationX: 0, y: -totalUpwardDistance * immersionProgress)
        }
        
        // Don't update scroll view insets during immersion mode transforms
        // The insets should remain constant to avoid scroll position jumps
        
        // Apply transform to bottom toolbar - layoutSubviews now preserves transforms
        let toolbarHeight = toolbar.bounds.height
        
        // Use device safe area bottom (home indicator area), not layout margins
        let deviceSafeAreaBottom = window?.safeAreaInsets.bottom ?? 34
        let totalDownwardDistance = toolbarHeight + deviceSafeAreaBottom
        let toolbarTransform = CGAffineTransform(translationX: 0, y: totalDownwardDistance * immersionProgress)
        toolbar.transform = toolbarTransform
        
        CATransaction.commit()
    }
    
    /// Helper to find navigation bar consistently (with caching for performance)
    private func findNavigationBar() -> UINavigationBar? {
        // Return cached navigation bar if it still exists
        if let cached = cachedNavigationBar {
            return cached
        }
        
        // Approach 1: Find through responder chain
        var responder: UIResponder? = self.next
        while responder != nil {
            if let viewController = responder as? UIViewController,
               let navBar = viewController.navigationController?.navigationBar {
                cachedNavigationBar = navBar  // Cache the result
                return navBar
            }
            responder = responder?.next
        }
        
        // Approach 2: Find through window hierarchy if approach 1 failed
        if let window = self.window,
           let rootNav = window.rootViewController as? UINavigationController {
            cachedNavigationBar = rootNav.navigationBar  // Cache the result
            return rootNav.navigationBar
        }
        
        return nil
    }
    
    /// Clear cached navigation bar when view hierarchy changes
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            cachedNavigationBar = nil
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
        lastScrollOffset = scrollView.contentOffset.y
        
        // disable transparency so that scroll thumbs work in dark mode
        if darkMode, !viewHasBeenScrolledOnce {
            renderView.toggleOpaqueToFixIOS15ScrollThumbColor(setOpaqueTo: true)
            viewHasBeenScrolledOnce = true
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Optional: Snap to complete if very close to fully shown/hidden
        if immersionModeEnabled && !refreshControlState.isArmedOrTriggered {
            if immersionProgress > 0.9 {
                // Snap to fully hidden
                immersionProgress = 1.0
            } else if immersionProgress < 0.1 {
                // Snap to fully visible
                immersionProgress = 0.0
            }
            // Otherwise leave at current position
        }
        
        switch refreshControlState {
        case .armed, .triggered:
            // Top bar shouldn't fight with refresh control.
            break

        case .ready, .awaitingScrollEnd, .refreshing, .disabled:
            // Only handle regular top bar logic if immersion mode is disabled
            if !immersionModeEnabled {
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

        // Handle immersion mode drawer-style behavior  
        // Disable immersion mode when VoiceOver is running for accessibility
        if immersionModeEnabled && !UIAccessibility.isVoiceOverRunning && (scrollView.isDragging || scrollView.isDecelerating) && !refreshControlState.isArmedOrTriggered {
            let currentOffset = scrollView.contentOffset.y
            let scrollDelta = currentOffset - lastScrollOffset
            
            // Calculate the actual bottom position using adjusted content inset
            // This ensures consistent calculation even as bars move
            let contentHeight = scrollView.contentSize.height
            let adjustedBottom = scrollView.adjustedContentInset.bottom
            let maxOffsetY = max(contentHeight, scrollView.bounds.height - adjustedBottom) - scrollView.bounds.height + adjustedBottom
            
            // Use the actual bar travel distance as the threshold for smooth 1:1 movement
            let barTravelDistance = totalBarTravelDistance
            
            // Check if near top of scroll view
            let distanceFromTop = currentOffset + scrollView.adjustedContentInset.top
            let isNearTop = distanceFromTop <= barTravelDistance
            
            // Check if near bottom of scroll view
            let distanceFromBottom = maxOffsetY - currentOffset
            let isNearBottom = distanceFromBottom <= barTravelDistance
            
            if isNearTop && !isNearBottom {
                // Near top: special handling with sticky zone
                let stickyTopZone: CGFloat = 20 // Small zone where bars always stay visible
                
                if distanceFromTop <= stickyTopZone {
                    // Very close to top: keep bars fully visible
                    immersionProgress = 0
                } else {
                    // In transition zone: bars should be visible based on distance from top
                    // This creates a smooth gradient from hidden to visible as we approach top
                    let targetProgress = distanceFromTop / barTravelDistance
                    
                    // Use incremental change for smooth movement, but constrain to target
                    let incrementalProgress = immersionProgress + (scrollDelta / barTravelDistance)
                    
                    // When scrolling up toward top, reveal bars (progress decreases)
                    // When scrolling down away from top, allow bars to start hiding (progress increases)
                    // But always respect the position-based limit
                    if scrollDelta < 0 { // Scrolling up toward top
                        // Moving toward top, bars should reveal
                        immersionProgress = min(incrementalProgress, targetProgress).clamp(0...1)
                    } else { // Scrolling down away from top
                        // Moving away from top, but still respect the near-top zone
                        // Don't hide bars more than the position allows
                        immersionProgress = min(incrementalProgress, targetProgress).clamp(0...1)
                    }
                }
            } else if isNearBottom && !isNearTop {
                // Near bottom: ensure bars fully reach starting position when at actual bottom
                // But allow them to hide again when scrolling up
                
                if distanceFromBottom <= 5 && scrollDelta > 0 { // Within 5 points AND scrolling down
                    // Reaching the actual bottom - bars must be fully visible
                    immersionProgress = 0
                } else {
                    // Use smooth incremental movement based on scroll delta
                    // This provides 1:1 response without interrupting scroll
                    let incrementalProgress = immersionProgress + (scrollDelta / barTravelDistance)
                    
                    if scrollDelta > 0 { // Scrolling down toward bottom
                        // Moving toward bottom - gradually reveal bars
                        // But ensure we can reach 0 (fully visible) at bottom
                        let maxProgress = distanceFromBottom / barTravelDistance
                        immersionProgress = min(incrementalProgress, maxProgress).clamp(0...1)
                    } else { // Scrolling up away from bottom
                        // Moving away from bottom - allow bars to hide with 1:1 response
                        immersionProgress = incrementalProgress.clamp(0...1)
                    }
                }
            } else if !isNearTop && !isNearBottom {
                // Middle area: normal scroll logic
                // Use actual bar travel distance for consistent movement speed
                let newProgress = immersionProgress + (scrollDelta / barTravelDistance)
                immersionProgress = newProgress.clamp(0...1)
            }
            // If both isNearTop and isNearBottom (very short content), don't change immersionProgress
            
            lastScrollOffset = currentOffset
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
            // Only handle regular top bar logic if immersion mode is disabled
            if !immersionModeEnabled {
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
    }
}

// (progressive immersive reveal helpers removed)
