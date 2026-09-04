//  NavigationController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulTheming
import SwiftUI
import UIKit

// MARK: - Sidebar Glass Bypass Views

/// A SwiftUI button with `.glassEffect(.identity)` that bypasses the glass
/// panel's vibrancy compositing for bar button items in the sidebar.
/// Reads `navigationBarTextColor` from the theme environment so the color
/// updates automatically when the user switches themes.
@available(iOS 26.0, *)
private struct SidebarButtonView: View {
    let title: String
    var weight: Font.Weight = .regular
    /// Overrides the theme's bar text colour, for bars whose glyph colour follows the scroll state.
    var color: Color? = nil
    let action: () -> Void

    @SwiftUI.Environment(\.theme) private var theme

    var body: some View {
        let color = color ?? theme[color: "navigationBarTextColor"] ?? .white
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: weight))
                .applyFontDesign(if: theme.roundedFonts)
                .foregroundStyle(color)
                .fixedSize()
        }
        .buttonStyle(.plain)
        .glassEffect(.identity)
    }
}

/// A SwiftUI image button with `.glassEffect(.identity)` that bypasses the
/// glass panel's vibrancy compositing. Reads color from the theme environment.
@available(iOS 26.0, *)
private struct SidebarImageButtonView: View {
    let image: Image
    let accessibilityLabel: String?
    var pointSize: CGFloat = 20
    /// Visual horizontal offset applied to the rendered icon (and its hit
    /// region). Used to nudge auto-replaced rightBarButtonItems toward the
    /// trailing edge to tighten the gap to system-injected items like the
    /// split-view sidebar toggle.
    var visualOffsetX: CGFloat = 0
    let action: () -> Void

    @SwiftUI.Environment(\.theme) private var theme

    var body: some View {
        let color = theme[color: "navigationBarTextColor"] ?? .white
        Button(action: action) {
            image
                .resizable()
                .scaledToFit()
                .frame(width: pointSize, height: pointSize)
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .frame(width: pointSize, height: pointSize)
        .offset(x: visualOffsetX)
        .glassEffect(.identity)
        .accessibilityLabel(accessibilityLabel ?? "")
    }
}

// MARK: - Glass Text Bar Button

/// A custom-view stand-in for a text bar button item (such as `editButtonItem`) on the iPhone
/// glass bar. The system item's label is composited through the platter's vibrancy, which
/// tints it with the bar colour behind; hosting the text under `.glassEffect(.identity)`
/// draws it in the given colour, the way the baked image items are.
@available(iOS 26.0, *)
final class GlassTextBarButtonView: UIView {
    private let hostingController: UIHostingController<AnyView>
    private var title: String
    private var weight: Font.Weight
    private var color: UIColor
    private let action: () -> Void

    init(title: String, weight: Font.Weight = .regular, color: UIColor, action: @escaping () -> Void) {
        self.title = title
        self.weight = weight
        self.color = color
        self.action = action
        hostingController = UIHostingController(rootView: AnyView(EmptyView()))
        super.init(frame: .zero)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        render()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String? = nil, weight: Font.Weight? = nil, color: UIColor? = nil) {
        let title = title ?? self.title
        let weight = weight ?? self.weight
        let color = color ?? self.color
        guard title != self.title || weight != self.weight || color != self.color else { return }
        self.title = title
        self.weight = weight
        self.color = color
        render()
    }

    /// Matches the label inset of a system text item, so the platter keeps its pill shape.
    private static let horizontalPadding: CGFloat = 14

    private func render() {
        hostingController.rootView = AnyView(
            SidebarButtonView(title: title, weight: weight, color: Color(color), action: action)
                .padding(.horizontal, Self.horizontalPadding)
                .themed()
        )
        let size = hostingController.sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44))
        frame.size = size
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize { frame.size }
}

/// A screen's Edit/Done bar button: the system `editButtonItem`, or on iOS 26 iPhone a
/// `GlassTextBarButtonView` stand-in (the iPad sidebar makes its own replacements). Call
/// `setEditing(_:)` from the screen's `setEditing(_:animated:)` and `setGlassGlyphColor(_:theme:)`
/// alongside its other glass glyph updates.
final class EditBarButton {
    private weak var viewController: UIViewController?
    private var glassView: UIView?

    init(for viewController: UIViewController) {
        self.viewController = viewController
    }

    var item: UIBarButtonItem {
        guard let viewController else { return UIBarButtonItem() }
        guard #available(iOS 26.0, *), LiquidGlass.affectsBarButtonPlatters, !LiquidGlass.affectsPadSidebar else {
            glassView = nil
            return viewController.editButtonItem
        }
        if let glassView {
            return UIBarButtonItem(customView: glassView)
        }
        // The colour is set by `setGlassGlyphColor` before the bar shows.
        let view = GlassTextBarButtonView(
            title: Self.title(isEditing: viewController.isEditing),
            weight: viewController.isEditing ? .bold : .regular,
            color: .white
        ) { [weak viewController] in
            guard let viewController else { return }
            viewController.setEditing(!viewController.isEditing, animated: true)
        }
        glassView = view
        return UIBarButtonItem(customView: view)
    }

    func setEditing(_ isEditing: Bool) {
        guard #available(iOS 26.0, *), let view = glassView as? GlassTextBarButtonView else { return }
        view.update(title: Self.title(isEditing: isEditing), weight: isEditing ? .bold : .regular)
    }

    /// `bakedColor` is the theme's bar text colour while the bar rests on the screen (see
    /// NavigationBarScrollTransitioning); nil once scrolled, when the label takes the mode colour
    /// the adaptive glass wants.
    func setGlassGlyphColor(_ bakedColor: UIColor?, theme: Theme) {
        guard #available(iOS 26.0, *), let view = glassView as? GlassTextBarButtonView else { return }
        view.update(color: bakedColor ?? theme.glassContentTextColor)
    }

    static func title(isEditing: Bool) -> String {
        isEditing
            ? NSLocalizedString("Done", comment: "Edit button done state")
            : NSLocalizedString("Edit", comment: "Edit button")
    }
}

/// A screen's plain text bar button (Cancel, Send, Preview…). On iOS 26 the system item's label
/// is composited through a bar-button platter's vibrancy, which washes it into the bar colour
/// behind, so the item gets a `GlassTextBarButtonView` stand-in that keeps the colour it is
/// given — the text equivalent of baking an image item's glyph.
///
/// Use `item` wherever the plain item went, including for `title` and `isEnabled`: the stand-in
/// follows both. Screens hand the resting colour along from their
/// `NavigationBarScrollTransitioning.updateGlassBarButtonGlyphs(color:)`.
final class GlassTextBarButton {
    let item: UIBarButtonItem
    private var glassView: UIView?
    private var observations: [NSKeyValueObservation] = []
    /// The colour the label rests at; nil until the bar first styles the screen.
    private var bakedColor: UIColor?

    init(title: String, weight: Font.Weight = .regular, action: @escaping () -> Void) {
        if #available(iOS 26.0, *), LiquidGlass.affectsBarButtonPlatters {
            // The colour arrives from `setGlassGlyphColor` before the bar shows.
            let view = GlassTextBarButtonView(title: title, weight: weight, color: .white, action: action)
            glassView = view
            item = UIBarButtonItem(customView: view)
            item.title = title
        } else {
            item = UIBarButtonItem(title: title, image: nil, primaryAction: UIAction { _ in action() }, menu: nil)
        }
        // A custom view shows neither the item's title nor its disabled state, so mirror both.
        observations = [
            item.observe(\.title) { [weak self] item, _ in self?.applyTitle(item.title) },
            item.observe(\.isEnabled) { [weak self] item, _ in self?.applyColor(isEnabled: item.isEnabled) },
        ]
    }

    /// The theme's bar text colour while the bar rests opaque on the screen, nil once scrolled —
    /// see `NavigationBarScrollTransitioning`.
    func setGlassGlyphColor(_ color: UIColor?, theme: Theme) {
        bakedColor = color ?? theme.glassContentTextColor
        applyColor(isEnabled: item.isEnabled)
    }

    private func applyTitle(_ title: String?) {
        guard #available(iOS 26.0, *), let view = glassView as? GlassTextBarButtonView, let title else { return }
        view.update(title: title)
    }

    private func applyColor(isEnabled: Bool) {
        guard #available(iOS 26.0, *), let view = glassView as? GlassTextBarButtonView else { return }
        let color = bakedColor ?? .white
        view.update(color: isEnabled ? color : color.withAlphaComponent(0.4))
        view.isUserInteractionEnabled = isEnabled
    }
}

// MARK: - Sidebar Title View

