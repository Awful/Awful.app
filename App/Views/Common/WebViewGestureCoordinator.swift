//  WebViewGestureCoordinator.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import UIKit
import WebKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "WebViewGestureCoordinator")

/// Coordinates gesture recognition between WebView content and navigation gestures
/// Implements research-proven patterns for resolving WebKit gesture conflicts
class WebViewGestureCoordinator: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?
    private let edgeThreshold: CGFloat = 30.0
    private let velocityThreshold: CGFloat = 500.0
    
    init(navigationController: UINavigationController? = nil) {
        self.navigationController = navigationController
        super.init()
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Critical: Only allow navigation gesture when WebView cannot go back
        if let webView = findWebView(in: gestureRecognizer.view) {
            let canNavigate = !webView.canGoBack
            logger.info("🌐 WebView gesture coordination - canGoBack: \(webView.canGoBack), allowing navigation: \(canNavigate)")
            return canNavigate
        }
        
        // For non-WebView gestures, allow by default
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow both gestures initially to prevent deadlock
        logger.info("🌐 Simultaneous gesture coordination: allowing both gestures")
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Navigation gestures should wait for WebView gestures to fail
        if gestureRecognizer is UIScreenEdgePanGestureRecognizer {
            let requiresFailure = otherGestureRecognizer.view is WKWebView
            if requiresFailure {
                logger.info("🌐 Navigation gesture requiring WebView gesture failure")
            }
            return requiresFailure
        }
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                          shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: gestureRecognizer.view)
        
        // For WebView scroll gestures, prevent interaction in edge zones
        if gestureRecognizer.view is UIScrollView,
           let webView = findWebView(in: gestureRecognizer.view) {
            
            let inEdgeZone = location.x <= edgeThreshold || 
                           location.x >= webView.bounds.width - edgeThreshold
            
            if inEdgeZone {
                logger.info("🌐 Preventing WebView scroll in edge zone at x: \(location.x)")
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Helper Methods
    
    private func findWebView(in view: UIView?) -> WKWebView? {
        guard let view = view else { return nil }
        
        if let webView = view as? WKWebView {
            return webView
        }
        
        // Search up the view hierarchy
        var currentView: UIView? = view
        while let parent = currentView?.superview {
            if let webView = parent as? WKWebView {
                return webView
            }
            currentView = parent
        }
        
        // Search down the view hierarchy
        for subview in view.subviews {
            if let webView = findWebViewInSubviews(subview) {
                return webView
            }
        }
        
        return nil
    }
    
    private func findWebViewInSubviews(_ view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        
        for subview in view.subviews {
            if let webView = findWebViewInSubviews(subview) {
                return webView
            }
        }
        
        return nil
    }
    
    private func isWebViewContainedGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        var currentView: UIView? = gestureRecognizer.view
        while currentView != nil {
            if currentView is WKWebView {
                return true
            }
            currentView = currentView?.superview
        }
        return false
    }
    
    private func isWebViewScrollGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Check if this is a scroll gesture from a WebView's scroll view
        if gestureRecognizer.view is UIScrollView {
            return isWebViewContainedGesture(gestureRecognizer)
        }
        return false
    }
}

