//  NavigationController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import Combine
import UIKit

/**
 Navigation controller with special powers:

 - Theming support.
 - Shows and hides the toolbar depending on whether the view controller has toolbar items.
 - On iPhone, allows swiping from the *right* screen edge to unpop a view controller.
 */
final class NavigationController: UINavigationController, Themeable {
    private var cancellables: Set<AnyCancellable> = []
    fileprivate weak var realDelegate: UINavigationControllerDelegate?
    fileprivate lazy var unpopHandler: UnpoppingViewHandler? = {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return nil }
        return UnpoppingViewHandler(navigationController: self)
    }()
    fileprivate var pushAnimationInProgress = false
    @FoilDefaultStorage(Settings.darkMode) private var darkMode
    var hidesNavigationBar: Bool = false
    
    // We cannot override the designated initializer, -initWithNibName:bundle:, and call -initWithNavigationBarClass:toolbarClass: within. So we override what we can, and handle our own restoration, to ensure our toolbar class is used.
    
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }
    
    required init() {
        super.init(navigationBarClass: nil, toolbarClass: Toolbar.self)
        delegate = self

        $darkMode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Awful a little too fast for its own good; let the system finish its transition first.
                DispatchQueue.main.async {
                    self?.themeDidChange()
                }
            }
            .store(in: &cancellables)
    }
    
    override convenience init(rootViewController: UIViewController) {
        self.init()
        viewControllers = [rootViewController]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var awfulNavigationBar: UINavigationBar {
        return navigationBar
    }

    var theme: Theme {
        return Theme.defaultTheme()
    }
    
    // MARK: set the status icons (clock, wifi, battery) to black or white depending on the mode of the theme
    // thanks sarunw https://sarunw.com/posts/how-to-set-status-bar-style/
    var isDarkContentBackground = false

    func statusBarEnterLightBackground() {
        isDarkContentBackground = false
        setNeedsStatusBarAppearanceUpdate()
    }

    func statusBarEnterDarkBackground() {
        isDarkContentBackground = true
        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
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
        
        // Remove "Back" text by setting empty title on the back button
        let backButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        topViewController?.navigationItem.backBarButtonItem = backButtonItem
        
        super.pushViewController(viewController, animated: animated)
        
        unpopHandler?.navigationController(self, didPushViewController: viewController)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = theme["navigationBarTintColor"]
        
        themeDidChange()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNavigationBarHidden(hidesNavigationBar, animated: animated)
        
        // Ensure theming is applied when navigation bar becomes visible
        if !hidesNavigationBar {
            themeDidChange()
        }
    }
    
    func themeDidChange() {
        awfulNavigationBar.barTintColor = theme["navigationBarTintColor"]
        awfulNavigationBar.layer.shadowOpacity = Float(theme[double: "navigationBarShadowOpacity"] ?? 1)
        awfulNavigationBar.tintColor = theme["navigationBarTextColor"]

        if theme["statusBarBackground"] == "light" {
            statusBarEnterLightBackground()
            awfulNavigationBar.barStyle = .default
        } else {
            statusBarEnterDarkBackground()
            awfulNavigationBar.barStyle = .black
        }

        // Fix odd grey navigation bar background when scrolled to top on iOS 15.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = theme["navigationBarTintColor"]
        
        // Set custom back indicator image to use arrowleft icon
        if let backButtonImage = UIImage(named: "arrowleft") {
            appearance.setBackIndicatorImage(backButtonImage, transitionMaskImage: backButtonImage)
        }
        
        // Also set the back indicator on the navigation bar directly for immediate effect
        if let backButtonImage = UIImage(named: "arrowleft") {
            navigationBar.backIndicatorImage = backButtonImage
            navigationBar.backIndicatorTransitionMaskImage = backButtonImage
        }
        
        let textColor: UIColor? = theme["navigationBarTextColor"]
        
        let useRoundedFonts = theme[bool: "roundedFonts"] ?? false
        let sizeAdjustment = theme[double: "navigationBarTitleFontSizeAdjustment"] ?? 0
        let font = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: sizeAdjustment, weight: .semibold, useRoundedFonts: useRoundedFonts)

        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: textColor!,
                                          NSAttributedString.Key.font: font]

        navigationBar.standardAppearance = appearance;
        navigationBar.scrollEdgeAppearance = navigationBar.standardAppearance
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
    
    // MARK: Fallback back button
    
    @objc private func didTapFallbackBackButton() {
        // Try to pop if we have multiple view controllers in the stack
        if viewControllers.count > 1 {
            popViewController(animated: true)
        } else if presentingViewController != nil {
            // If we're in a modal presentation and can't pop, dismiss
            dismiss(animated: true, completion: nil)
        } else {
            // As a last resort, try to find a split view controller and navigate to the primary pane
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let splitVC = UIViewController.findSplitViewController(in: window.rootViewController) {
                splitVC.showPrimaryViewController()
            }
        }
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
        if let unpopHandler = unpopHandler, animated {
            unpopHandler.navigationControllerDidBeginAnimating()
            
            transitionCoordinator?.notifyWhenInteractionChanges { context in
                guard context.isCancelled else { return }
                if unpopHandler.interactiveUnpopIsTakingPlace {
                    unpopHandler.navigationControllerDidCancelInteractiveUnpop()
                } else {
                    unpopHandler.navigationControllerDidCancelInteractivePop()
                }
            }
        }
        
        // Ensure navigation bar appearance is current when showing a view controller
        if !hidesNavigationBar {
            themeDidChange()
        }
        
        // Add fallback back button if none exists and it's not the root view controller
        if viewController.navigationItem.leftBarButtonItem == nil &&
           viewController.navigationItem.hidesBackButton == false &&
           navigationController.viewControllers.count > 1 {
            let backButton = UIBarButtonItem(
                image: UIImage(named: "arrowleft"),
                style: .plain,
                target: self,
                action: #selector(didTapFallbackBackButton)
            )
            backButton.tintColor = theme["navigationBarTextColor"]
            viewController.navigationItem.leftBarButtonItem = backButton
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
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if let unpopHandler = unpopHandler, unpopHandler.shouldHandleAnimatingTransitionForOperation(operation) {
            return unpopHandler
        }
        return realDelegate?.navigationController?(navigationController, animationControllerFor: operation, from: fromVC, to: toVC)
    }
    
    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if let unpopHandler = unpopHandler, unpopHandler.interactiveUnpopIsTakingPlace {
            return unpopHandler
        }
        return realDelegate?.navigationController?(navigationController, interactionControllerFor: animationController)
    }
}