/// A titleView that uses SwiftUI Text with `.glassEffect(.identity)` to bypass
/// the glass panel's vibrancy compositing that tints UILabel text colors.
@available(iOS 26.0, *)
final class SidebarTitleView: UIView {
    private var hostingController: UIHostingController<AnyView>?
    private var currentTitle: String
    private var currentColor: UIColor
    private var useRoundedFont: Bool
    /// When true, the title view reports a very wide intrinsic content size
    /// so UINavigationBar gives it the full available width; the SwiftUI
    /// content then uses an HStack with Spacers to center the text inside.
    /// When false (the default), the title view reports the natural text
    /// width and renders a plain Text — the bar centers a snug-fitting
    /// title view absolutely. The wide-mode is needed for VCs whose
    /// leading/trailing bar items are asymmetric (e.g. auto-back-button
    /// pushed VCs in iPad sidebar mode); the natural-mode is the right
    /// default for tab roots, which usually have balanced bar items.
    private var fillsAvailableWidth: Bool

    /// The hosting view's edge constraints, kept so `layoutSubviews()` can
    /// shift the content in wide mode: the bar clamps this view to the span
    /// between its item clusters, and when those clusters are unequal that
    /// span — and anything centered within it — sits off the bar's center.
    private var hostingLeadingConstraint: NSLayoutConstraint?
    private var hostingTrailingConstraint: NSLayoutConstraint?

    // Mid-transition the bar sits deeper: transition hosts add ~3 levels.
    private static let maxBarSearchDepth = 16
    private static let correctionEpsilon: CGFloat = 0.5
    private static let maxCorrectionDelta: CGFloat = 50
    /// Below this bar width (iPad mini portrait sidebar ≈ 256pt; the Pros
    /// are 350pt) a bar-centered title can't clear the trailing cluster, so
    /// the title gap-centers between the clusters instead: the correction
    /// stands down and the fill-mode Spacers do the centering.
    static let narrowBarWidthThreshold: CGFloat = 300

    init(title: String, color: UIColor, roundedFont: Bool, fillsAvailableWidth: Bool = false) {
        self.currentTitle = title
        self.currentColor = color
        self.useRoundedFont = roundedFont
        self.fillsAvailableWidth = fillsAvailableWidth
        super.init(frame: .zero)
        setupHostingView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String, color: UIColor, roundedFont: Bool, fillsAvailableWidth: Bool = false) {
        guard title != currentTitle
            || color != currentColor
            || roundedFont != useRoundedFont
            || fillsAvailableWidth != self.fillsAvailableWidth
        else { return }
        currentTitle = title
        currentColor = color
        useRoundedFont = roundedFont
        self.fillsAvailableWidth = fillsAvailableWidth
        setupHostingView()
    }

    private func setupHostingView() {
        hostingController?.view.removeFromSuperview()

        let swiftUIColor = Color(currentColor)
        let baseText = Text(currentTitle)
            .font(.system(size: 17, weight: .semibold))
            .applyFontDesign(if: useRoundedFont)
            .foregroundStyle(swiftUIColor)
            .lineLimit(1)
            .truncationMode(.tail)

        let content: AnyView
        if fillsAvailableWidth {
            // HStack with leading/trailing Spacers + .frame(maxWidth: .infinity)
            // so the title view fills the bar's available width and the Text
            // sits at the visual center within. Long Text collapses Spacers
            // to zero and fills + truncates trailing.
            content = AnyView(
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    baseText
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .glassEffect(.identity)
            )
        } else {
            // Natural-width title — bar centers a snug-fitting title view
            // absolutely. Used for tab roots with balanced bar items.
            content = AnyView(baseText.glassEffect(.identity))
        }

        let hosting = UIHostingController(rootView: AnyView(content))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        // Don't let the bar's safe area leak into the SwiftUI content: a
        // wide-mode title view that the bar centers across the full width
        // (Settings — no leading items) otherwise gets its HStack inset on
        // one side and renders the text off-center inside a perfectly
        // centered container.
        hosting.safeAreaRegions = []
        addSubview(hosting.view)

        // Re-created (not reused) so every mode/title/color change starts
        // from constants of 0, clearing any stale centering correction.
        let leading = hosting.view.leadingAnchor.constraint(equalTo: leadingAnchor)
        let trailing = hosting.view.trailingAnchor.constraint(equalTo: trailingAnchor)
        hostingLeadingConstraint = leading
        hostingTrailingConstraint = trailing
        NSLayoutConstraint.activate([
            leading,
            trailing,
            hosting.view.topAnchor.constraint(equalTo: topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        hostingController = hosting
        hosting.view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        hosting.view.invalidateIntrinsicContentSize()
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        // In wide mode, claim a width larger than any nav bar will ever be —
        // UINavigationBar clamps to the available width between leading and
        // trailing bar items, which is exactly what we want for VCs with
        // asymmetric bar items. In default (natural) mode, return the
        // hosting view's intrinsic so the bar can absolutely-center a
        // snug-fitting title view (the right behavior for tab roots).
        let hostingIntrinsic = hostingController?.view.intrinsicContentSize ?? .zero
        if fillsAvailableWidth {
            return CGSize(width: 10000, height: hostingIntrinsic.height)
        } else {
            return hostingIntrinsic
        }
    }

    override func sizeToFit() {
        hostingController?.view.sizeToFit()
        let size = hostingController?.view.intrinsicContentSize ?? .zero
        frame.size = size
    }

    /// In wide mode, re-center the content on the navigation bar. The bar
    /// clamps this view to the span between its leading and trailing item
    /// clusters, and when those clusters are unequal (a lone back button
    /// against compose + the system sidebar toggle, whose presence varies
    /// with display mode) that span's center — where the Spacers put the
    /// text — sits off the bar's center. The cluster widths change at
    /// runtime, so measure and compensate at layout time.
    ///
    /// Updating the constants here is loop-safe: this view's own frame is
    /// imposed by the bar's frame-based layout, and in wide mode
    /// `intrinsicContentSize` is a constant, so the edit dirties only this
    /// view — one extra pass recomputes an identical delta, lands inside
    /// the epsilon, and stops.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard fillsAvailableWidth,
              bounds.width > 0,
              window != nil,
              let leading = hostingLeadingConstraint,
              let trailing = hostingTrailingConstraint
        else { return }

        var ancestor = superview
        var depth = 0
        var bar: UINavigationBar?
        while let view = ancestor, depth < Self.maxBarSearchDepth {
            if let navigationBar = view as? UINavigationBar {
                bar = navigationBar
                break
            }
            ancestor = view.superview
            depth += 1
        }
        // No bar reachable (mid-transition/detached): keep the current
        // correction — resetting would visibly jump, and the next pass in a
        // settled hierarchy recomputes it anyway.
        guard let bar else { return }

        // Narrow bar: gap-center. There is no room to put the title on the
        // bar's center without colliding with the trailing cluster, so let
        // the content center in the span the bar granted and clear any
        // correction left over from a wider layout.
        if bar.bounds.width < Self.narrowBarWidthThreshold {
            if abs(leading.constant) > Self.correctionEpsilon || abs(trailing.constant) > Self.correctionEpsilon {
                leading.constant = 0
                trailing.constant = 0
            }
            return
        }

        var delta = convert(CGPoint(x: bar.bounds.midX, y: 0), from: bar).x - bounds.midX
        // A huge delta means the bar has this view staged at a transitional
        // offset; skip rather than swing the content around mid-animation.
        guard abs(delta) <= Self.maxCorrectionDelta else { return }

        // The constants attach to leading/trailing anchors, which flip sides
        // in right-to-left layout; delta is in x-coordinates.
        if effectiveUserInterfaceLayoutDirection == .rightToLeft {
            delta = -delta
        }

        // Shifting one edge in by 2*delta moves the content's center by
        // delta, and shrinks long titles to the symmetric span so they
        // truncate centered instead of filling the lopsided one.
        let newLeading = max(0, 2 * delta)
        let newTrailing = min(0, 2 * delta)
        if abs(newLeading - leading.constant) > Self.correctionEpsilon
            || abs(newTrailing - trailing.constant) > Self.correctionEpsilon {
            leading.constant = newLeading
            trailing.constant = newTrailing
        }
    }
}

/**
 Navigation controller with special powers:

 - Theming support.
 - Custom navbar class `NavigationBar`.
 - Shows and hides the toolbar depending on whether the view controller has toolbar items.
 - On iPhone, allows swiping from the *right* screen edge to unpop a view controller.
 */
final class NavigationController: UINavigationController, Themeable {

    /// Scroll progress thresholds for navigation bar appearance transitions
    private enum ScrollProgress {
        static let atTop: CGFloat = 0.01
        static let fullyScrolled: CGFloat = 0.99
    }

    private static let gradientImageSize = CGSize(width: 1, height: 96)

    fileprivate weak var realDelegate: UINavigationControllerDelegate?
    fileprivate lazy var unpopHandler: UnpoppingViewHandler? = {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return nil }
        return UnpoppingViewHandler(navigationController: self)
    }()
    fileprivate var pushAnimationInProgress = false
    
    // We cannot override the designated initializer, -initWithNibName:bundle:, and call -initWithNavigationBarClass:toolbarClass: within. So we override what we can to ensure our navigation bar and toolbar classes are used.

    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    required init() {
        super.init(navigationBarClass: NavigationBar.self, toolbarClass: Toolbar.self)
        delegate = self
    }
    
    override convenience init(rootViewController: UIViewController) {
        self.init()
        viewControllers = [rootViewController]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Routes describing the swipe-from-right-edge "unpop" stack, used by `SceneDelegate` to
    /// preserve it across cold launches. View controllers that don't conform to
    /// `RestorableLocation` (or whose `restorationRoute` is nil) are dropped, since the scene
    /// activity can only carry route-shaped data.
    ///
    /// The stack is consumed from the end, so an entry that can't be saved makes everything below
    /// it unreachable too. This truncates there rather than dropping entries individually: keeping
    /// non-adjacent survivors would leave a restored unpop pushing a view controller that wasn't
    /// the next one up.
    var unpopRoutes: [AwfulRoute] {
        guard let handler = unpopHandler else { return [] }
        let restorable = handler.viewControllers
            .reversed()
            .prefix { ($0 as? RestorableLocation)?.restorationRoute != nil }
            .reversed()
        return restorable.compactMap { ($0 as? RestorableLocation)?.restorationRoute }
    }

    /// Replaces the unpop stack contents with the given view controllers without performing any
    /// navigation. Caller is responsible for constructing the view controllers (typically from
    /// previously saved `unpopRoutes`).
    func setUnpopStack(_ viewControllers: [UIViewController]) {
        unpopHandler?.viewControllers = viewControllers
    }

    private var awfulNavigationBar: NavigationBar {
        return navigationBar as! NavigationBar
    }

    @available(iOS 26.0, *)
    private func createGradientBackgroundImage(from color: UIColor, size: CGSize = gradientImageSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [color.cgColor, color.withAlphaComponent(0.0).cgColor] as CFArray
            let locations: [CGFloat] = [0.0, 1.0]
            
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
                return
            }
            
            let startPoint = CGPoint(x: 0, y: 0)
            let endPoint = CGPoint(x: 0, y: size.height)
            
            context.cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        }
    }

