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
            if immersionModeEnabled && !oldValue {
                // When immersion mode is enabled, force layout to ensure proper frame
                setNeedsLayout()
                layoutIfNeeded()
            } else if !immersionModeEnabled && oldValue {
                // When immersion mode is disabled, reset all transforms
                immersionProgress = 0.0
                // Reset all transforms immediately
                if let navBar = findNavigationBar() {
                    navBar.transform = .identity
                }
                topBarContainer.transform = .identity
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
            let topDistance = navBarHeight + deviceSafeAreaTop + 30 // Match the working transform distance
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

    /// Sets the goToParentForum callback on the appropriate top bar
    func setGoToParentForum(_ callback: (() -> Void)?) {
        if let standardTopBar = topBarContainer.postsTopBar {
            standardTopBar.goToParentForum = callback
        } else if #available(iOS 26.0, *), let liquidGlassTopBar = topBarContainer.liquidGlassTopBar {
            liquidGlassTopBar.goToParentForum = callback
        }
    }
    
    /// Sets the showPreviousPosts callback on the appropriate top bar
    func setShowPreviousPosts(_ callback: (() -> Void)?) {
        if let standardTopBar = topBarContainer.postsTopBar {
            standardTopBar.showPreviousPosts = callback
        } else if #available(iOS 26.0, *), let liquidGlassTopBar = topBarContainer.liquidGlassTopBar {
            liquidGlassTopBar.showPreviousPosts = callback
        }
    }
    
    /// Sets the scrollToEnd callback on the appropriate top bar
    func setScrollToEnd(_ callback: (() -> Void)?) {
        if let standardTopBar = topBarContainer.postsTopBar {
            standardTopBar.scrollToEnd = callback
        } else if #available(iOS 26.0, *), let liquidGlassTopBar = topBarContainer.liquidGlassTopBar {
            liquidGlassTopBar.scrollToEnd = callback
        }
    }

    private let topBarContainer = TopBarContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 0) /* start with zero height when hidden */)

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
        topBarState = UIAccessibility.isVoiceOverRunning ? TopBarState.alwaysVisible : TopBarState.hidden

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
        
        // Ensure topBarContainer starts with correct height based on initial state
        updateTopBarContainerFrameAndScrollViewInsets()
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
            y: max(scrollView.contentSize.height, scrollView.bounds.height - layoutMargins.bottom) - 20,
            width: bounds.width - safeAreaInsets.left - safeAreaInsets.right,
            height: refreshControlHeight)

        let topBarHeight = topBarContainer.layoutFittingCompressedHeight(targetWidth: bounds.width - safeAreaInsets.left - safeAreaInsets.right)
        
        // Position topBarContainer based on mode and state
        let topBarY: CGFloat
        if immersionModeEnabled {
            // In immersion mode, position it to attach directly to the bottom edge of the navigation bar
            // The nav bar is positioned at layoutMargins.top, so we attach right below it
            if let navBar = findNavigationBar() {
                // Position directly at the bottom edge of the nav bar (no gap)
                // Nav bar frame.maxY gives us the exact bottom edge position
                topBarY = navBar.frame.maxY
            } else {
                topBarY = bounds.minY + layoutMargins.top + 44 // fallback nav bar height
            }
        } else {
            // In normal mode, position at top of safe area
            topBarY = bounds.minY + layoutMargins.top
        }
        
        // Only update frame if topBarContainer doesn't have a transform applied
        // This prevents layoutSubviews from overriding immersion mode transforms
        if topBarContainer.transform.isIdentity {
            topBarContainer.frame = CGRect(
                x: safeAreaInsets.left,
                y: topBarY,
                width: bounds.width - safeAreaInsets.left - safeAreaInsets.right,
                height: topBarHeight)
        }
        
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
        
        // Update top bar and scroll view insets based on mode
        updateTopBarContainerFrameAndScrollViewInsets()
        
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
            topBarState = TopBarState.alwaysVisible
        } else {
            switch topBarState {
            case .alwaysVisible:
                topBarState = TopBarState.visible
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

        // Update theme for whichever top bar is in use
        if let standardTopBar = topBarContainer.postsTopBar {
            standardTopBar.themeDidChange(Theme.defaultTheme())
        } else if #available(iOS 26.0, *), let liquidGlassTopBar = topBarContainer.liquidGlassTopBar {
            liquidGlassTopBar.themeDidChange(Theme.defaultTheme())
        }
        
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
            
            // Reset top bar container transform
            topBarContainer.transform = .identity
            
            // Reset bottom toolbar transform
            toolbar.transform = .identity
            
            updateScrollViewInsets()
            CATransaction.commit()
            return
        }
        
        // Update safe area gradient
        safeAreaGradientView.alpha = immersionProgress
        
        // Apply transform to navigation bar if found - NO SYSTEM HIDE/SHOW
        var navBarTransform: CGFloat = 0
        if let navBar = findNavigationBar() {
            let navBarHeight = navBar.bounds.height
            
            // Use device safe area top (status bar/notch area), not layout margins
            let deviceSafeAreaTop = window?.safeAreaInsets.top ?? 44
            let totalUpwardDistance = navBarHeight + deviceSafeAreaTop + 30 // Extra distance to fully disappear above safe area
            navBarTransform = -totalUpwardDistance * immersionProgress
            navBar.transform = CGAffineTransform(translationX: 0, y: navBarTransform)
        }
        
        // Position subtoolbar to move with the navigation bar as a synchronized unit
        // The subtoolbar should be attached to the bottom of the nav bar and move with it
        // Since it's positioned below the nav bar in layout, it needs the same transform to stay attached
        topBarContainer.transform = CGAffineTransform(translationX: 0, y: navBarTransform)
        
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

        private var topBarHeightConstraint: NSLayoutConstraint?
        private var isTopBarRemoved = false
        
        fileprivate lazy var topBar: UIView = {
            if #available(iOS 26.0, *) {
                let liquidGlassTopBar = PostsPageTopBarLiquidGlass()
                topBarHeightConstraint = liquidGlassTopBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
                topBarHeightConstraint?.isActive = true
                return liquidGlassTopBar
            } else {
                let standardTopBar = PostsPageTopBar()
                topBarHeightConstraint = standardTopBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
                topBarHeightConstraint?.isActive = true
                return standardTopBar
            }
        }()
        
        /// Controls whether the topBar should be hidden (height = 0) or visible (minimum height = 44)
        func setHidden(_ hidden: Bool, immersionModeEnabled: Bool = false) {
            topBarHeightConstraint?.constant = hidden ? 0 : 44
            
            // For iOS 26+ with liquid glass, remove from view hierarchy when hidden and not in immersion mode
            if #available(iOS 26.0, *), !immersionModeEnabled {
                if hidden && !isTopBarRemoved {
                    topBar.removeFromSuperview()
                    isTopBarRemoved = true
                } else if !hidden && isTopBarRemoved {
                    addSubview(topBar, constrainEdges: [.bottom, .left, .right])
                    isTopBarRemoved = false
                }
            } else {
                // For iOS < 26 or immersion mode, use the standard hide/show approach
                topBar.isHidden = hidden
            }
        }
        
        /// Sets the alpha of the topBar for smooth transitions
        func setTopBarAlpha(_ alpha: CGFloat) {
            topBar.alpha = alpha
        }
        
        /// Returns the top bar as PostsPageTopBar for iOS < 26 or PostsPageTopBarLiquidGlass for iOS 26+
        var postsTopBar: PostsPageTopBar? {
            return topBar as? PostsPageTopBar
        }
        
        @available(iOS 26.0, *)
        var liquidGlassTopBar: PostsPageTopBarLiquidGlass? {
            return topBar as? PostsPageTopBarLiquidGlass
        }


        override init(frame: CGRect) {
            super.init(frame: frame)

            // Don't clip bounds - allows smooth sliding in immersion mode
            clipsToBounds = false

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
        
        if immersionModeEnabled {
            // In immersion mode, keep subtoolbar at full height when it should be visible
            // Transforms handle the positioning, not frame height
            switch topBarState {
            case .hidden:
                topBarContainer.setHidden(true, immersionModeEnabled: immersionModeEnabled)
                topBarContainer.frame.size.height = 0
                result = .init(progress: 0) // Progress 0 when hidden
            case .appearing, .disappearing, .visible, .alwaysVisible:
                topBarContainer.setHidden(false, immersionModeEnabled: immersionModeEnabled)
                // Give it full height so transforms can work properly
                topBarContainer.layoutIfNeeded()
                topBarContainer.frame.size.height = topBarContainer.topBar.bounds.height
                result = .init(progress: 1)
            }
        } else {
            // In non-immersion mode, use frame height changes for hiding/showing
            switch topBarState {
            case .hidden:
                topBarContainer.setHidden(true, immersionModeEnabled: immersionModeEnabled)
                topBarContainer.frame.size.height = 0
                result = .init(progress: 0) // Progress 0 when hidden

            case .appearing(fromContentOffset: let initialContentOffset):
                topBarContainer.setHidden(false, immersionModeEnabled: immersionModeEnabled)
                let distance = initialContentOffset.y - renderView.scrollView.contentOffset.y
                let upperBound = topBarContainer.topBar.bounds.height
                let clamped = distance.clamp(0...upperBound)
                topBarContainer.frame.size.height = clamped
                let progress = clamped / upperBound
                
                // For iOS 26+, use alpha transition for smooth appearance
                if #available(iOS 26.0, *), !immersionModeEnabled {
                    topBarContainer.setTopBarAlpha(progress)
                }
                
                result = .init(progress: progress)

            case .disappearing(fromContentOffset: let initialContentOffset):
                topBarContainer.setHidden(false, immersionModeEnabled: immersionModeEnabled)
                let distance = renderView.scrollView.contentOffset.y - initialContentOffset.y
                let upperBound = topBarContainer.topBar.bounds.height
                let clamped = distance.clamp(0...upperBound)
                topBarContainer.frame.size.height = upperBound - clamped
                let progress = clamped / upperBound
                
                // For iOS 26+, use alpha transition for smooth disappearance
                if #available(iOS 26.0, *), !immersionModeEnabled {
                    topBarContainer.setTopBarAlpha(1.0 - progress)
                }
                
                result = .init(progress: progress)

            case .visible, .alwaysVisible:
                topBarContainer.setHidden(false, immersionModeEnabled: immersionModeEnabled)
                topBarContainer.layoutIfNeeded()
                topBarContainer.frame.size.height = topBarContainer.topBar.bounds.height
                
                // Ensure full alpha when visible
                if #available(iOS 26.0, *), !immersionModeEnabled {
                    topBarContainer.setTopBarAlpha(1.0)
                }
                
                result = .init(progress: 1)
            }
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
                    topBarState = TopBarState.appearing(fromContentOffset: scrollView.contentOffset)

                case .visible where velocity.y > 0:
                    topBarState = TopBarState.disappearing(fromContentOffset: scrollView.contentOffset)

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
            topBarState = result.progress >= 0.75 ? TopBarState.visible : TopBarState.hidden

        case .disappearing:
            topBarState = result.progress >= 0.75 ? TopBarState.hidden : TopBarState.visible

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
            
            // Simplified immersion mode: always allow bars to respond to scroll without position constraints
            // This ensures bars can fully hide when scrolling up, regardless of scroll position
            let barTravelDistance = totalBarTravelDistance
            
            // Check if near bottom of scroll view for special handling
            let distanceFromBottom = maxOffsetY - currentOffset
            let isNearBottom = distanceFromBottom <= barTravelDistance
            
            if isNearBottom {
                // Near bottom: progressive reveal behavior
                if distanceFromBottom <= 5 {
                    // At the actual bottom - bars must be fully visible
                    immersionProgress = 0
                } else {
                    // Progressive reveal based on distance from bottom
                    // Use incremental change for smooth 1:1 response
                    let incrementalProgress = immersionProgress + (scrollDelta / barTravelDistance)
                    
                    if scrollDelta > 0 {
                        // Scrolling down toward bottom - gradually reveal bars
                        // Limit progress based on distance to ensure full reveal at bottom
                        let maxProgress = distanceFromBottom / barTravelDistance
                        immersionProgress = min(incrementalProgress, maxProgress).clamp(0...1)
                    } else {
                        // Scrolling up away from bottom - allow normal 1:1 hiding
                        immersionProgress = incrementalProgress.clamp(0...1)
                    }
                }
            } else {
                // Not near bottom: simple 1:1 scroll response
                let incrementalProgress = immersionProgress + (scrollDelta / barTravelDistance)
                immersionProgress = incrementalProgress.clamp(0...1)
            }
            
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
            // Handle top bar scroll logic for both immersion and non-immersion modes
            switch (topBarState, willBeginDraggingContentOffset)  {
            case (.hidden, let willBeginDraggingContentOffset?):
                // Only trigger appearing if scrolling UP (negative delta)
                let scrollDelta = scrollView.contentOffset.y - willBeginDraggingContentOffset.y
                if scrollDelta < 0 {
                    topBarState = TopBarState.appearing(fromContentOffset: willBeginDraggingContentOffset)
                }

            case (.visible, let willBeginDraggingContentOffset?):
                // Without this check, when the refresh control is disabled, it's impossible to scroll content up when at the bottom of the page and the top bar is visible (i.e. after tapping "Scroll to Bottom"). There's surely a better approach, but this gets us working again.
                let contentOffsetYAtBottom = max(scrollView.contentSize.height + scrollView.contentInset.bottom, scrollView.bounds.height) - scrollView.bounds.height
                let isVeryCloseToBottom = abs(willBeginDraggingContentOffset.y - contentOffsetYAtBottom) < 5
                if !isVeryCloseToBottom {
                    topBarState = TopBarState.disappearing(fromContentOffset: willBeginDraggingContentOffset)
                }

            case (.hidden, _), (.visible, _), (.appearing, _), (.disappearing, _), (.alwaysVisible, _):
                break
            }
        }
    }
}

// (progressive immersive reveal helpers removed)
