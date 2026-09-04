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
}

public extension NavigationBarScrollTransitioning {
    func updateGlassBarButtonGlyphs(color: UIColor?) {}
}

/// The bar-coloured strip `applyNavigationBarPlatterBackdrop` places under the bar in a plain
/// scroll view (the web views), in the top inset so it scrolls away with the content.
private final class NavigationBarBackdropStripView: UIView {}

/// The `backgroundView` installed by `applyNavigationBarPlatterBackdrop` in a collection view:
/// the bar colour in the strip under the bar (what the glass circles sample), the list
/// background everywhere else.
private final class NavigationBarBackdropView: UIView {
    let content = UIView()
    var barHeight: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = CGRect(x: 0, y: barHeight, width: bounds.width, height: max(0, bounds.height - barHeight))
    }
}

public extension UIScrollView {
    /// iOS 26 glass bar-button circles take their light/dark from the scroll view beneath the
    /// translucent bar: its trait and its background. At the top, make both match the theme's
    /// bar so the circles read as dark glass on a dark bar (`statusBarBackground`); once scrolled,
    /// hand back to the content so the circles adapt to it as the bar goes transparent.
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
        let style: UIUserInterfaceStyle = readsAsBar ? theme.navigationBarUserInterfaceStyle : .unspecified
        if overrideUserInterfaceStyle != style {
            overrideUserInterfaceStyle = style
        }

        if let collectionView = self as? UICollectionView {
            let existing = collectionView.backgroundView as? NavigationBarBackdropView
            if readsAsBar {
                let backdrop = existing ?? NavigationBarBackdropView()
                backdrop.backgroundColor = theme[uicolor: "navigationBarTintColor"]
                backdrop.content.backgroundColor = theme[uicolor: "backgroundColor"]
                backdrop.barHeight = safeAreaInsets.top
                if existing == nil {
                    collectionView.backgroundView = backdrop
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

    /// The part of the visible area under the navigation bar.
    private var navigationBarBackdropStripFrame: CGRect {
        CGRect(x: 0, y: contentOffset.y, width: bounds.width, height: safeAreaInsets.top)
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
private var overContentBackdropThemeKey = 0

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