    var theme: Theme {
        // Get theme from the top view controller if it's Themeable
        if let themeableVC = topViewController as? Themeable {
            return themeableVC.theme
        }
        // Fallback to default theme
        return Theme.defaultTheme()
    }
    
    // MARK: Status bar style management
    var isDarkContentBackground = false
    var isScrolledFromTop = false
    private var lastAppliedScrollProgress: CGFloat = -1

    // MARK: Scroll-driven appearance caches
    //
    // `updateNavigationBarTintForScrollProgress` rebuilds a UINavigationBarAppearance on
    // every scroll delta above 0.005. Cache the expensive pieces so scroll-driven updates
    // don't re-allocate/redraw identical resources each frame.
    private var cachedGradientImage: UIImage?
    private var cachedGradientImageColor: UIColor?
    private lazy var cachedBackIndicatorTemplate: UIImage? = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
    private var cachedBackIndicatorsByColor: [UIColor: UIImage] = [:]

    /// The back chevron with `color` baked in: glass vibrancy ignores `tintColor` on the dark
    /// circles the bar shows at the top (see NavigationBarScrollTransitioning), and the bar's
    /// trait follows the bar rather than the content, so a dynamic colour would resolve wrongly
    /// once scrolled.
    private func backIndicatorImage(tinted color: UIColor) -> UIImage? {
        if let cached = cachedBackIndicatorsByColor[color] {
            return cached
        }
        guard let image = UIImage(named: "back")?.withTintColor(color, renderingMode: .alwaysOriginal) else { return nil }
        cachedBackIndicatorsByColor[color] = image
        return image
    }

    private lazy var listPlatterBackdropStrip: UIView = {
        let strip = UIView()
        strip.isUserInteractionEnabled = false
        return strip
    }()

    private lazy var listPlatterBackdrop: UIScrollView = {
        let backdrop = UIScrollView()
        backdrop.isScrollEnabled = false
        backdrop.isUserInteractionEnabled = false
        backdrop.scrollsToTop = false
        backdrop.backgroundColor = .clear
        backdrop.contentInsetAdjustmentBehavior = .never
        backdrop.showsVerticalScrollIndicator = false
        backdrop.showsHorizontalScrollIndicator = false
        backdrop.accessibilityElementsHidden = true
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdrop.addSubview(listPlatterBackdropStrip)
        return backdrop
    }()

    /// A collection view can't hand the bar a usable backdrop: its cells scroll over anything we
    /// put under the bar, and its capture ignores our own subviews entirely (verified by pixel
    /// sampling with a navy view covering the whole visible area, above every cell and below the
    /// scroll indicators). So under Reduce Liquid Glass the list is kept out from under the bar
    /// (`edgesForExtendedLayout`) and this inert scroll view takes its place there — clear, so the
    /// capture samples rather than flattening to a colour, with one bar-coloured strip for it to
    /// sample. The opaque bar hides it.
    @available(iOS 26.0, *)
    private func installListPlatterBackdrop(for viewController: UIViewController, theme: Theme) {
        // The list has to stop at the bar, or it is the one UIKit picks and samples.
        if viewController.edgesForExtendedLayout != [] {
            viewController.edgesForExtendedLayout = []
            viewController.view.setNeedsLayout()
        }
        let backdrop = listPlatterBackdrop
        backdrop.overrideUserInterfaceStyle = theme.navigationBarUserInterfaceStyle
        listPlatterBackdropStrip.backgroundColor = theme[uicolor: "navigationBarTintColor"]
        if backdrop.superview !== view {
            backdrop.frame = view.bounds
            view.insertSubview(backdrop, at: 0)
        }
        layoutListPlatterBackdrop()
        if viewController.contentScrollView(for: .top) !== backdrop {
            viewController.setContentScrollView(backdrop, for: .top)
        }
    }

