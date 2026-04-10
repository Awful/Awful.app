//  NavigationController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI
import UIKit

// MARK: - Sidebar Glass Bypass Helpers

// MARK: - Sidebar Button View

/// A SwiftUI button with `.glassEffect(.identity)` that bypasses the glass
/// panel's vibrancy compositing for bar button items in the sidebar.
@available(iOS 26.0, *)
private struct SidebarButtonView: View {
    let title: String
    let color: Color
    var weight: Font.Weight = .regular
    let action: () -> Void

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: weight))
            .foregroundStyle(color)
            .fixedSize()
            .glassEffect(.identity)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
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

    init(title: String, color: UIColor) {
        self.currentTitle = title
        self.currentColor = color
        super.init(frame: .zero)
        setupHostingView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String, color: UIColor) {
        guard title != currentTitle || color != currentColor else { return }
        currentTitle = title
        currentColor = color
        setupHostingView()
    }

    private func setupHostingView() {
        hostingController?.view.removeFromSuperview()

        let swiftUIColor = Color(currentColor)
        let content = Text(currentTitle)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(swiftUIColor)
            .glassEffect(.identity)

        let hosting = UIHostingController(rootView: AnyView(content))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: trailingAnchor),
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
        return hostingController?.view.intrinsicContentSize ?? .zero
    }

    override func sizeToFit() {
        hostingController?.view.sizeToFit()
        let size = hostingController?.view.intrinsicContentSize ?? .zero
        frame.size = size
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

        // Set forcedTintColor at init time for iPad sidebar nav controllers.
        // This ensures the very first layoutSubviews uses the correct color
        // before any view lifecycle methods fire.
        if #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            awfulNavigationBar.forcedTintColor = .white
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Routes describing the swipe-from-right-edge "unpop" stack, used by `SceneDelegate` to
    /// preserve it across cold launches. View controllers that don't conform to
    /// `RestorableLocation` (or whose `restorationRoute` is nil) are dropped, since the scene
    /// activity can only carry route-shaped data.
    var unpopRoutes: [AwfulRoute] {
        guard let handler = unpopHandler else { return [] }
        return handler.viewControllers.compactMap { ($0 as? RestorableLocation)?.restorationRoute }
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

    func statusBarEnterLightBackground() {
        isDarkContentBackground = false
        setNeedsStatusBarAppearanceUpdate()
    }

    func statusBarEnterDarkBackground() {
        isDarkContentBackground = true
        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        // For iOS 26+: use dynamic when scrolled
        if #available(iOS 26.0, *), isScrolledFromTop {
            return .default  // Let system handle it dynamically when scrolled
        }

        // Otherwise: follow the theme setting
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
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        themeDidChange()

        // Set forcedTintColor early for iPad sidebar so the first
        // layoutSubviews pass uses the correct color.
        if #available(iOS 26.0, *),
           UIDevice.current.userInterfaceIdiom == .pad,
           tabBarController != nil {
            awfulNavigationBar.forcedTintColor = theme[uicolor: "navigationBarTextColor"] ?? .white
        }

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
        updateNavigationBarAppearance(with: theme)
    }

    /// On iPad sidebar, the nav bar is inside a glass panel so buttons get
    /// flat rendering and fall back to the app's default tintColor. This
    /// method overrides with an opaque themed appearance and explicit colors.
    /// Called from both `willShow` (push/pop) and `viewWillAppear` (tab switch).
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
            replaceSidebarBarButtonItems(for: topVC, color: textColor)

            // Custom titleView using SwiftUI Text with .glassEffect(.identity)
            // to bypass the glass panel's vibrancy compositing.
            if let existing = topVC.navigationItem.titleView as? SidebarTitleView {
                existing.update(title: topVC.title ?? "", color: textColor)
            } else {
                let titleView = SidebarTitleView(title: topVC.title ?? "", color: textColor)
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

    /// Replaces text-based bar button items with custom-view equivalents that
    /// bypass the glass panel's content-level vibrancy compositing.
    @available(iOS 26.0, *)
    private func replaceSidebarBarButtonItems(for viewController: UIViewController, color: UIColor) {
        func replaceItem(_ item: UIBarButtonItem) -> UIBarButtonItem {
            // Skip items that are already custom-view items (including
            // ones we created on a previous pass).
            if item.customView != nil { return item }

            // Text-based items need custom-view wrappers to bypass glass
            // vibrancy. Detect editButtonItem by title match (identity
            // comparison via === can fail on non-initial tabs).
            let title = item.title ?? ""
            let isEditButton = title == "Edit" || title == "Done"
                || item === viewController.editButtonItem

            if isEditButton {
                return makeEditBarButtonItem(for: viewController, color: color)
            }

            if !title.isEmpty {
                return makeTextBarButtonItem(
                    title: title,
                    color: color,
                    target: item.target as AnyObject?,
                    action: item.action
                )
            }

            // Image-based items — wrap in SwiftUI with .glassEffect(.identity)
            // to bypass vibrancy, same as text items.
            if let image = item.image {
                return makeImageBarButtonItem(
                    image: image,
                    color: color,
                    accessibilityLabel: item.accessibilityLabel,
                    target: item.target as AnyObject?,
                    action: item.action
                )
            }

            item.tintColor = color
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
    }

    /// Creates a custom-view bar button item using SwiftUI with
    /// `.glassEffect(.identity)` to bypass glass vibrancy compositing.
    @available(iOS 26.0, *)
    private func makeTextBarButtonItem(
        title: String,
        color: UIColor,
        target: AnyObject?,
        action: Selector?
    ) -> UIBarButtonItem {
        let swiftUIColor = Color(color)
        let content = SidebarButtonView(title: title, color: swiftUIColor) {
            if let target = target as? NSObject, let action {
                target.perform(action, with: nil)
            }
        }
        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.sizeToFit()
        return UIBarButtonItem(customView: hosting.view)
    }

    /// Creates a custom-view bar button item that replicates `editButtonItem` behavior
    /// using SwiftUI with `.glassEffect(.identity)` to bypass vibrancy.
    @available(iOS 26.0, *)
    private func makeEditBarButtonItem(for viewController: UIViewController, color: UIColor) -> UIBarButtonItem {
        let isEditing = viewController.isEditing
        let title = isEditing
            ? NSLocalizedString("Done", comment: "Edit button done state")
            : NSLocalizedString("Edit", comment: "Edit button")
        let weight: Font.Weight = isEditing ? .bold : .regular
        let swiftUIColor = Color(color)

        let view = SidebarButtonView(title: title, color: swiftUIColor, weight: weight) { [weak viewController] in
            guard let vc = viewController else { return }
            vc.setEditing(!vc.isEditing, animated: true)
            if let nav = vc.navigationController as? NavigationController {
                nav.applySidebarAppearanceIfNeeded(with: nav.theme)
            }
        }
        let hosting = UIHostingController(rootView: view)
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
        color: UIColor,
        accessibilityLabel: String?,
        target: AnyObject?,
        action: Selector?
    ) -> UIBarButtonItem {
        let swiftUIColor = Color(color)
        let swiftUIImage = Image(uiImage: image.withRenderingMode(.alwaysTemplate))
        let content = Button {
            if let target = target as? NSObject, let action {
                target.perform(action, with: nil)
            }
        } label: {
            swiftUIImage
                .foregroundStyle(swiftUIColor)
        }
        .buttonStyle(.plain)
        .glassEffect(.identity)

        let hosting = UIHostingController(rootView: AnyView(content))
        hosting.view.backgroundColor = .clear
        let size = hosting.sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44))
        hosting.view.frame = CGRect(origin: .zero, size: size)
        hosting.view.accessibilityLabel = accessibilityLabel
        return UIBarButtonItem(customView: hosting.view)
    }

    /// Configures button appearance attributes for iOS 26 liquid glass compatibility.
    /// Omits foregroundColor to allow navigationBar.tintColor to control button text color.
    private func configureButtonAppearance(_ appearance: UINavigationBarAppearance, font: UIFont) {
        let buttonAttributes: [NSAttributedString.Key: Any] = [.font: font]
        appearance.buttonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttributes
        appearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
        appearance.backButtonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
    }

    @objc func updateNavigationBarTintForScrollProgress(_ progress: NSNumber) {
        guard #available(iOS 26.0, *) else { return }

        // On iPad/macOS, only the detail column does the glass scroll transition.
        // The sidebar (primary) keeps its opaque themed nav bar.
        if UIDevice.current.userInterfaceIdiom == .pad, tabBarController != nil {
            return // sidebar/primary — keep opaque
        }

        let progressValue = CGFloat(progress.floatValue)

        // Avoid redundant appearance rebuilds when progress hasn't changed.
        if abs(progressValue - lastAppliedScrollProgress) < 0.005 {
            return
        }
        lastAppliedScrollProgress = progressValue

        updateNavigationBarBackgroundWithProgress(progressValue)

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
        guard #available(iOS 26.0, *) else { return }
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
        appearance.shadowColor = nil
        appearance.shadowImage = nil

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

            if let gradientImage = createGradientBackgroundImage(from: gradientBaseColor) {
                appearance.backgroundImage = gradientImage
                let overlayAlpha = 1.0 - progress
                appearance.backgroundColor = opaqueColor.withAlphaComponent(overlayAlpha)
            } else {
                appearance.backgroundColor = interpolateColor(from: opaqueColor, to: gradientBaseColor, progress: progress)
            }
        }
    }

    @available(iOS 26.0, *)
    private func configureBackIndicator(for appearance: UINavigationBarAppearance, progress: CGFloat) {
        if progress > ScrollProgress.fullyScrolled {
            if let backImage = UIImage(named: "back")?.withTintColor(.label, renderingMode: .alwaysOriginal) {
                appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
            }
        } else {
            if let backImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate) {
                appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
            }
        }
    }

    @available(iOS 26.0, *)
    private func configureTitleAndButtons(for appearance: UINavigationBarAppearance, progress: CGFloat) {
        let textColor: UIColor
        if progress > ScrollProgress.fullyScrolled {
            textColor = theme["mode"] == "dark" ? .white : .black
        } else {
            textColor = theme[uicolor: "navigationBarTextColor"] ?? .label
        }

        appearance.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]

        let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
        configureButtonAppearance(appearance, font: buttonFont)
    }

    @available(iOS 26.0, *)
    private func applyAppearance(_ appearance: UINavigationBarAppearance, progress: CGFloat) {
        awfulNavigationBar.standardAppearance = appearance
        awfulNavigationBar.scrollEdgeAppearance = appearance
        awfulNavigationBar.compactAppearance = appearance
        awfulNavigationBar.compactScrollEdgeAppearance = appearance

        if progress < ScrollProgress.atTop {
            // At the top, the nav bar is opaque with theme background,
            // so use the theme's text color for button tint.
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

        if #available(iOS 26.0, *) {
            awfulNavigationBar.bottomBorderColor = .clear
        } else {
            awfulNavigationBar.bottomBorderColor = theme["topBarBottomBorderColor"]
        }

        if #available(iOS 26.0, *) {
            awfulNavigationBar.layer.shadowOpacity = 0
            awfulNavigationBar.layer.shadowColor = UIColor.clear.cgColor
        } else {
            awfulNavigationBar.layer.shadowOpacity = Float(theme[double: "navigationBarShadowOpacity"] ?? 1)
        }

        // Apply theme's status bar setting
        if theme["statusBarBackground"] == "light" {
            statusBarEnterLightBackground()
        } else {
            statusBarEnterDarkBackground()
        }

        if #available(iOS 15.0, *) {
            if #available(iOS 26.0, *),
               !(UIDevice.current.userInterfaceIdiom == .pad && tabBarController != nil) {
                // iPhone and iPad detail column: iOS 26 glass-capable appearance.
                // Sidebar nav controllers skip this — they use the opaque path
                // below so willShow/tab switches never reset tintColor to nil.
                let initialAppearance = UINavigationBarAppearance()
                initialAppearance.configureWithOpaqueBackground()
                initialAppearance.backgroundColor = theme["navigationBarTintColor"]
                initialAppearance.shadowColor = nil
                initialAppearance.shadowImage = nil

                let textColor = theme[uicolor: "navigationBarTextColor"] ?? .label

                if let backImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate) {
                    initialAppearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
                }

                initialAppearance.titleTextAttributes = [
                    .foregroundColor: textColor,
                    .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
                ]
                let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
                configureButtonAppearance(initialAppearance, font: buttonFont)

                awfulNavigationBar.standardAppearance = initialAppearance
                awfulNavigationBar.scrollEdgeAppearance = initialAppearance
                awfulNavigationBar.compactAppearance = initialAppearance
                awfulNavigationBar.compactScrollEdgeAppearance = initialAppearance

                // Start with themed tintColor so the sidebar toggle button
                // (and other bar items) are visible against the dark nav bar
                // background. The scroll transition code nils this out when
                // fully scrolled so glass can handle colors dynamically.
                awfulNavigationBar.tintColor = textColor

                awfulNavigationBar.setNeedsLayout()
                awfulNavigationBar.layoutIfNeeded()

            } else {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = theme["navigationBarTintColor"]
                appearance.shadowColor = nil
                appearance.shadowImage = nil

                if let backImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate) {
                    appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
                }

                let textColor = theme[uicolor: "navigationBarTextColor"] ?? .label

                appearance.titleTextAttributes = [.foregroundColor: textColor,
                                                 .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)]

                let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
                configureButtonAppearance(appearance, font: buttonFont)

                awfulNavigationBar.standardAppearance = appearance
                awfulNavigationBar.scrollEdgeAppearance = appearance
                awfulNavigationBar.compactAppearance = appearance
                awfulNavigationBar.compactScrollEdgeAppearance = appearance

                awfulNavigationBar.tintColor = textColor

                awfulNavigationBar.setNeedsLayout()
                awfulNavigationBar.layoutIfNeeded()
            }
        } else {
            guard let fallbackTextColor = theme[uicolor: "navigationBarTextColor"] else { return }
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: fallbackTextColor,
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
            ]
            UIBarButtonItem.appearance().setTitleTextAttributes(attrs, for: .normal)
            UIBarButtonItem.appearance().setTitleTextAttributes(attrs, for: .highlighted)

            if let backImage = UIImage(named: "back") {
                let tintedBackImage = backImage.withRenderingMode(.alwaysTemplate)
                navigationBar.backIndicatorImage = tintedBackImage
                navigationBar.backIndicatorTransitionMaskImage = tintedBackImage
            }
        }
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
        }

        if awfulNavigationBar.backIndicatorImage == nil {
            if #available(iOS 26.0, *),
               UIDevice.current.userInterfaceIdiom == .pad,
               tabBarController != nil,
               let textColor = vcTheme[uicolor: "navigationBarTextColor"] {
                // Sidebar: bake color in with .alwaysOriginal to bypass glass vibrancy
                awfulNavigationBar.backIndicatorImage = UIImage(named: "back")?.withTintColor(textColor, renderingMode: .alwaysOriginal)
                awfulNavigationBar.backIndicatorTransitionMaskImage = UIImage(named: "back")?.withTintColor(textColor, renderingMode: .alwaysOriginal)
            } else {
                awfulNavigationBar.backIndicatorImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
                awfulNavigationBar.backIndicatorTransitionMaskImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
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
                if #available(iOS 26.0, *) {
                    if let splitVC = tabBarController?.splitViewController ?? splitViewController,
                       !splitVC.isCollapsed {
                        return true // iPad with expanded split view
                    }
                    return false // iPhone — glass handles tint
                }
                return true // pre-iOS 26
            }()

            if needsManualButtonTint {
                // On iPad sidebar with iOS 26, replace text-based items with
                // custom-view equivalents to bypass glass vibrancy.
                if #available(iOS 26.0, *),
                   UIDevice.current.userInterfaceIdiom == .pad,
                   tabBarController != nil {
                    replaceSidebarBarButtonItems(for: viewController, color: textColor)
                } else {
                    viewController.navigationItem.leftBarButtonItem?.tintColor = textColor
                    viewController.navigationItem.rightBarButtonItem?.tintColor = textColor
                    viewController.navigationItem.leftBarButtonItems?.forEach { $0.tintColor = textColor }
                    viewController.navigationItem.rightBarButtonItems?.forEach { $0.tintColor = textColor }
                }

                if viewControllers.count > 1 {
                    let previousVC = viewControllers[viewControllers.count - 2]
                    previousVC.navigationItem.backBarButtonItem?.tintColor = textColor
                }
            }
        }

        awfulNavigationBar.setNeedsLayout()
        awfulNavigationBar.layoutIfNeeded()

        if #available(iOS 26.0, *) {
            isScrolledFromTop = false
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
