//  NavigationBarPlatterBackdrop.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import ObjectiveC
import SwiftUI
import UIKit

/// A screen whose scroll view sits beneath the translucent iOS 26 navigation bar and drives its
/// opaque→clear transition.
///
/// The bar's glass bar-button circles take their light/dark from that scroll view — its trait
/// and its background — so while the screen rests at the top the navigation controller makes the
/// scroll view read as the bar (`UIScrollView.applyNavigationBarPlatterBackdrop`), giving dark
/// glass on a dark bar even in a light-mode theme, and hands it back to the content once scrolled.
/// Glyphs on dark glass ignore `tintColor`, so screens with image bar buttons bake the colour in
/// via `updateGlassBarButtonGlyphs(color:)`.
public protocol NavigationBarScrollTransitioning: AnyObject {
    /// The scroll view beneath the navigation bar.
    var navigationBarScrollView: UIScrollView? { get }

    /// Called with the theme's bar text colour while the bar rests opaque at the top, and with
    /// nil once it has gone transparent over the content. Plain image bar button items are baked
    /// by the navigation controller; implement this to bake custom-view buttons with
    /// `UIButton.setGlassGlyph(bakedColor:tint:)` (nil restores the template).
    func updateGlassBarButtonGlyphs(color: UIColor?)

    /// `.black` or `.white` as sampled from the content beneath the status bar while the bar is
    /// transparent (see `ContentContrastSampler`), or nil when unknown: nothing sampled yet, or
    /// the screen doesn't sample. The navigation controller derives the status bar style from it.
    var statusBarContentColor: UIColor? { get }

    /// True while the screen has moved the bar out from under the status bar itself (immersive
    /// mode), so the status bar sits over the content whatever the bar's scroll state. The
    /// navigation controller then styles it from `statusBarContentColor` as it does once the
    /// glass bar has gone transparent. Call `contentContrastDidChange()` when this changes.
    var isStatusBarOverContent: Bool { get }

    /// Likewise for the content beneath the navigation bar (what the title is coloured for); the
    /// navigation controller points the content blur's trait at it. Call
    /// `contentContrastDidChange()` when either colour changes.
    var navigationBarContentColor: UIColor? { get }

    /// True while the screen moves the bar out from under the status bar itself (the posts page in
    /// immersive mode): the system's soft edge effect belongs to the scroll view and can't slide
    /// away with the bar, so the bar puts its own fading blur under the transparent bar instead.
    /// False keeps the system effect, the blurred fade the lists show as they scroll under the bar.
    var usesNavigationBarContentBlur: Bool { get }
}

public extension NavigationBarScrollTransitioning {
    func updateGlassBarButtonGlyphs(color: UIColor?) {}

    var statusBarContentColor: UIColor? { nil }

    var isStatusBarOverContent: Bool { false }

    var navigationBarContentColor: UIColor? { nil }

    var usesNavigationBarContentBlur: Bool { false }
}

/// A navigation controller that restyles the status bar and its content blur from its top
/// screen's `statusBarContentColor` and `navigationBarContentColor`.
public protocol NavigationBarContentContrastObserving: AnyObject {
    func topScreenContentContrastDidChange()
}

public extension UIViewController {
    /// Tells the navigation controller that `statusBarContentColor` or
    /// `navigationBarContentColor` changed; a navigation controller that doesn't observe just
    /// gets a status bar appearance update.
    func contentContrastDidChange() {
        if let observer = navigationController as? NavigationBarContentContrastObserving {
            observer.topScreenContentContrastDidChange()
        } else {
            navigationController?.setNeedsStatusBarAppearanceUpdate()
        }
    }
}

/// The bar-coloured strip `applyNavigationBarPlatterBackdrop` places under the bar in a plain
/// scroll view (the web views), in the top inset so it scrolls away with the content.
private final class NavigationBarBackdropStripView: UIView {}