    /// Re-fits the backdrop after a bounds change (rotation): the strip has to keep covering the
    /// bar, and an inert scroll view has to keep `contentSize` in step with its bounds.
    @available(iOS 26.0, *)
    private func layoutListPlatterBackdrop() {
        guard listPlatterBackdrop.superview === view else { return }
        listPlatterBackdrop.frame = view.bounds
        listPlatterBackdrop.contentSize = listPlatterBackdrop.bounds.size
        // The navigation controller's own safe area stops at the status bar, but the platter sits
        // in the bar below it, so the strip is sized to the bar instead.
        let barBottom = max(navigationBar.frame.maxY, view.safeAreaInsets.top)
        listPlatterBackdropStrip.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: barBottom)
    }

    /// Undoes `installListPlatterBackdrop` when Liquid Glass is switched back on, so the list goes
    /// back to scrolling under the translucent bar and driving the platters itself.
    @available(iOS 26.0, *)
    private func removeListPlatterBackdrop(for viewController: UIViewController) {
        if viewController.contentScrollView(for: .top) === listPlatterBackdrop {
            viewController.setContentScrollView(nil, for: .top)
        }
        if viewController.edgesForExtendedLayout != .all {
            viewController.edgesForExtendedLayout = .all
            viewController.view.setNeedsLayout()
        }
        if listPlatterBackdrop.superview != nil {
            listPlatterBackdrop.removeFromSuperview()
        }
    }

    /// iOS 26 glass bar-button circles take their light/dark from the scroll view beneath the
    /// bar (or from the bar's own trait when nothing scrolls beneath it), and their glyphs ignore
    /// tintColor on dark glass. At the top, make the screen's scroll view read as the bar (dark
    /// glass on a dark bar, even in a light theme) and bake the theme's bar text colour into its
    /// glyphs; once scrolled, hand both back to the content.
    @available(iOS 26.0, *)
    private func applyGlassRestingState(atTop: Bool, for viewController: UIViewController?, theme: Theme) {
        guard let viewController else { return }
        let screen = viewController as? NavigationBarScrollTransitioning
        if LiquidGlass.isEnabled {
            screen?.navigationBarScrollView?.applyNavigationBarPlatterBackdrop(atTop: atTop, theme: theme)
            removeListPlatterBackdrop(for: viewController)
        } else if screen?.navigationBarScrollView is UICollectionView {
            // See `installListPlatterBackdrop`: a collection view can't be made to sample right.
            installListPlatterBackdrop(for: viewController, theme: theme)
        } else {
            // Reduce Liquid Glass keeps the bar solid at every offset, so the backdrop never gets
            // handed back to the content — and it has to sit in front of it to stay sampled.
            screen?.navigationBarScrollView?.pinNavigationBarPlatterBackdropOverContent(theme: theme)
        }

        let color = atTop ? theme[uicolor: "navigationBarTextColor"] : nil
        for item in navigationBarItems(of: viewController) where item.customView == nil && item.image != nil {
            item.setGlassGlyph(bakedColor: color, tint: nil)
        }
        screen?.updateGlassBarButtonGlyphs(color: color)
    }

    @available(iOS 26.0, *)
    private func gradientBackgroundImage(from color: UIColor) -> UIImage? {
        if let cached = cachedGradientImage, cachedGradientImageColor == color {
            return cached
        }
        let image = createGradientBackgroundImage(from: color)
        cachedGradientImage = image
        cachedGradientImageColor = color
        return image
    }

    func statusBarEnterLightBackground() {
        isDarkContentBackground = false
        setNeedsStatusBarAppearanceUpdate()
    }

    func statusBarEnterDarkBackground() {
        isDarkContentBackground = true
        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        // Once the glass bar has gone transparent the system picks the style for the content.
        if #available(iOS 26.0, *), LiquidGlass.usesGlassNavigationBar, isScrolledFromTop {
            return .default
        }

        if isDarkContentBackground {
            return .lightContent
        } else {
            return .darkContent
        }
    }
    
    
    // MARK: Swipe to unpop
    
    override func popViewController(animated: Bool) -> UIViewController? {
        let viewController = super.popViewController(animated: animated)
        unpopHandler?.navigationController(self, didPopViewController: viewController)
        return viewController
    }
    
    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        let popped = super.popToViewController(viewController, animated: animated)
        for viewController in popped ?? [] {
            unpopHandler?.navigationController(self, didPopViewController: viewController)
        }
        return popped
    }
    
    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        let popped = super.popToRootViewController(animated: animated)
        for viewController in popped ?? [] {
            unpopHandler?.navigationController(self, didPopViewController: viewController)
        }
        return popped
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        pushAnimationInProgress = true
        
        super.pushViewController(viewController, animated: animated)
        
        unpopHandler?.navigationController(self, didPushViewController: viewController)
    }

    /// UIKit implements the `viewControllers` property setter by calling through to
    /// `setViewControllers(_:animated:)`, so plain property assignment would otherwise hit the
    /// override below and clear the unpop stack. The split view's collapse/separate handling
    /// assigns the property to move stacks between columns and relies on the unpop stack
    /// surviving — see the unpop TODO in
    /// `RootViewControllerStack.splitViewController(_:separateSecondaryFrom:)`.
    private var isAssigningViewControllersProperty = false

    override var viewControllers: [UIViewController] {
        get { super.viewControllers }
        set {
            isAssigningViewControllersProperty = true
            defer { isAssigningViewControllersProperty = false }
            super.viewControllers = newValue
        }
    }

    /// An explicit `setViewControllers(_:animated:)` call replaces the stack wholesale, so the
    /// staged unpop view controllers are discarded (otherwise the swipe-from-right-edge gesture
    /// would splice an unrelated screen back on top). Assigning the `viewControllers` property
    /// deliberately does *not* clear the stack; see `isAssigningViewControllersProperty` above.
    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)

        if !isAssigningViewControllersProperty {
            unpopHandler?.navigationControllerDidReplaceStack(self)
        }
    }
    
    // MARK: View lifecycle
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if #available(iOS 26.0, *) {
            layoutListPlatterBackdrop()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        themeDidChange()

        interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if #available(iOS 26.0, *) {
            applySidebarAppearanceIfNeeded(with: theme)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if #available(iOS 26.0, *) {
            applySidebarAppearanceIfNeeded(with: theme)
        }
    }

    func themeDidChange() {
        lastAppliedScrollProgress = -1
        cachedGradientImage = nil
        cachedGradientImageColor = nil
        updateNavigationBarAppearance(with: theme)

        if #available(iOS 26.0, *) {
            applySidebarAppearanceIfNeeded(with: theme)
            if let topVC = topViewController {
                updateSharedBackgroundVisibility(for: topVC)
            }
        }
    }

    /// On iPad sidebar, the nav bar is inside a glass panel so buttons get
    /// flat rendering and fall back to the app's default tintColor. This
    /// method overrides with an opaque themed appearance and explicit colors.
    /// Called on push/pop (`willShow`), view appearance (tab switch), and
    /// theme changes.
    ///
    /// Runs regardless of the Reduce Liquid Glass setting: that setting only
    /// swaps the app's own bar appearances, while UIKit keeps rendering the
    /// sidebar column as a glass panel, so the bypass is needed either way.
    @available(iOS 26.0, *)
    private func applySidebarAppearanceIfNeeded(with theme: Theme) {
        // A nav controller inside the tab bar controller is always a
        // sidebar column on iPad. We intentionally avoid checking
        // splitViewController here because it isn't available during
        // initial setup (the tab bar is added to the split view AFTER
        // its child nav controllers are configured).
        guard UIDevice.current.userInterfaceIdiom == .pad,
              tabBarController != nil else { return }

        let textColor = theme[uicolor: "navigationBarTextColor"] ?? .label

        let sidebarAppearance = UINavigationBarAppearance()
        sidebarAppearance.configureWithOpaqueBackground()
        sidebarAppearance.backgroundColor = theme["navigationBarTintColor"]
        sidebarAppearance.shadowColor = nil
        sidebarAppearance.shadowImage = nil
        sidebarAppearance.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]
        // Use .alwaysOriginal with the color baked in to bypass the glass
        // panel's vibrancy compositing (same approach as title images).
        // The system back button is replaced by a custom-view
        // leftBarButtonItem in `replaceSidebarBarButtonItems` for iPad
        // sidebar mode, so this image is only seen on iPhone (where it
        // sits at a sensible inset by default).
        if let backImage = UIImage(named: "back")?.withTintColor(textColor, renderingMode: .alwaysOriginal) {
            sidebarAppearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        }
        let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
        let buttonAttributes: [NSAttributedString.Key: Any] = [
            .font: buttonFont,
            .foregroundColor: textColor
        ]
        sidebarAppearance.buttonAppearance.normal.titleTextAttributes = buttonAttributes
        sidebarAppearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttributes
        sidebarAppearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttributes
        sidebarAppearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
        sidebarAppearance.backButtonAppearance.normal.titleTextAttributes = buttonAttributes
        sidebarAppearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttributes

        awfulNavigationBar.standardAppearance = sidebarAppearance
        awfulNavigationBar.scrollEdgeAppearance = sidebarAppearance
        awfulNavigationBar.compactAppearance = sidebarAppearance
        awfulNavigationBar.compactScrollEdgeAppearance = sidebarAppearance
        awfulNavigationBar.tintColor = textColor
        awfulNavigationBar.forcedTintColor = textColor
        awfulNavigationBar.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]
        view.tintColor = textColor

        if let topVC = topViewController {
            // Replace system bar button items with custom-view equivalents
            // that bypass the glass panel's vibrancy compositing.
            replaceSidebarBarButtonItems(for: topVC)

            // Custom titleView using SwiftUI Text with .glassEffect(.identity)
            // to bypass the glass panel's vibrancy compositing. Wide mode —
            // where the title view claims the full available width and
            // SidebarTitleView re-centers its content on the bar in
            // layoutSubviews — is used for pushed VCs (their injected back
            // button makes the bars asymmetric) and on narrow bars (iPad
            // mini portrait), which leading-anchor a natural-width title
            // view instead of centering it; there the fill content's
            // Spacers gap-center the title between the clusters, with the
            // bar-centering correction standing down. Tab roots on regular
            // bars keep the natural-width mode where the bar
            // absolutely-centers a snug title view.
            //
            // Width comes from our own view — the split view sizes the
            // column before the first appearance pass, while the bar lays
            // out a beat later, and a wrong first verdict renders one frame
            // in the wrong mode. Zero (not yet laid out) means "not
            // narrow"; a later pass corrects it.
            let roundedFont = theme.roundedFonts
            let columnWidth = view.bounds.width > 0 ? view.bounds.width : awfulNavigationBar.bounds.width
            let isNarrowBar = columnWidth > 0 && columnWidth < SidebarTitleView.narrowBarWidthThreshold
            let fillsAvailableWidth = viewControllers.first !== topVC || isNarrowBar
            if let existing = topVC.navigationItem.titleView as? SidebarTitleView {
                existing.update(
                    title: topVC.title ?? "",
                    color: textColor,
                    roundedFont: roundedFont,
                    fillsAvailableWidth: fillsAvailableWidth
                )
            } else {
                let titleView = SidebarTitleView(
                    title: topVC.title ?? "",
                    color: textColor,
                    roundedFont: roundedFont,
                    fillsAvailableWidth: fillsAvailableWidth
                )
                titleView.sizeToFit()
                topVC.navigationItem.titleView = titleView
            }

            // Hide the back button text to avoid vibrancy tinting it blue.
            // The back arrow image still shows (it responds to forcedTintColor).
            if viewControllers.count > 1 {
                let previousVC = viewControllers[viewControllers.count - 2]
                previousVC.navigationItem.backBarButtonItem = UIBarButtonItem(
                    title: "", style: .plain, target: nil, action: nil
                )
            }
        }
    }

    /// When the user has disabled Liquid Glass, hides the shared glass background behind every
    /// bar button item (the system back button doesn't expose this and stays glass). Assignment
    /// rather than set-once so re-enabling glass recovers.
    @available(iOS 26.0, *)
    private func updateSharedBackgroundVisibility(for viewController: UIViewController) {
        let hide = !LiquidGlass.isEnabled
        let toolbarItems = (viewController.toolbarItems ?? []).filter { !$0.isSpacer }
        for item in navigationBarItems(of: viewController) + toolbarItems {
            item.hidesSharedBackground = hide
        }
    }

    /// Hands both screens' bar button items their shared glass background back for the length of a
    /// push or pop, then takes it away again.
    ///
    /// UIKit morphs the outgoing screen's bar-button background into the incoming one's. Under
    /// Reduce Liquid Glass ours are hidden, so the morph has no shape to start from and UIKit
    /// materialises the incoming platter out of the item's raw bounds instead: a hard-cornered
    /// rectangle that rounds into the back button's circle, after which the glass lens goes on
    /// refracting that rectangle for the best part of a second. Lending the background back for
    /// the transition gives the morph a capsule to grow from, and the resting state is untouched
    /// because it is taken away again the moment the transition ends (whether it finished or was
    /// cancelled).
    ///
    /// Verified frame by frame: everything else that looked promising — `UIBarButtonItem`'s
    /// `identifier` and `sharesBackground`, a capsule `cornerConfiguration` on the custom views,
    /// and dropping the navigation bar's forced mid-transition layout passes — changed nothing.
    /// Nor is the custom-view stand-in to blame: a plain system `editButtonItem` with the
    /// background hidden shows exactly the same rectangle.
    @available(iOS 26.0, *)
    private func lendSharedBackgroundDuringTransition(_ navigationController: UINavigationController) {
        guard !LiquidGlass.isEnabled, let coordinator = navigationController.transitionCoordinator else { return }
        let screens = [coordinator.viewController(forKey: .from), coordinator.viewController(forKey: .to)]
            .compactMap { $0 }
            .filter { !navigationBarItems(of: $0).isEmpty }
        guard !screens.isEmpty else { return }

        for item in screens.flatMap(navigationBarItems) {
            item.hidesSharedBackground = false
        }

        // Re-read the setting when restoring rather than assuming: the user can flip it while the
        // transition is in flight.
        //
        // Known cost: UIKit animates the loan away by shrinking it into a tight ring around the
        // label, which sits on the arriving screen's button for about a third of a second after
        // the transition has finished. It resists `UIView.performWithoutAnimation`,
        // `CATransaction.setDisableActions`, restoring off the animation context on the next
        // runloop turn, re-seating the bar's items, toggling `sharesBackground` around the change,
        // and restoring partway through the transition instead of at the end. Restoring inside
        // the transition's own animation removes the ring but brings the rectangle back, because
        // the morph loses its shape halfway through.
        let restore = { [weak self] in
            guard let self else { return }
            let hide = !LiquidGlass.isEnabled
            for screen in screens {
                for item in self.navigationBarItems(of: screen) {
                    item.hidesSharedBackground = hide
                }
            }
        }
        if !coordinator.animate(alongsideTransition: nil, completion: { _ in restore() }) {
            // The coordinator wouldn't take the block, so there is nothing to restore it later.
            restore()
        }
    }

    /// The screen's own bar button items — the ones `hidesSharedBackground` applies to. The system
    /// back button isn't among them; it keeps its platter either way.
    @available(iOS 26.0, *)
    private func navigationBarItems(of viewController: UIViewController) -> [UIBarButtonItem] {
        let navigationItem = viewController.navigationItem
        return ((navigationItem.leftBarButtonItems ?? []) + (navigationItem.rightBarButtonItems ?? []))
            .filter { !$0.isSpacer }
    }

    /// Replaces text-based bar button items with custom-view equivalents that
    /// bypass the glass panel's content-level vibrancy compositing.
    @available(iOS 26.0, *)
    private func replaceSidebarBarButtonItems(for viewController: UIViewController) {
        func replaceItem(_ item: UIBarButtonItem) -> UIBarButtonItem {
            // Skip items that are already custom-view items (including
            // ones we created on a previous pass). The SwiftUI views read
            // color from @Environment(\.theme) so they update automatically.
            if item.customView != nil { return item }

            // Text-based items need custom-view wrappers to bypass glass
            // vibrancy. Detect editButtonItem by title match (identity
            // comparison via === can fail on non-initial tabs).
            let title = item.title ?? ""
            let isEditButton = title == "Edit" || title == "Done"
                || item === viewController.editButtonItem

            if isEditButton {
                return makeEditBarButtonItem(for: viewController)
            }

            if !title.isEmpty {
                return makeTextBarButtonItem(
                    title: title,
                    target: item.target as AnyObject?,
                    action: item.action
                )
            }

            // Image-based items — wrap in SwiftUI with .glassEffect(.identity)
            // to bypass vibrancy, same as text items.
            if let image = item.image {
                return makeImageBarButtonItem(
                    image: image,
                    accessibilityLabel: item.accessibilityLabel,
                    target: item.target as AnyObject?,
                    action: item.action
                )
            }

            return item
        }

        // Replace single items
        if let right = viewController.navigationItem.rightBarButtonItem {
            let replaced = replaceItem(right)
            if replaced !== right {
                viewController.navigationItem.rightBarButtonItem = replaced
            }
        }
        if let left = viewController.navigationItem.leftBarButtonItem {
            let replaced = replaceItem(left)
            if replaced !== left {
                viewController.navigationItem.leftBarButtonItem = replaced
            }
        }
        // Replace items in arrays (overrides single-item setters)
        if let rights = viewController.navigationItem.rightBarButtonItems, !rights.isEmpty {
            let updated = rights.map { replaceItem($0) }
            if zip(rights, updated).contains(where: { $0 !== $1 }) {
                viewController.navigationItem.rightBarButtonItems = updated
            }
        }
        if let lefts = viewController.navigationItem.leftBarButtonItems, !lefts.isEmpty {
            let updated = lefts.map { replaceItem($0) }
            if zip(lefts, updated).contains(where: { $0 !== $1 }) {
                viewController.navigationItem.leftBarButtonItems = updated
            }
        }

        // Replace the system back button with a custom-view leftBarButtonItem
        // when there's something to pop back to and the VC hasn't claimed the
        // leading slot itself. setBackIndicatorImage doesn't honor
        // alignmentRectInsets in iOS 26's glass nav bar, leaving the chevron
        // visibly more inset than the matched custom-view items (Edit, etc).
        // Routing the back chevron through the same hosting-view path gives
        // it the same tight leading position. Interactive pop-swipe is
        // preserved by the existing UIGestureRecognizerDelegate.
        //
        // Skip SwiftUI hosting controllers (e.g. anything pushed via a SwiftUI
        // `NavigationLink` from the Settings tab — theme picker, app icon
        // picker, etc.). SwiftUI manages its own back button on these and
        // injecting our own results in two visible back chevrons. This holds
        // even for hosting controllers that drive their own UIKit chrome (the
        // pushed search screens): the system back button is still drawn
        // alongside the injected one, so they keep the system chevron.
        let hasExistingLeft = viewController.navigationItem.leftBarButtonItem != nil
            || (viewController.navigationItem.leftBarButtonItems?.isEmpty == false)
        if !hasExistingLeft,
           viewControllers.first !== viewController,
           !Self.isHostingController(viewController),
           let backImage = UIImage(named: "back") {
            let backHosting = Self.makeSidebarImageHostingView(
                image: backImage,
                accessibilityLabel: NSLocalizedString("Back", comment: "Back button accessibility label"),
                target: self,
                action: #selector(popOnSidebarBackTap)
            )
            // A lone leading item is fine even though the trailing cluster
            // is wider: SidebarTitleView re-centers its content on the bar
            // in layoutSubviews, whatever the item clusters weigh.
            let backButton = UIBarButtonItem(customView: backHosting)
            viewController.navigationItem.leftBarButtonItems = [backButton]
        }

        // A tab root with no leading items at all (Settings) gets its title
        // staged by the bar in a container squeezed between the leading edge
        // and the trailing cluster — rendered off-center even though the
        // title view's own frame reports centered, so the layout-time
        // correction can't see it. Any leading item, even a 1pt invisible
        // one, makes the bar lay the title out symmetrically. Tab roots
        // only: pushed SwiftUI screens must keep their leading slot empty
        // or their SwiftUI back button disappears.
        if !hasExistingLeft, viewControllers.first === viewController {
            let hairline = UIBarButtonItem(customView: UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 44)))
            viewController.navigationItem.leftBarButtonItems = [hairline]
        }
    }

    /// Walks the class hierarchy looking for `UIHostingController`. Generic
    /// type erasure makes a direct `is UIHostingController<…>` check awkward,
    /// so match on the class name instead. Catches both vanilla
    /// `UIHostingController` and Awful's `HostingController` subclass.
    private static func isHostingController(_ vc: UIViewController) -> Bool {
        var cls: AnyClass? = type(of: vc)
        while let c = cls {
            if NSStringFromClass(c).contains("UIHostingController") {
                return true
            }
            cls = class_getSuperclass(c)
        }
        return false
    }

    @available(iOS 26.0, *)
    @objc private func popOnSidebarBackTap() {
        _ = popViewController(animated: true)
    }

    /// Creates a custom-view bar button item using SwiftUI with
    /// `.glassEffect(.identity)` to bypass glass vibrancy compositing.
    @available(iOS 26.0, *)
    private func makeTextBarButtonItem(
        title: String,
        target: AnyObject?,
        action: Selector?
    ) -> UIBarButtonItem {
        let content = SidebarButtonView(title: title) {
            if let target = target as? NSObject, let action {
                target.perform(action, with: nil)
            }
        }.themed()
        let hosting = UIHostingController(rootView: AnyView(content))
        hosting.view.backgroundColor = .clear
        hosting.view.sizeToFit()
        return UIBarButtonItem(customView: hosting.view)
    }

    /// Creates a custom-view bar button item that replicates `editButtonItem` behavior
    /// using SwiftUI with `.glassEffect(.identity)` to bypass vibrancy.
    @available(iOS 26.0, *)
    private func makeEditBarButtonItem(for viewController: UIViewController) -> UIBarButtonItem {
        let isEditing = viewController.isEditing
        let title = EditBarButton.title(isEditing: isEditing)
        let weight: Font.Weight = isEditing ? .bold : .regular

        let view = SidebarButtonView(title: title, weight: weight) { [weak viewController] in
            guard let vc = viewController else { return }
            vc.setEditing(!vc.isEditing, animated: true)
            if let nav = vc.navigationController as? NavigationController {
                nav.applySidebarAppearanceIfNeeded(with: nav.theme)
            }
        }.themed()
        let hosting = UIHostingController(rootView: AnyView(view))
        hosting.view.backgroundColor = .clear
        let size = hosting.sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44))
        hosting.view.frame = CGRect(origin: .zero, size: size)
        return UIBarButtonItem(customView: hosting.view)
    }

    /// Creates a custom-view bar button item for an image button, using SwiftUI
    /// with `.glassEffect(.identity)` to bypass glass vibrancy compositing.
    @available(iOS 26.0, *)
    private func makeImageBarButtonItem(
        image: UIImage,
        accessibilityLabel: String?,
        target: AnyObject?,
        action: Selector?
    ) -> UIBarButtonItem {
        // Nudge the icon toward the trailing edge to tighten the gap to
        // system-injected items (e.g. the split-view sidebar toggle), which
        // can't be reduced through bar-item APIs.
        let hostingView = Self.makeSidebarImageHostingView(
            image: image,
            accessibilityLabel: accessibilityLabel,
            visualOffsetX: 16,
            target: target,
            action: action
        )
        // The icon overflows its hosting bounds because of the SwiftUI .offset;
        // make sure UIKit doesn't clip those overflowing pixels.
        hostingView.clipsToBounds = false
        return UIBarButtonItem(customView: hostingView)
    }

    /// Builds a UIHostingController-hosted view wrapping `SidebarImageButtonView`
    /// for use as a `UIBarButtonItem.customView`. Callers that need direct
    /// access to the hosting view (e.g. to animate alpha or anchor a popover)
    /// can use this directly instead of `makeImageBarButtonItem`.
    @available(iOS 26.0, *)
    static func makeSidebarImageHostingView(
        image: UIImage,
        accessibilityLabel: String?,
        pointSize: CGFloat = 20,
        visualOffsetX: CGFloat = 0,
        target: AnyObject?,
        action: Selector?
    ) -> UIView {
        let swiftUIImage = Image(uiImage: image.withRenderingMode(.alwaysTemplate))
        // Capture target weakly: the closure lives inside the SwiftUI view
        // hosted by UIBarButtonItem.customView, which is owned (transitively)
        // by the view controller — and the target is typically the same
        // view controller (or its navigation controller). A strong capture
        // would form a retain cycle that only breaks when the bar button is
        // removed.
        let content = SidebarImageButtonView(
            image: swiftUIImage,
            accessibilityLabel: accessibilityLabel,
            pointSize: pointSize,
            visualOffsetX: visualOffsetX
        ) { [weak target] in
            if let target = target as? NSObject, let action {
                target.perform(action, with: nil)
            }
        }.themed()

        let hosting = UIHostingController(rootView: AnyView(content))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        // Enforce a tight size so the bar button item doesn't reserve the
        // hosting view's natural (often larger) fitting size. The system
        // already adds inter-item spacing between bar buttons, so the
        // customView itself doesn't need internal horizontal padding.
        NSLayoutConstraint.activate([
            hosting.view.widthAnchor.constraint(equalToConstant: pointSize),
            hosting.view.heightAnchor.constraint(equalToConstant: pointSize),
        ])
        hosting.view.frame = CGRect(x: 0, y: 0, width: pointSize, height: pointSize)
        return hosting.view
    }

    /// Builds a menu-bearing sidebar button whose icon gets the same
    /// `.glassEffect(.identity)` treatment as `makeSidebarImageHostingView`, so the glass
    /// panel's vibrancy compositing doesn't mis-tint it.
    ///
    /// Split into two layers because neither half can do the whole job: SwiftUI's `Menu`
    /// can't present a `UIMenu`, and a plain UIButton — which is what `showsMenuAsPrimaryAction`
    /// needs, since UIBarButtonItem menus misbehave on iOS 26 iPad — is exactly what the
    /// vibrancy mis-tints. So the SwiftUI hosting view draws the icon and a transparent
    /// UIButton on top carries the menu.
    @available(iOS 26.0, *)
    static func makeSidebarMenuButtonView(
        image: UIImage,
        accessibilityLabel: String?,
        pointSize: CGFloat = 20,
        tapTargetSize: CGFloat = 44,
        menu: UIMenu
    ) -> UIView {
        let iconView = makeSidebarImageHostingView(
            image: image,
            accessibilityLabel: nil,
            pointSize: pointSize,
            target: nil,
            action: nil
        )
        // Purely decorative here: the SwiftUI Button inside would otherwise swallow the taps
        // meant for the menu button layered over it, and would surface to VoiceOver (and
        // XCUITest) as an unlabeled button beside the real, labeled one.
        iconView.isUserInteractionEnabled = false
        iconView.accessibilityElementsHidden = true

        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.menu = menu
        button.accessibilityLabel = accessibilityLabel
        button.translatesAutoresizingMaskIntoConstraints = false

        // The container is the tap target, so it can be larger than the icon it centers.
        let container = UIView(frame: CGRect(x: 0, y: 0, width: tapTargetSize, height: tapTargetSize))
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        container.addSubview(button)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: tapTargetSize),
            container.heightAnchor.constraint(equalToConstant: tapTargetSize),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    /// Configures button appearance attributes for iOS 26 liquid glass compatibility.
    /// Omits foregroundColor (so navigationBar.tintColor controls button text color) unless
    /// `color` is given, which the resting-at-the-top state does: the glass circles read as the
    /// bar there and take the theme's bar text colour (see NavigationBarScrollTransitioning).
    private func configureButtonAppearance(_ appearance: UINavigationBarAppearance, font: UIFont, color: UIColor? = nil) {
        var buttonAttributes: [NSAttributedString.Key: Any] = [.font: font]
        if let color {
            buttonAttributes[.foregroundColor] = color
        }
        appearance.buttonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttributes
        appearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
        appearance.backButtonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
    }

    /// Forces the next scroll-progress update to re-apply the appearance, even if the reported progress hasn't changed.
    @available(iOS 26.0, *)
    func invalidateScrollProgressCache() {
        lastAppliedScrollProgress = -1
    }

    @objc func updateNavigationBarTintForScrollProgress(_ progress: NSNumber) {
        guard #available(iOS 26.0, *), LiquidGlass.usesGlassNavigationBar else { return }

        // On iPad/macOS, only the detail column does the glass scroll transition.
        // The sidebar (primary) keeps its opaque themed nav bar.
        if UIDevice.current.userInterfaceIdiom == .pad, tabBarController != nil {
            return // sidebar/primary — keep opaque
        }

        // Reduce Liquid Glass never lets the bar go clear: it stays at the resting state.
        let progressValue = LiquidGlass.isEnabled ? CGFloat(progress.floatValue) : 0

        // Snap to the extremes: near-0 and near-1 scrolls render identically to 0 and 1,
        // so collapse them into a single stable value. Without this, oscillations around
        // the boundaries (e.g. 0.003 → 0.009 → 0.002) each clear the 0.005 delta gate
        // and rebuild the appearance even though the visual result is unchanged.
        let snappedProgress: CGFloat
        if progressValue < ScrollProgress.atTop {
            snappedProgress = 0
        } else if progressValue > ScrollProgress.fullyScrolled {
            snappedProgress = 1
        } else {
            snappedProgress = progressValue
        }

        // Avoid redundant appearance rebuilds when progress hasn't changed.
        if abs(snappedProgress - lastAppliedScrollProgress) < 0.005 {
            return
        }
        lastAppliedScrollProgress = snappedProgress

        // Before the appearance is rebuilt: the glass circles re-evaluate their light/dark then.
        if snappedProgress == 0 {
            applyGlassRestingState(atTop: true, for: topViewController, theme: theme)
        } else if snappedProgress == 1 {
            applyGlassRestingState(atTop: false, for: topViewController, theme: theme)
        }

        updateNavigationBarBackgroundWithProgress(snappedProgress)

        if progressValue < ScrollProgress.atTop {
            isScrolledFromTop = false

            if theme["statusBarBackground"] == "light" {
                statusBarEnterLightBackground()
            } else {
                statusBarEnterDarkBackground()
            }
        } else if progressValue > ScrollProgress.fullyScrolled {
            awfulNavigationBar.tintColor = nil

            if let topViewController = topViewController {
                topViewController.navigationItem.leftBarButtonItem?.tintColor = nil
                topViewController.navigationItem.rightBarButtonItem?.tintColor = nil
                topViewController.navigationItem.leftBarButtonItems?.forEach { $0.tintColor = nil }
                topViewController.navigationItem.rightBarButtonItems?.forEach { $0.tintColor = nil }
            }

            isScrolledFromTop = true
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    @objc func updateNavigationBarTintForScrollPosition(_ isAtTop: NSNumber) {
        guard #available(iOS 26.0, *), LiquidGlass.usesGlassNavigationBar else { return }
        // Scroll-based appearance handled in updateNavigationBarTintForScrollProgress,
        // which already guards against iPad split view.
        let progress = isAtTop.boolValue ? 0.0 : 1.0
        updateNavigationBarTintForScrollProgress(NSNumber(value: progress))
    }

    /// Updates the navigation bar appearance based on scroll progress for iOS 26+ liquid glass effect.
    ///
    /// This method creates a dynamic navigation bar that transitions between three states:
    /// - At top (progress < 0.01): Opaque background with theme colors
    /// - Fully scrolled (progress > 0.99): Transparent background with system-provided contrasting colors
    /// - Mid-scroll (0.01...0.99): Gradient transition between opaque and transparent states
    ///
    /// The dynamic appearance ensures optimal button visibility by letting the system adapt
    /// colors to content underneath when scrolled, while maintaining theme consistency at the top.
    ///
    /// - Parameter progress: Scroll progress value from 0.0 (at top) to 1.0 (fully scrolled)
    @available(iOS 26.0, *)
    private func updateNavigationBarBackgroundWithProgress(_ progress: CGFloat) {
        let appearance = UINavigationBarAppearance()

        configureBackground(for: appearance, progress: progress)
        configureBackIndicator(for: appearance, progress: progress)
        configureTitleAndButtons(for: appearance, progress: progress)
        applyAppearance(appearance, progress: progress)
    }

    @available(iOS 26.0, *)
    private func configureBackground(for appearance: UINavigationBarAppearance, progress: CGFloat) {
        if progress < ScrollProgress.atTop {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = theme["navigationBarTintColor"]
        } else if progress > ScrollProgress.fullyScrolled {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.backgroundImage = nil
        } else {
            appearance.configureWithTransparentBackground()

            guard let opaqueColor = theme[uicolor: "navigationBarTintColor"],
                  let gradientBaseColor = theme[uicolor: "listHeaderBackgroundColor"] else {
                return
            }

            if let gradientImage = gradientBackgroundImage(from: gradientBaseColor) {
                appearance.backgroundImage = gradientImage
                let overlayAlpha = 1.0 - progress
                appearance.backgroundColor = opaqueColor.withAlphaComponent(overlayAlpha)
            } else {
                appearance.backgroundColor = interpolateColor(from: opaqueColor, to: gradientBaseColor, progress: progress)
            }
        }

        // Must be set AFTER configureWith* — those methods reset shadow state
        // back to system defaults, which renders as a grey hairline on dark
        // themes (most visible on SpankyKongDark) once scrolled off the top.
        appearance.shadowColor = .clear
        appearance.shadowImage = nil
    }

    @available(iOS 26.0, *)
    private func configureBackIndicator(for appearance: UINavigationBarAppearance, progress: CGFloat) {
        let backImage: UIImage?
        if progress > ScrollProgress.fullyScrolled {
            backImage = backIndicatorImage(tinted: theme.glassContentTextColor)
        } else if progress < ScrollProgress.atTop,
                  let textColor = theme[uicolor: "navigationBarTextColor"] {
            backImage = backIndicatorImage(tinted: textColor)
        } else {
            backImage = cachedBackIndicatorTemplate
        }
        if let backImage {
            appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        }
    }

    @available(iOS 26.0, *)
    private func configureTitleAndButtons(for appearance: UINavigationBarAppearance, progress: CGFloat) {
        let textColor: UIColor
        if progress > ScrollProgress.fullyScrolled {
            textColor = theme.glassContentTextColor
        } else {
            textColor = theme[uicolor: "navigationBarTextColor"] ?? .label
        }

        appearance.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]

        let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
        let restingOnBar = progress < ScrollProgress.atTop
        configureButtonAppearance(appearance, font: buttonFont, color: restingOnBar ? textColor : nil)
    }

    @available(iOS 26.0, *)
    private func applyAppearance(_ appearance: UINavigationBarAppearance, progress: CGFloat) {
        awfulNavigationBar.standardAppearance = appearance
        awfulNavigationBar.scrollEdgeAppearance = appearance
        awfulNavigationBar.compactAppearance = appearance
        awfulNavigationBar.compactScrollEdgeAppearance = appearance

        if progress < ScrollProgress.atTop {
            // At the top the glass circles read as the bar, so text items take the theme's bar
            // text colour (image items are baked; see applyGlassRestingState).
            awfulNavigationBar.tintColor = theme[uicolor: "navigationBarTextColor"] ?? .label
        } else if progress > ScrollProgress.fullyScrolled {
            awfulNavigationBar.tintColor = nil
        }
    }

    private func interpolateColor(from startColor: UIColor, to endColor: UIColor, progress: CGFloat) -> UIColor {
        let progress = max(0, min(1, progress)) // Clamp to 0-1

        var startRed: CGFloat = 0, startGreen: CGFloat = 0, startBlue: CGFloat = 0, startAlpha: CGFloat = 0
        var endRed: CGFloat = 0, endGreen: CGFloat = 0, endBlue: CGFloat = 0, endAlpha: CGFloat = 0

        // Convert colors to RGB color space if needed and handle failures
        guard startColor.getRed(&startRed, green: &startGreen, blue: &startBlue, alpha: &startAlpha),
              endColor.getRed(&endRed, green: &endGreen, blue: &endBlue, alpha: &endAlpha) else {
            // If color conversion fails (e.g., non-RGB color space), return the end color at full progress
            // or start color at zero progress
            return progress >= 0.5 ? endColor : startColor
        }

        let red = startRed + (endRed - startRed) * progress
        let green = startGreen + (endGreen - startGreen) * progress
        let blue = startBlue + (endBlue - startBlue) * progress
        let alpha = startAlpha + (endAlpha - startAlpha) * progress

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    private func updateNavigationBarAppearance(with theme: Theme, for viewController: UIViewController? = nil) {
        awfulNavigationBar.barTintColor = theme["navigationBarTintColor"]

        // Repair the init-time value when the Reduce Liquid Glass setting changes while running.
        awfulNavigationBar.isTranslucent = LiquidGlass.usesGlassNavigationBar

        if #available(iOS 26.0, *), LiquidGlass.usesGlassNavigationBar {
            awfulNavigationBar.bottomBorderColor = .clear
            awfulNavigationBar.layer.shadowOpacity = 0
            awfulNavigationBar.layer.shadowColor = UIColor.clear.cgColor
        } else {
            awfulNavigationBar.bottomBorderColor = theme["topBarBottomBorderColor"]
            awfulNavigationBar.layer.shadowOpacity = Float(theme[double: "navigationBarShadowOpacity"] ?? 1)
        }

        if theme["statusBarBackground"] == "light" {
            statusBarEnterLightBackground()
        } else {
            statusBarEnterDarkBackground()
        }

        let textColor = theme[uicolor: "navigationBarTextColor"] ?? .label
        let isSidebar = UIDevice.current.userInterfaceIdiom == .pad && tabBarController != nil
        let backImage: UIImage?
        let buttonTitleColor: UIColor?
        if #available(iOS 26.0, *), LiquidGlass.usesGlassNavigationBar, !isSidebar {
            // iPhone and iPad detail column: the glass-capable bar. Sidebar nav controllers take
            // the opaque path so willShow/tab switches never reset tintColor to nil.
            //
            // The glass bar-button circles follow this trait when nothing scrolls beneath the bar
            // (the search and settings screens); a scroll view beneath the bar overrides it (see
            // applyGlassRestingState).
            awfulNavigationBar.overrideUserInterfaceStyle = theme.navigationBarUserInterfaceStyle

            // At the top the glass circles read as the bar, and their glyphs take the theme's bar
            // text colour, baked in where vibrancy would otherwise override it.
            applyGlassRestingState(atTop: true, for: viewController ?? topViewController, theme: theme)
            backImage = backIndicatorImage(tinted: textColor)
            buttonTitleColor = textColor
        } else {
            awfulNavigationBar.overrideUserInterfaceStyle = .unspecified
            backImage = cachedBackIndicatorTemplate
            buttonTitleColor = nil
        }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = theme["navigationBarTintColor"]
        appearance.shadowColor = nil
        appearance.shadowImage = nil
        if let backImage {
            appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        }
        appearance.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]
        let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
        configureButtonAppearance(appearance, font: buttonFont, color: buttonTitleColor)

        awfulNavigationBar.standardAppearance = appearance
        awfulNavigationBar.scrollEdgeAppearance = appearance
        awfulNavigationBar.compactAppearance = appearance
        awfulNavigationBar.compactScrollEdgeAppearance = appearance

        awfulNavigationBar.tintColor = textColor

        awfulNavigationBar.setNeedsLayout()
        awfulNavigationBar.layoutIfNeeded()
    }
    
    // MARK: Delegate delegation
    
    override weak var delegate: UINavigationControllerDelegate? {
        didSet {
            if delegate === self {
                realDelegate = nil
            } else {
                realDelegate = delegate
                delegate = self
            }
        }
    }
    
    override func responds(to selector: Selector) -> Bool {
        return super.responds(to: selector) || realDelegate?.responds(to: selector) ?? false
    }
    
    override func forwardingTarget(for selector: Selector) -> Any? {
        if let realDelegate = realDelegate , realDelegate.responds(to: selector) {
            return realDelegate
        }
        return nil
    }
}