/// Enhanced WebView that implements edge zone exclusion and navigation gesture coordination
class EdgePanAwareWebView: WKWebView, UIGestureRecognizerDelegate {
    private let edgeThreshold: CGFloat = 30.0
    private var gestureCoordinator: WebViewGestureCoordinator?
    private var dismissCallback: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Don't setup edge pan handling here - wait for didMoveToSuperview
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // Don't setup edge pan handling here - wait for didMoveToSuperview
    }
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        // Don't setup edge pan handling here - wait for didMoveToSuperview
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil && customEdgeGesture == nil {
            setupEdgePanHandling()
        }
    }
    
    private var customEdgeGesture: UIScreenEdgePanGestureRecognizer?
    
    private func setupEdgePanHandling() {
        // First, try to find the existing navigation edge gesture recognizer
        if let navigationController = findNavigationController() {
            gestureCoordinator = WebViewGestureCoordinator(navigationController: navigationController)
            
            // Look for existing edge gesture recognizer in the navigation controller's view
            if let navView = navigationController.view {
                for gestureRecognizer in navView.gestureRecognizers ?? [] {
                    if let edgeGesture = gestureRecognizer as? UIScreenEdgePanGestureRecognizer,
                       edgeGesture.edges.contains(.left) {
                        logger.info("🌐 Found existing navigation edge gesture recognizer")
                        // Set ourselves as delegate to intercept it
                        edgeGesture.delegate = self
                        customEdgeGesture = edgeGesture
                        logger.info("🌐 EdgePanAwareWebView hijacked existing UIScreenEdgePanGestureRecognizer")
                        return
                    }
                }
            }
        }
        
        // Fallback: Create our own if we can't find the navigation one
        let leftEdgeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgeGesture(_:)))
        leftEdgeGesture.edges = .left
        leftEdgeGesture.delegate = self
        
        // Search the view hierarchy for competing gestures
        var currentView: UIView? = self
        while currentView != nil {
            for otherGestureRecognizer in currentView?.gestureRecognizers ?? [] {
                if otherGestureRecognizer !== leftEdgeGesture {
                    if let edgeGesture = otherGestureRecognizer as? UIScreenEdgePanGestureRecognizer {
                        logger.info("🌐 Found competing UIScreenEdgePanGestureRecognizer: \(edgeGesture.edges.rawValue)")
                        // Don't make it wait, but log it
                    } else {
                        logger.info("🌐 Found other gesture: \(type(of: otherGestureRecognizer))")
                    }
                }
            }
            currentView = currentView?.superview
        }
        
        customEdgeGesture = leftEdgeGesture
        addGestureRecognizer(leftEdgeGesture)
        
        logger.info("🌐 EdgePanAwareWebView created new UIScreenEdgePanGestureRecognizer for left edge")
    }
    
    func setDismissCallback(_ callback: (() -> Void)?) {
        dismissCallback = callback
    }
    
    @objc private func handleEdgeGesture(_ gesture: UIScreenEdgePanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .began:
            logger.info("🌐 Screen edge gesture began from left edge")
            
        case .changed:
            logger.info("🌐 Screen edge gesture in progress: translation=\(translation.x), velocity=\(velocity.x)")
            
        case .ended:
            let hasSignificantVelocity = velocity.x > 100 // Further reduced threshold
            let hasSignificantDistance = translation.x > 10 // Further reduced threshold
            
            // Check if this should trigger navigation - simplified conditions without canGoBack check for now
            if hasSignificantVelocity && hasSignificantDistance {
                logger.info("🌐 Screen edge gesture completed - triggering navigation dismissal (velocity=\(velocity.x), distance=\(translation.x), canGoBack=\(self.canGoBack))")
                DispatchQueue.main.async {
                    self.dismissCallback?()
                }
            } else {
                logger.info("🌐 Screen edge gesture ended but conditions not met: velocity=\(velocity.x), distance=\(translation.x), canGoBack=\(self.canGoBack)")
            }
            
        case .cancelled, .failed:
            logger.info("🌐 Screen edge gesture cancelled or failed")
            
        default:
            break
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                          shouldReceive touch: UITouch) -> Bool {
        // For UIScreenEdgePanGestureRecognizer, let it handle edge detection automatically
        if gestureRecognizer === customEdgeGesture {
            let location = touch.location(in: self)
            logger.info("🌐 Screen edge gesture received touch at x: \(location.x), bounds.width: \(self.bounds.width)")
            logger.info("🌐 Gesture recognizer state: \(gestureRecognizer.state.rawValue), isEnabled: \(gestureRecognizer.isEnabled)")
            return true
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow simultaneous recognition but log for debugging
        if gestureRecognizer === customEdgeGesture {
            logger.info("🌐 Screen edge gesture simultaneous with: \(type(of: otherGestureRecognizer))")
        }
        return true
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === customEdgeGesture {
            logger.info("🌐 Screen edge gesture should begin - canGoBack: \(self.canGoBack), gesture type: \(type(of: gestureRecognizer))")
            // Always allow the gesture to begin for now, check canGoBack in the end handler
            return true
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                          shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // If this is the navigation edge gesture, make sure other gestures wait for it
        if gestureRecognizer === customEdgeGesture {
            logger.info("🌐 Other gesture should wait for edge gesture: \(type(of: otherGestureRecognizer))")
            return true
        }
        return false
    }
    
    private func findNavigationController() -> UINavigationController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let navigationController = responder as? UINavigationController {
                return navigationController
            }
            if let viewController = responder as? UIViewController {
                return viewController.navigationController
            }
            responder = responder?.next
        }
        return nil
    }
}

/// SwiftUI wrapper for EdgePanAwareWebView
struct EdgePanAwareWebViewRepresentable: UIViewRepresentable {
    let configuration: WKWebViewConfiguration
    @Binding var webView: WKWebView?
    
    init(configuration: WKWebViewConfiguration = WKWebViewConfiguration(), webView: Binding<WKWebView?> = .constant(nil)) {
        self.configuration = configuration
        self._webView = webView
    }
    
    func makeUIView(context: Context) -> EdgePanAwareWebView {
        let webView = EdgePanAwareWebView(frame: .zero, configuration: configuration)
        
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: EdgePanAwareWebView, context: Context) {
        // Updates handled by binding
    }
}