/// The `backgroundView` installed by `applyNavigationBarPlatterBackdrop` in a collection view:
/// the bar colour in the strip under the bar (what the glass circles sample), the list
/// background everywhere else.
///
/// The strip is placed under the bar wherever the visible top edge is, not at the view's own
/// top: the collection view places this view in its layout pass, so whenever that runs behind
/// the bounds (see `UIScrollView.fitNavigationBarBackdropToBar`) the view sits out from under
/// the bar and a strip at its top would show in the pull-to-refresh gap.
private final class NavigationBarBackdropView: UIView {
    /// The list background below the strip.
    let content = UIView()
    /// The list background above the strip: the gap a pull past the top opens up.
    let overscrollContent = UIView()
    var barHeight: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }
    /// The visible top edge in this view's coordinates, when the layout pass can't read it (see
    /// `UIScrollView.fitNavigationBarBackdropToBar`); nil derives it from the model geometry.
    var visibleTopOverride: CGFloat? {
        didSet {
            if visibleTopOverride != oldValue { setNeedsLayout() }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(overscrollContent)
        addSubview(content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let visibleTop: CGFloat
        if let visibleTopOverride {
            visibleTop = visibleTopOverride
        } else if let scrollView = superview as? UIScrollView {
            visibleTop = scrollView.navigationBarBackdropVisibleTop - frame.minY
        } else {
            visibleTop = 0
        }
        let stripTop = max(0, visibleTop)
        let stripBottom = max(0, visibleTop + barHeight)
        overscrollContent.frame = CGRect(x: 0, y: 0, width: bounds.width, height: stripTop)
        content.frame = CGRect(x: 0, y: stripBottom, width: bounds.width, height: max(0, bounds.height - stripBottom))
    }
}

public extension UIScrollView {
    /// iOS 26 glass bar-button circles take their light/dark from the scroll view beneath the
    /// translucent bar: its trait and its background. At the top, make both match the theme's
    /// bar so the circles read as dark glass on a dark bar (`statusBarBackground`); once scrolled,
    /// hand back to the content so the circles adapt to it as the bar goes transparent.
    ///
    /// The trait is iOS 26 only. iOS 27 reads the bar's own trait for the circles (the
    /// navigation controller sets it), and its root tab bar reads the tab root's view — which,
    /// for a collection view controller, is this scroll view — so a dark override here turned a
    /// light theme's tab bar dark. The background still tones the circles on both.
    ///
    /// Collection views get a `backgroundView` that is the bar colour only in the strip under the
    /// bar, so the list looks unchanged (a collection view's list layout paints over anything else
    /// in the top inset). Other scroll views (the web views) get a bar-coloured strip subview in
    /// the top inset, under the bar; the rest of the inset (e.g. the posts page's top bar) and the
    /// overscroll keep showing the content background.
    ///
    /// Call `relayoutNavigationBarPlatterBackdrop()` from the screen's layout pass so the strip
    /// follows inset and bar-height changes (rotation).
    func applyNavigationBarPlatterBackdrop(atTop: Bool, theme: Theme) {
        let readsAsBar = atTop && LiquidGlass.usesGlassNavigationBar
        if #unavailable(iOS 27.0) {
            let style: UIUserInterfaceStyle = readsAsBar ? theme.navigationBarUserInterfaceStyle : .unspecified
            if overrideUserInterfaceStyle != style {
                overrideUserInterfaceStyle = style
            }
        }

        if let collectionView = self as? UICollectionView {
            let existing = collectionView.backgroundView as? NavigationBarBackdropView
            if readsAsBar {
                let backdrop = existing ?? NavigationBarBackdropView()
                backdrop.backgroundColor = theme[uicolor: "navigationBarTintColor"]
                backdrop.content.backgroundColor = theme[uicolor: "backgroundColor"]
                backdrop.overscrollContent.backgroundColor = theme[uicolor: "backgroundColor"]
                backdrop.barHeight = safeAreaInsets.top
                if existing == nil {
                    collectionView.backgroundView = backdrop
                }
                observeNavigationBarBackdropGeometry(key: &backdropFitObservationsKey) { scrollView in
                    scrollView.fitNavigationBarBackdropToBar()
                }
            } else if existing != nil {
                collectionView.backgroundView = nil
            }
        } else {
            let existing = navigationBarBackdropStrip
            if readsAsBar {
                let strip = existing ?? NavigationBarBackdropStripView()
                strip.backgroundColor = theme[uicolor: "navigationBarTintColor"]
                strip.isUserInteractionEnabled = false
                strip.frame = navigationBarBackdropStripFrame
                if existing == nil {
                    insertSubview(strip, at: 0)
                }
                observeNavigationBarBackdropGeometry(key: &backdropFitObservationsKey) { scrollView in
                    scrollView.fitNavigationBarBackdropToBar()
                }
            } else {
                existing?.removeFromSuperview()
            }
        }
    }

    private var navigationBarBackdropStrip: NavigationBarBackdropStripView? {
        subviews.lazy.compactMap { $0 as? NavigationBarBackdropStripView }.first
    }

    /// Re-fits the backdrop to the current insets and bar height; a no-op without a backdrop.
    /// Call it from the screen's layout pass: the resting state is often applied before the
    /// screen has laid out (e.g. a tab shown for the first time), when the insets are still zero.
    func relayoutNavigationBarPlatterBackdrop() {
        if objc_getAssociatedObject(self, &overContentBackdropThemeKey) != nil {
            // Cells and web content are added above the strip as they lay out; this puts it back
            // on top (and back in the hierarchy if the scroll view threw it out).
            return repositionOverContentBackdrop()
        }
        if let collectionView = self as? UICollectionView {
            guard let backdrop = collectionView.backgroundView as? NavigationBarBackdropView else { return }
            backdrop.setNeedsLayout()
            let barHeight = safeAreaInsets.top
            if backdrop.barHeight != barHeight {
                backdrop.barHeight = barHeight
                refreshNavigationBarGlass()
            }
        } else if let strip = navigationBarBackdropStrip {
            let frame = navigationBarBackdropStripFrame
            if strip.frame != frame {
                strip.frame = frame
                refreshNavigationBarGlass()
            }
        }
    }

    /// The glass circles only re-sample what's beneath the bar when a different appearance
    /// object is assigned (re-assigning the same instance is a no-op), so hand the bar copies
    /// after the backdrop geometry changes.
    private func refreshNavigationBarGlass() {
        guard let bar = enclosingViewController?.navigationController?.navigationBar else { return }
        bar.standardAppearance = bar.standardAppearance.copy()
        if let scrollEdge = bar.scrollEdgeAppearance {
            bar.scrollEdgeAppearance = scrollEdge.copy()
        }
    }

    /// Observes the scroll view's own geometry so a strip can follow it; installed once per `key`.
    private func observeNavigationBarBackdropGeometry(key: UnsafeRawPointer, _ reposition: @escaping (UIScrollView) -> Void) {
        guard objc_getAssociatedObject(self, key) == nil else { return }
        let observations = [
            observe(\.contentOffset) { scrollView, _ in reposition(scrollView) },
            observe(\.bounds) { scrollView, _ in reposition(scrollView) },
        ]
        objc_setAssociatedObject(self, key, observations, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// The part of the visible area under the navigation bar (shifted with the bar when it has
    /// slid away; see `followNavigationBarPlatterBackdrop`).
    private var navigationBarBackdropStripFrame: CGRect {
        CGRect(
            x: 0,
            y: navigationBarBackdropVisibleTop,
            width: bounds.width,
            height: safeAreaInsets.top
        )
    }

    /// The visible top edge, shifted with the bar when it has slid away.
    fileprivate var navigationBarBackdropVisibleTop: CGFloat {
        bounds.origin.y + navigationBarBackdropFollowState.verticalOffset
    }

    /// Keeps whichever backdrop is installed under the bar while the screen is at the top or
    /// pulled past it (pull-to-refresh): a strip is a subview in content coordinates, so it
    /// slides down out from under the bar with the content unless it is moved, and a collection
    /// view only places its background view in its layout pass.
    ///
    /// Called from the offset observation, so it can run inside a `UIView.animate` block: a
    /// pull-to-refresh release animates the offset that way, and the model geometry is at its
    /// destination at once while what is on screen takes the animation's duration to get there.
    /// Frames set inside the block animate in step with the bounds, which keeps the backdrop
    /// under the bar throughout; a frame set from a later layout pass would jump ahead and show
    /// below the bar until the bounds caught up.
    private func fitNavigationBarBackdropToBar() {
        let inAnimationBlock = UIView.inheritedAnimationDuration > 0
        if let collectionView = self as? UICollectionView {
            guard let backdrop = collectionView.backgroundView as? NavigationBarBackdropView else { return }
            if inAnimationBlock {
                // The collection view places its background view in its layout pass; have that
                // happen inside the block too, so the view's frame animates on the same clock as
                // the bounds and the backdrop can be fitted to where it is headed.
                collectionView.layoutIfNeeded()
                backdrop.visibleTopOverride = navigationBarBackdropVisibleTop - backdrop.frame.minY
                backdrop.layoutIfNeeded()
            } else {
                backdrop.visibleTopOverride = nil
                backdrop.setNeedsLayout()
            }
        } else if let strip = navigationBarBackdropStrip {
            // A pinned strip follows the visible top at every offset by itself.
            guard objc_getAssociatedObject(self, &pinnedBackdropObservationsKey) == nil else { return }
            // Scrolled down, the strip is left to scroll away with the content (or to follow a
            // bar sliding away; see `followNavigationBarPlatterBackdrop`).
            guard bounds.origin.y <= -adjustedContentInset.top + 0.5 else { return }
            let frame = navigationBarBackdropStripFrame
            if strip.frame != frame {
                strip.frame = frame
            }
        }
    }

    /// Where the strip is relative to its resting place under the bar, and how visible it is.
    /// Mirrors the bar when a screen slides or fades it away over the content.
    private struct NavigationBarBackdropFollowState {
        var verticalOffset: CGFloat = 0
        var alpha: CGFloat = 1
    }

    private var navigationBarBackdropFollowState: NavigationBarBackdropFollowState {
        get { objc_getAssociatedObject(self, &backdropFollowStateKey) as? NavigationBarBackdropFollowState ?? .init() }
        set { objc_setAssociatedObject(self, &backdropFollowStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// For a bar that slides or fades away over the content (the posts page's immersive mode):
    /// moves the strip with the bar so it stays under it and never shows on its own. Pass the
    /// bar's translation and alpha; `0` and `1` put the strip back. Safe to call with no strip.
    func followNavigationBarPlatterBackdrop(verticalOffset: CGFloat, alpha: CGFloat) {
        let state = NavigationBarBackdropFollowState(verticalOffset: verticalOffset, alpha: alpha)
        navigationBarBackdropFollowState = state
        guard let strip = navigationBarBackdropStrip else { return }
        // The bar is mid-motion; no glass refresh, the reposition path skips it while dragging too.
        strip.frame = navigationBarBackdropStripFrame
        strip.alpha = state.alpha
    }

    /// For a scroll view under a bar that stays opaque (the search results and SAclopedia
    /// screens): the resting backdrop at every offset, the strip following the content offset so
    /// it always sits under the bar. Safe to call repeatedly, e.g. on theme changes.
    func pinNavigationBarPlatterBackdrop(theme: Theme) {
        let hadStrip = navigationBarBackdropStrip != nil
        applyNavigationBarPlatterBackdrop(atTop: true, theme: theme)
        guard LiquidGlass.usesGlassNavigationBar else { return }
        if !hadStrip {
            refreshNavigationBarGlass()
        }
        observeNavigationBarBackdropGeometry(key: &pinnedBackdropObservationsKey) { scrollView in
            scrollView.navigationBarBackdropStrip?.frame = scrollView.navigationBarBackdropStripFrame
        }
    }

    /// For a bar that stays opaque at every offset: like `pinNavigationBarPlatterBackdrop`, but
    /// the strip goes in *front* of the content. The platters sample the topmost thing beneath the
    /// bar, and content that has scrolled up under an opaque bar is itself opaque — behind it the
    /// strip would only be sampled while the screen sat at the very top. The bar hides the strip.
    ///
    /// For the web views only: a collection view's capture ignores anything drawn inside it, so
    /// list screens go through `NavigationController.installListPlatterBackdrop` instead.
    func pinNavigationBarPlatterBackdropOverContent(theme: Theme) {
        guard LiquidGlass.affectsBarButtonPlatters, !(self is UICollectionView) else { return }
        if overrideUserInterfaceStyle != theme.navigationBarUserInterfaceStyle {
            overrideUserInterfaceStyle = theme.navigationBarUserInterfaceStyle
        }
        objc_setAssociatedObject(self, &overContentBackdropThemeKey, theme, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        installOverContentBackdrop(theme: theme)
        observeNavigationBarBackdropGeometry(key: &overContentBackdropObservationsKey) { scrollView in
            scrollView.repositionOverContentBackdrop()
        }
    }

    /// Adds the strip if it isn't there (a `WKScrollView` throws ours out when it rebuilds its
    /// content) and keeps it frontmost.
    private func installOverContentBackdrop(theme: Theme) {
        let existing = navigationBarBackdropStrip
        let strip = existing ?? NavigationBarBackdropStripView()
        strip.backgroundColor = theme[uicolor: "navigationBarTintColor"]
        strip.isUserInteractionEnabled = false
        strip.frame = navigationBarBackdropStripFrame
        strip.alpha = navigationBarBackdropFollowState.alpha
        raiseNavigationBarBackdropStrip(strip, wasInstalled: existing != nil)
    }

    /// Puts the strip above the content it has to cover, but *below* UIKit's scroll indicators:
    /// the bar's backdrop capture ignores whatever sits above those, so a strip brought all the
    /// way to the front is silently left out of the sample (and stays out until a touch shuffles
    /// the order back). Verified by pixel-sampling both orderings.
    private func raiseNavigationBarBackdropStrip(_ strip: UIView, wasInstalled: Bool) {
        // Everything above the topmost non-indicator subview is either the strip itself or an
        // indicator, so this is the highest slot the capture still looks at.
        var target = subviews.count
        while target > 0, subviews[target - 1] === strip || subviews[target - 1].isScrollIndicator {
            target -= 1
        }
        let moved = subviews.firstIndex(of: strip) != target
        if moved {
            insertSubview(strip, at: min(target, subviews.count))
        }
        if moved || !wasInstalled {
            refreshNavigationBarGlass()
        }
    }

    private func repositionOverContentBackdrop() {
        guard let theme = objc_getAssociatedObject(self, &overContentBackdropThemeKey) as? Theme else { return }
        guard let strip = navigationBarBackdropStrip else {
            return installOverContentBackdrop(theme: theme)
        }
        let frame = navigationBarBackdropStripFrame
        let moved = strip.frame != frame
        strip.frame = frame
        // Content added above it as it lays out has to be got back under, without ever leaving
        // the strip above the scroll indicators.
        raiseNavigationBarBackdropStrip(strip, wasInstalled: true)
        // Live re-sampling happens by itself while a drag is in flight, and re-assigning the
        // appearance then freezes the capture instead of refreshing it.
        if moved, !isTracking, !isDragging, !isDecelerating {
            refreshNavigationBarGlass()
        }
    }

    /// An inert scroll view to put behind a screen whose own scroll view doesn't reach the bar
    /// (the composition screen, whose text view starts below the bar). The bar samples the scroll
    /// view under it; with none, the circles fall back to the bar's trait, which renders darker
    /// than the sampled glass elsewhere. Keep it at the back of the screen's view and hand it the
    /// theme on theme changes; it pins, sizes, and registers itself as the bar's content scroll
    /// view once it is in a window.
    static func makeNavigationBarPlatterBackdrop(theme: Theme) -> NavigationBarPlatterBackdropScrollView {
        let scrollView = NavigationBarPlatterBackdropScrollView()
        scrollView.theme = theme
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return scrollView
    }
}

private extension UIView {
    /// UIKit keeps its scroll indicators as the topmost subviews of a scroll view. Matching on the
    /// class name reads an implementation detail, so the callers fall back to the front of the
    /// stack if it ever stops matching.
    var isScrollIndicator: Bool {
        String(describing: type(of: self)).contains("ScrollViewScrollIndicator")
    }

    var enclosingViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let viewController = current as? UIViewController { return viewController }
            responder = current.next
        }
        return nil
    }
}

private var pinnedBackdropObservationsKey = 0
private var overContentBackdropObservationsKey = 0
private var backdropFitObservationsKey = 0
private var overContentBackdropThemeKey = 0
private var backdropFollowStateKey = 0

public extension View {
    /// Marks a SwiftUI scroll view whose bar stays opaque (the search results and SAclopedia
    /// screens) so its glass bar-button circles read as dark glass on a dark bar: apply it to the
    /// `ScrollView`'s content, so it lives inside the scroll view (and is rebuilt with it).
    /// See `UIScrollView.pinNavigationBarPlatterBackdrop(theme:)`.
    func navigationBarPlatterBackdrop() -> some View {
        background(NavigationBarPlatterBackdropAnchor())
    }

    /// The SwiftUI counterpart of `UIScrollView.makeNavigationBarPlatterBackdrop(theme:)`, for a
    /// screen with no scroll view of its own beneath the bar (the search form, whose forum list
    /// starts below a header). Apply it to the screen's root content.
    ///
    /// A `UIHostingController` screen can't just add the inert scroll view to its own view — UIKit
    /// warns that adding subviews to a hosting controller's view isn't supported — so SwiftUI owns
    /// it here.
    func navigationBarPlatterBackdropSurface() -> some View {
        background(NavigationBarPlatterBackdropSurface().ignoresSafeArea())
    }
}

/// Hosts the inert backdrop scroll view inside the SwiftUI content.
private struct NavigationBarPlatterBackdropSurface: UIViewRepresentable {
    @Environment(\.theme) private var theme

    func makeUIView(context: Context) -> NavigationBarPlatterBackdropScrollView {
        let view = NavigationBarPlatterBackdropScrollView()
        view.theme = theme
        return view
    }

    func updateUIView(_ view: NavigationBarPlatterBackdropScrollView, context: Context) {
        view.theme = theme
    }
}

/// The inert scroll view behind `UIScrollView.makeNavigationBarPlatterBackdrop(theme:)` and
/// `View.navigationBarPlatterBackdropSurface()`. The circles are toned by its `backgroundColor`
/// and blur the strip under them, so it takes the screen background (as the list screens'
/// collection views have).
public final class NavigationBarPlatterBackdropScrollView: UIScrollView {
    public var theme: Theme? {
        didSet { applyTheme() }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isScrollEnabled = false
        isUserInteractionEnabled = false
        // UIKit refuses status-bar-tap scroll-to-top when more than one scroll view is eligible.
        scrollsToTop = false
        contentInsetAdjustmentBehavior = .always
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        applyTheme()
        // The bar samples the scroll view under it, and the screen's own content doesn't reach
        // there; this one does, so claim the spot.
        if let viewController = enclosingViewController, viewController.contentScrollView(for: .top) !== self {
            viewController.setContentScrollView(self, for: .top)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if contentSize != bounds.size {
            contentSize = bounds.size
        }
        relayoutNavigationBarPlatterBackdrop()
    }

    private func applyTheme() {
        guard let theme, window != nil else { return }
        backgroundColor = theme[uicolor: "backgroundColor"]
        pinNavigationBarPlatterBackdrop(theme: theme)
    }
}

/// Pins the backdrop to the scroll view it is placed in.
private struct NavigationBarPlatterBackdropAnchor: UIViewRepresentable {
    @Environment(\.theme) private var theme

    func makeUIView(context: Context) -> NavigationBarPlatterBackdropAnchorView {
        NavigationBarPlatterBackdropAnchorView()
    }

    func updateUIView(_ view: NavigationBarPlatterBackdropAnchorView, context: Context) {
        view.theme = theme
        view.install()
    }
}

private final class NavigationBarPlatterBackdropAnchorView: UIView {
    var theme: Theme?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        install()
    }

    func install() {
        guard window != nil, let theme, let scrollView = enclosingScrollView else { return }
        scrollView.pinNavigationBarPlatterBackdrop(theme: theme)
    }

    private var enclosingScrollView: UIScrollView? {
        var ancestor = superview
        while let current = ancestor {
            if let scrollView = current as? UIScrollView { return scrollView }
            ancestor = current.superview
        }
        return nil
    }
}

private var glassGlyphTemplateKey = 0
private var glassGlyphBakedColorKey = 0
private var glassGlyphEnabledObservationKey = 0

private func glassGlyphTemplate(for object: AnyObject, current: UIImage?) -> UIImage? {
    if let stored = objc_getAssociatedObject(object, &glassGlyphTemplateKey) as? UIImage {
        return stored
    }
    objc_setAssociatedObject(object, &glassGlyphTemplateKey, current, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    return current
}

public extension UIButton {
    /// Glass vibrancy renders a bar button's glyph in a darkened bar colour on dark glass, ignoring
    /// `tintColor`. Pass the colour to bake it into the image (`.alwaysOriginal`); pass nil to go
    /// back to the template image tinted with `tint`.
    func setGlassGlyph(bakedColor: UIColor?, tint: UIColor?) {
        guard let template = glassGlyphTemplate(for: self, current: image(for: .normal)) else { return }
        if let bakedColor {
            setImage(template.withTintColor(bakedColor, renderingMode: .alwaysOriginal), for: .normal)
        } else {
            setImage(template, for: .normal)
        }
        tintColor = tint
    }
}

public extension UIBarButtonItem {
    /// See `UIButton.setGlassGlyph(bakedColor:tint:)`. UIKit doesn't dim a baked image when the
    /// item is disabled, so the baked colour follows `isEnabled`.
    func setGlassGlyph(bakedColor: UIColor?, tint: UIColor?) {
        guard glassGlyphTemplate(for: self, current: image) != nil else { return }
        objc_setAssociatedObject(self, &glassGlyphBakedColorKey, bakedColor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if bakedColor != nil, objc_getAssociatedObject(self, &glassGlyphEnabledObservationKey) == nil {
            let observation = observe(\.isEnabled) { item, _ in item.applyGlassGlyph() }
            objc_setAssociatedObject(self, &glassGlyphEnabledObservationKey, observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        applyGlassGlyph()
        tintColor = tint
    }

    private func applyGlassGlyph() {
        guard let template = glassGlyphTemplate(for: self, current: image) else { return }
        guard let bakedColor = objc_getAssociatedObject(self, &glassGlyphBakedColorKey) as? UIColor else {
            image = template
            return
        }
        let color = isEnabled ? bakedColor : bakedColor.withAlphaComponent(0.4)
        image = template.withTintColor(color, renderingMode: .alwaysOriginal)
    }
}