extension NavigationController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Disable swipe-to-pop gesture recognizer during pop animations and when we have nothing to pop. If we don't do this, something bad happens in conjunction with the swipe-to-unpop that causes a pushed view controller not to actually appear on the screen. It looks like the app has simply frozen.
        // See http://holko.pl/ios/2014/04/06/interactive-pop-gesture/ for more, and https://github.com/fastred/AHKNavigationController for the fix.
        return viewControllers.count > 1 && !pushAnimationInProgress
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        /*
            Allow simultaneous recognition with:
         
                1. The swipe-to-unpop gesture recognizer.
                2. The swipe-to-show-basement gesture recognizer.
         */
        return otherGestureRecognizer is UIScreenEdgePanGestureRecognizer
    }
}

extension NavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {

        let vcTheme: Theme
        if let themeableViewController = viewController as? Themeable {
            vcTheme = themeableViewController.theme
            updateNavigationBarAppearance(with: vcTheme, for: viewController)
        } else {
            vcTheme = theme
            updateNavigationBarAppearance(with: vcTheme, for: viewController)
        }

        // Apply sidebar glass bypass (titleView, button replacement) for
        // pushed VCs too, not just on tab switches.
        if #available(iOS 26.0, *) {
            applySidebarAppearanceIfNeeded(with: vcTheme)
            updateSharedBackgroundVisibility(for: viewController)
            lendSharedBackgroundDuringTransition(navigationController)
        }

        if awfulNavigationBar.backIndicatorImage == nil {
            if #available(iOS 26.0, *), let backImage = vcTheme[uicolor: "navigationBarTextColor"].flatMap(backIndicatorImage(tinted:)) {
                // Glass vibrancy ignores tintColor, on the sidebar panel and on the back button's
                // platter alike (which stays even under Reduce Liquid Glass), so bake the colour in.
                awfulNavigationBar.backIndicatorImage = backImage
                awfulNavigationBar.backIndicatorTransitionMaskImage = backImage
            } else {
                awfulNavigationBar.backIndicatorImage = cachedBackIndicatorTemplate
                awfulNavigationBar.backIndicatorTransitionMaskImage = cachedBackIndicatorTemplate
            }
        }

        if !isScrolledFromTop {
            guard let textColor = vcTheme[uicolor: "navigationBarTextColor"] else { return }

            awfulNavigationBar.tintColor = textColor

            // On iOS 26 iPhone, the liquid glass system handles button
            // colors dynamically. On iPad sidebar, glass-on-glass is
            // disallowed so buttons get flat rendering that inherits
            // tintColor — we must set it explicitly. Pre-iOS 26 also
            // needs manual tinting.
            let needsManualButtonTint: Bool = {
                if #available(iOS 26.0, *), LiquidGlass.usesGlassNavigationBar {
                    if let splitVC = tabBarController?.splitViewController ?? splitViewController,
                       !splitVC.isCollapsed {
                        return true // iPad with expanded split view
                    }
                    return false // iPhone — glass handles tint
                }
                return true // pre-iOS 26 or Liquid Glass disabled
            }()

            if needsManualButtonTint {
                // On iPad sidebar with iOS 26, replace text-based items with
                // custom-view equivalents to bypass glass vibrancy.
                if #available(iOS 26.0, *),
                   UIDevice.current.userInterfaceIdiom == .pad,
                   tabBarController != nil {
                    replaceSidebarBarButtonItems(for: viewController)
                } else {
                    let buttonTintColor: UIColor
                    if #available(iOS 26.0, *), LiquidGlass.usesGlassNavigationBar,
                       !(viewController is NavigationBarScrollTransitioning) {
                        // Liquid glass renders bar buttons in glass circles that adapt to the
                        // content; ignore the theme's white and match the title label / back
                        // button. (Screens whose circles read as the bar take the theme colour.)
                        buttonTintColor = vcTheme.glassContentTextColor
                    } else {
                        buttonTintColor = textColor
                    }
                    viewController.navigationItem.leftBarButtonItem?.tintColor = buttonTintColor
                    viewController.navigationItem.rightBarButtonItem?.tintColor = buttonTintColor
                    viewController.navigationItem.leftBarButtonItems?.forEach { $0.tintColor = buttonTintColor }
                    viewController.navigationItem.rightBarButtonItems?.forEach { $0.tintColor = buttonTintColor }
                }

                if viewControllers.count > 1 {
                    let previousVC = viewControllers[viewControllers.count - 2]
                    previousVC.navigationItem.backBarButtonItem?.tintColor = textColor
                }
            }
        }

        awfulNavigationBar.setNeedsLayout()
        awfulNavigationBar.layoutIfNeeded()

        if #available(iOS 26.0, *), LiquidGlass.usesGlassNavigationBar {
            isScrolledFromTop = false
            invalidateScrollProgressCache()

            if animated {
                // A cancelled interactive pop calls neither -...didShowViewController: nor scrollViewDidScroll,
                // so nothing would restore the transparent bar on a still-scrolled page. The coordinator's
                // completion does run on cancellation, after the rewind settles.
                navigationController.transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] context in
                    guard context.isCancelled, let self else { return }
                    self.invalidateScrollProgressCache()
                    (self.topViewController as? NavigationBarScrollProgressProviding)?.resyncNavigationBarScrollProgress()
                }
            }
        }

        if let unpopHandler = unpopHandler , animated {
            unpopHandler.navigationControllerDidBeginAnimating()
            
            // We need to hook into the transitionCoordinator's notifications as well as -...didShowViewController: because the latter isn't called when the default interactive pop action is cancelled.
            // See http://stackoverflow.com/questions/23484310
            let interactionChanges = { (context: UIViewControllerTransitionCoordinatorContext) in
                guard context.isCancelled else { return }
                let unpopping = unpopHandler.interactiveUnpopIsTakingPlace
                let completion = context.transitionDuration * Double(context.percentComplete)
                var viewControllerCount = navigationController.viewControllers.count
                if !unpopping {
                    viewControllerCount += 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + completion) {
                    if unpopping {
                        unpopHandler.navigationControllerDidCancelInteractiveUnpop()
                    } else {
                        unpopHandler.navigationControllerDidCancelInteractivePop()
                    }

                    self.pushAnimationInProgress = false
                }
            }

            navigationController.transitionCoordinator?.notifyWhenInteractionChanges(interactionChanges)
        }
        
        realDelegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if animated {
            unpopHandler?.navigationControllerDidFinishAnimating()
        }

        pushAnimationInProgress = false
        
        realDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
    }
    
    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if let unpopHandler = unpopHandler, animationController === unpopHandler {
            return unpopHandler
        }
        
        return realDelegate?.navigationController?(navigationController, interactionControllerFor: animationController)
    }
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if let unpopHandler = unpopHandler , unpopHandler.shouldHandleAnimatingTransitionForOperation(operation) {
            return unpopHandler
        }
        
        return realDelegate?.navigationController?(navigationController, animationControllerFor: operation, from: fromVC, to: toVC)
    }
}

/// A view controller that can re-derive the navigation bar's opaque/clear state from its current
/// scroll position when no scroll event will arrive to do so (e.g. after a cancelled interactive pop).
@MainActor protocol NavigationBarScrollProgressProviding: UIViewController {
    func resyncNavigationBarScrollProgress()
}
