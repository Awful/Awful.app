//  NavigationController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import UIKit

/**
 Navigation controller with special powers:

 - Theming support.
 - Custom navbar class `NavigationBar`, including after state restoration.
 - Shows and hides the toolbar depending on whether the view controller has toolbar items.
 - On iPhone, allows swiping from the *right* screen edge to unpop a view controller.
 */
final class NavigationController: UINavigationController, Themeable {
    fileprivate weak var realDelegate: UINavigationControllerDelegate?
    fileprivate lazy var unpopHandler: UnpoppingViewHandler? = {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return nil }
        return UnpoppingViewHandler(navigationController: self)
    }()
    fileprivate var pushAnimationInProgress = false
    
    // We cannot override the designated initializer, -initWithNibName:bundle:, and call -initWithNavigationBarClass:toolbarClass: within. So we override what we can, and handle our own restoration, to ensure our navigation bar and toolbar classes are used.
    
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }
    
    required init() {
        super.init(navigationBarClass: NavigationBar.self, toolbarClass: Toolbar.self)
        restorationClass = type(of: self)
        delegate = self
    }
    
    override convenience init(rootViewController: UIViewController) {
        self.init()
        viewControllers = [rootViewController]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var awfulNavigationBar: NavigationBar {
        return navigationBar as! NavigationBar
    }
    
    /// Creates a gradient background image for iOS 26+ liquid glass effect
    @available(iOS 26.0, *)
    private func createGradientBackgroundImage(from color: UIColor, size: CGSize = CGSize(width: 1, height: 96)) -> UIImage? {
        return UIGraphicsImageRenderer(size: size).image { context in
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
    
    // MARK: set the status icons (clock, wifi, battery) to black or white depending on the mode of the theme
    // thanks sarunw https://sarunw.com/posts/how-to-set-status-bar-style/
    var isDarkContentBackground = false
    var isScrolledFromTop = false  // Track scroll state for iOS 26 dynamic status bar

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
        
        interactivePopGestureRecognizer?.delegate = self
    }
    
    func themeDidChange() {
        updateNavigationBarAppearance(with: theme)
    }

    /// Updates navigation bar tint for scroll progress
    /// Call this from scroll view delegates to enable smooth dynamic color adaptation when scrolling
    @objc func updateNavigationBarTintForScrollProgress(_ progress: NSNumber) {
        guard #available(iOS 26.0, *) else { return }

        let progressValue = CGFloat(progress.floatValue)

        // First update the background appearance
        updateNavigationBarBackgroundWithProgress(progressValue)

        // Then update text colors and tint based on threshold (keep existing behavior for text)
        if progressValue < 0.01 {
            // Fully at top: use theme colors
            let textColor: UIColor = theme["navigationBarTextColor"]!

            // Set tintColor which affects back button and bar button items
            awfulNavigationBar.tintColor = theme["navigationBarTextColor"]

            // Force update bar button items to use the theme color
            if let topViewController = topViewController {
                topViewController.navigationItem.leftBarButtonItem?.tintColor = textColor
                topViewController.navigationItem.rightBarButtonItem?.tintColor = textColor
                topViewController.navigationItem.leftBarButtonItems?.forEach { $0.tintColor = textColor }
                topViewController.navigationItem.rightBarButtonItems?.forEach { $0.tintColor = textColor }
            }

            isScrolledFromTop = false

            // Set status bar based on theme
            if theme["statusBarBackground"] == "light" {
                statusBarEnterLightBackground()
            } else {
                statusBarEnterDarkBackground()
            }
        } else if progressValue > 0.99 {
            // Fully scrolled: nil for dynamic adaptation
            awfulNavigationBar.tintColor = nil

            // Reset bar button items to inherit dynamic color
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

    /// Legacy method for backwards compatibility
    @objc func updateNavigationBarTintForScrollPosition(_ isAtTop: NSNumber) {
        guard #available(iOS 26.0, *) else { return }
        // Convert boolean to progress (0 or 1)
        let progress = isAtTop.boolValue ? 0.0 : 1.0
        updateNavigationBarTintForScrollProgress(NSNumber(value: progress))
    }

    /// Smoothly transitions navigation bar background based on scroll progress
    private func updateNavigationBarBackgroundWithProgress(_ progress: CGFloat) {
        guard #available(iOS 26.0, *) else { return }

        // Create interpolated appearance based on progress
        let appearance = UINavigationBarAppearance()

        if progress < 0.01 {
            // Fully at top - use opaque background
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = theme["navigationBarTintColor"]
        } else if progress > 0.99 {
            // Fully scrolled - use gradient background
            appearance.configureWithTransparentBackground()
            let listHeaderBackgroundColor: UIColor = theme["listHeaderBackgroundColor"]!
            if let gradientImage = createGradientBackgroundImage(from: listHeaderBackgroundColor) {
                appearance.backgroundImage = gradientImage
            } else {
                appearance.backgroundColor = listHeaderBackgroundColor
            }
        } else {
            // In transition - interpolate between states
            appearance.configureWithTransparentBackground()

            // Get base colors
            let opaqueColor: UIColor = theme["navigationBarTintColor"]!
            let gradientBaseColor: UIColor = theme["listHeaderBackgroundColor"]!

            // Create a blended background
            if let gradientImage = createGradientBackgroundImage(from: gradientBaseColor) {
                // Use gradient with interpolated overlay
                appearance.backgroundImage = gradientImage

                // Add semi-transparent overlay of opaque color that fades out
                let overlayAlpha = 1.0 - progress
                appearance.backgroundColor = opaqueColor.withAlphaComponent(overlayAlpha)
            } else {
                // Fallback: blend the two colors
                appearance.backgroundColor = interpolateColor(from: opaqueColor, to: gradientBaseColor, progress: progress)
            }
        }

        // Common appearance settings
        appearance.shadowColor = nil
        appearance.shadowImage = nil

        // Set back indicator in appearance with appropriate tinting
        if progress > 0.99 {
            // When scrolled, use a black-tinted version for dynamic appearance
            if let backImage = UIImage(named: "back")?.withTintColor(.label, renderingMode: .alwaysOriginal) {
                appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
            }
        } else {
            // When at top, use template for theme color
            if let backImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate) {
                appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
            }
        }

        // Set title text attributes based on scroll position
        if progress < 0.01 {
            // At top: use theme colors
            let textColor: UIColor = theme["navigationBarTextColor"]!

            appearance.titleTextAttributes = [
                NSAttributedString.Key.foregroundColor: textColor,
                NSAttributedString.Key.font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
            ]
            let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
            let buttonAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: textColor,
                .font: buttonFont
            ]
            appearance.buttonAppearance.normal.titleTextAttributes = buttonAttributes
            appearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttributes
            appearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttributes
            appearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
            appearance.backButtonAppearance.normal.titleTextAttributes = buttonAttributes
            appearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
        } else if progress > 0.99 {
            // Fully scrolled: no foreground color for dynamic adaptation
            appearance.titleTextAttributes = [
                NSAttributedString.Key.font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
            ]
            let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
            let buttonAttributes: [NSAttributedString.Key: Any] = [
                .font: buttonFont
            ]
            appearance.buttonAppearance.normal.titleTextAttributes = buttonAttributes
            appearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttributes
            appearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttributes
            appearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
            appearance.backButtonAppearance.normal.titleTextAttributes = buttonAttributes
            appearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
        } else {
            // In transition: use theme colors
            let textColor: UIColor = theme["navigationBarTextColor"]!

            appearance.titleTextAttributes = [
                NSAttributedString.Key.foregroundColor: textColor,
                NSAttributedString.Key.font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
            ]
            let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
            let buttonAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: textColor,
                .font: buttonFont
            ]
            appearance.buttonAppearance.normal.titleTextAttributes = buttonAttributes
            appearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttributes
            appearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttributes
            appearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
            appearance.backButtonAppearance.normal.titleTextAttributes = buttonAttributes
            appearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
        }

        // Apply the interpolated appearance
        awfulNavigationBar.standardAppearance = appearance
        awfulNavigationBar.scrollEdgeAppearance = appearance
        awfulNavigationBar.compactAppearance = appearance
        awfulNavigationBar.compactScrollEdgeAppearance = appearance

        // IMPORTANT: Re-apply tintColor after changing appearance
        // The appearance change can reset the tintColor
        if progress < 0.01 {
            awfulNavigationBar.tintColor = theme["navigationBarTextColor"]
        } else if progress > 0.99 {
            awfulNavigationBar.tintColor = nil
        }
    }

    /// Interpolates between two colors based on progress (0.0 to 1.0)
    private func interpolateColor(from startColor: UIColor, to endColor: UIColor, progress: CGFloat) -> UIColor {
        let progress = max(0, min(1, progress)) // Clamp to 0-1

        var startRed: CGFloat = 0, startGreen: CGFloat = 0, startBlue: CGFloat = 0, startAlpha: CGFloat = 0
        var endRed: CGFloat = 0, endGreen: CGFloat = 0, endBlue: CGFloat = 0, endAlpha: CGFloat = 0

        startColor.getRed(&startRed, green: &startGreen, blue: &startBlue, alpha: &startAlpha)
        endColor.getRed(&endRed, green: &endGreen, blue: &endBlue, alpha: &endAlpha)

        let red = startRed + (endRed - startRed) * progress
        let green = startGreen + (endGreen - startGreen) * progress
        let blue = startBlue + (endBlue - startBlue) * progress
        let alpha = startAlpha + (endAlpha - startAlpha) * progress

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    private func updateNavigationBarAppearance(with theme: Theme, for viewController: UIViewController? = nil) {
        awfulNavigationBar.barTintColor = theme["navigationBarTintColor"]
        
        // iOS 26: Hide bottom border for liquid glass effect, earlier versions show themed border
        if #available(iOS 26.0, *) {
            awfulNavigationBar.bottomBorderColor = .clear
        } else {
            awfulNavigationBar.bottomBorderColor = theme["topBarBottomBorderColor"]
        }
        
        // iOS 26: Remove shadow for liquid glass effect, earlier versions use themed shadow
        if #available(iOS 26.0, *) {
            awfulNavigationBar.layer.shadowOpacity = 0
            awfulNavigationBar.layer.shadowColor = UIColor.clear.cgColor
        } else {
            awfulNavigationBar.layer.shadowOpacity = Float(theme[double: "navigationBarShadowOpacity"] ?? 1)
        }
        // Don't set tintColor here - will be set after appearance is applied

        // Apply theme's status bar setting
        if theme["statusBarBackground"] == "light" {
            statusBarEnterLightBackground()
        } else {
            statusBarEnterDarkBackground()
        }

        if #available(iOS 15.0, *) {
            // Fix odd grey navigation bar background when scrolled to top on iOS 15.
            // For iOS 26/Liquid Glass, we must configure ALL appearance modes

            if #available(iOS 26.0, *) {
                // iOS 26+: Set up initial appearance (will be dynamically updated on scroll)
                // Start with opaque appearance since most views start at top
                let initialAppearance = UINavigationBarAppearance()
                initialAppearance.configureWithOpaqueBackground()
                initialAppearance.backgroundColor = theme["navigationBarTintColor"]
                initialAppearance.shadowColor = nil
                initialAppearance.shadowImage = nil

                // Use theme colors for initial state
                let textColor: UIColor = theme["navigationBarTextColor"]!

                // Set back indicator in appearance (required for custom image to show)
                if let backImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate) {
                    initialAppearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
                }

                initialAppearance.titleTextAttributes = [
                    NSAttributedString.Key.foregroundColor: textColor,
                    NSAttributedString.Key.font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
                ]
                let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
                let buttonAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: textColor,
                    .font: buttonFont
                ]
                initialAppearance.buttonAppearance.normal.titleTextAttributes = buttonAttributes
                initialAppearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttributes
                initialAppearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttributes
                initialAppearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
                initialAppearance.backButtonAppearance.normal.titleTextAttributes = buttonAttributes
                initialAppearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttributes

                // Apply the initial appearance to all states
                awfulNavigationBar.standardAppearance = initialAppearance
                awfulNavigationBar.scrollEdgeAppearance = initialAppearance
                awfulNavigationBar.compactAppearance = initialAppearance
                awfulNavigationBar.compactScrollEdgeAppearance = initialAppearance

                // Set tintColor AFTER applying appearance to ensure it's not overridden
                awfulNavigationBar.tintColor = textColor
                print("DEBUG iOS26+: Set navigation bar tintColor to: \(textColor) for theme: \(theme["name"] ?? "unknown")")

                // Force navigation bar to update its appearance
                awfulNavigationBar.setNeedsLayout()
                awfulNavigationBar.layoutIfNeeded()

                // The appearance will be dynamically updated as the user scrolls
                // via updateNavigationBarBackgroundWithProgress

            } else {
                // iOS 15-25: Use single opaque appearance
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = theme["navigationBarTintColor"]
                appearance.shadowColor = nil
                appearance.shadowImage = nil

                // Set back indicator in appearance (required for custom image to show)
                if let backImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate) {
                    appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
                }

                // For iOS < 26, use explicit text color from theme
                let textColor: UIColor = theme["navigationBarTextColor"]!
                appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: textColor,
                                                 NSAttributedString.Key.font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)]

                // Ensure all text-based bar button items use the theme's font (rounded if enabled)
                let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
                let buttonAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: textColor,
                    .font: buttonFont
                ]
                appearance.buttonAppearance.normal.titleTextAttributes = buttonAttributes
                appearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttributes
                appearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttributes
                appearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
                appearance.backButtonAppearance.normal.titleTextAttributes = buttonAttributes
                appearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttributes

                // Apply the same appearance to all modes for iOS 15-25
                awfulNavigationBar.standardAppearance = appearance
                awfulNavigationBar.scrollEdgeAppearance = appearance
                awfulNavigationBar.compactAppearance = appearance
                awfulNavigationBar.compactScrollEdgeAppearance = appearance

                // Set tintColor AFTER applying appearance to ensure it's not overridden
                awfulNavigationBar.tintColor = textColor

                // Force navigation bar to update its appearance
                awfulNavigationBar.setNeedsLayout()
                awfulNavigationBar.layoutIfNeeded()
            }
        } else {
            // Fallback for earlier iOS versions: set UIBarButtonItem appearance globally
            let fallbackTextColor = theme[uicolor: "navigationBarTextColor"]!
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: fallbackTextColor,
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
            ]
            UIBarButtonItem.appearance().setTitleTextAttributes(attrs, for: .normal)
            UIBarButtonItem.appearance().setTitleTextAttributes(attrs, for: .highlighted)
            
            // Set the back indicator image for earlier iOS versions with proper tinting
            if let backImage = UIImage(named: "back") {
                let tintedBackImage = backImage.withRenderingMode(.alwaysTemplate)
                navigationBar.backIndicatorImage = tintedBackImage
                navigationBar.backIndicatorTransitionMaskImage = tintedBackImage
            }
        }
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(unpopHandler?.viewControllers, forKey: Key.FutureViewControllers.rawValue)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        if let viewControllers = coder.decodeObject(forKey: Key.FutureViewControllers.rawValue) as? [UIViewController] {
            unpopHandler?.viewControllers = viewControllers
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

private enum Key: String {
    case FutureViewControllers = "AwfulFutureViewControllers"
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
        // Get the appropriate theme for this view controller
        let vcTheme: Theme
        if let themeableViewController = viewController as? Themeable {
            vcTheme = themeableViewController.theme
            updateNavigationBarAppearance(with: vcTheme, for: viewController)
        } else {
            vcTheme = theme
            updateNavigationBarAppearance(with: vcTheme, for: viewController)
        }

        // Ensure the navigation bar has the back indicator set directly
        if awfulNavigationBar.backIndicatorImage == nil {
            awfulNavigationBar.backIndicatorImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
            awfulNavigationBar.backIndicatorTransitionMaskImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
        }

        // Only set theme colors when not scrolled (to preserve dynamic color when scrolled)
        if !isScrolledFromTop {
            let textColor: UIColor = vcTheme["navigationBarTextColor"]!

            // Set tintColor AFTER all appearance changes to ensure it's not overridden
            awfulNavigationBar.tintColor = textColor
            print("DEBUG willShow: Set navigation bar tintColor to: \(textColor) for VC: \(type(of: viewController)) theme: \(vcTheme["name"] ?? "unknown")")

            // Also set bar button item colors
            viewController.navigationItem.leftBarButtonItem?.tintColor = textColor
            viewController.navigationItem.rightBarButtonItem?.tintColor = textColor
            viewController.navigationItem.leftBarButtonItems?.forEach { $0.tintColor = textColor }
            viewController.navigationItem.rightBarButtonItems?.forEach { $0.tintColor = textColor }

            // Try setting the back button tint directly on the previous view controller
            if viewControllers.count > 1 {
                let previousVC = viewControllers[viewControllers.count - 2]
                previousVC.navigationItem.backBarButtonItem?.tintColor = textColor
            }
        }

        // Force navigation bar to update its appearance (critical for back button)
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

extension NavigationController: UIViewControllerRestoration {
    static func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        let nav = self.init()
        nav.restorationIdentifier = identifierComponents.last
        return nav
    }
}
