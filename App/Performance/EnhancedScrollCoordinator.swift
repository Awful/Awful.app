import UIKit
import WebKit
import SwiftUI

/// Enhanced scroll coordinator with CADisplayLink integration for 120fps performance
/// Replaces the basic UIScrollViewDelegate approach in WebViewCoordinator
final class EnhancedScrollCoordinator: NSObject, UIScrollViewDelegate, ObservableObject {
    
    // MARK: - Performance Components
    private let velocityTracker = VelocityTracker()
    private let displayLinkAnimator = DisplayLinkAnimator()
    private var displayLink: CADisplayLink?
    
    // MARK: - State
    private var lastUpdateTime: TimeInterval = 0
    private var isTrackingActive = false
    private weak var webView: WKWebView?
    
    // MARK: - Callbacks
    var onScrollChanged: ((Bool) -> Void)?
    var onScrollPositionChanged: ((CGFloat, CGFloat, CGFloat) -> Void)?
    var onVelocityChanged: ((CGFloat) -> Void)?
    
    // MARK: - Toolbar Animation Support
    @Published var toolbarOffset: CGFloat = 0
    @Published var toolbarVisible: Bool = true
    
    private let toolbarHeight: CGFloat = 44
    private let velocityThreshold: CGFloat = 25 // Reduced from 50 for more responsive UI
    
    override init() {
        super.init()
        setupDisplayLink()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup
    
    func attachToWebView(_ webView: WKWebView) {
        self.webView = webView
        // Set delegate AFTER webView is configured to avoid conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            webView.scrollView.delegate = self
        }
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkUpdate))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: 120,
            preferred: 120
        )
        displayLink?.isPaused = true
        displayLink?.add(to: .current, forMode: .common)
    }
    
    @objc private func displayLinkUpdate() {
        let currentTime = CACurrentMediaTime()
        
        // Throttle to display refresh rate (8.33ms for 120fps)
        guard currentTime - lastUpdateTime >= 0.0083 else { return }
        lastUpdateTime = currentTime
        
        // Process velocity and update toolbar if needed
        updateToolbarVisibility()
    }
    
    // MARK: - UIScrollViewDelegate (120fps Optimized)
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentOffset = scrollView.contentOffset.y
        
        // Add sample to velocity tracker
        velocityTracker.addSample(currentOffset)
        
        // Start display link if not already running
        if !isTrackingActive && velocityTracker.isActivelyScrolling {
            startActiveTracking()
        }
        
        // Basic scroll callbacks (lightweight)
        let velocity = velocityTracker.velocity
        onVelocityChanged?(velocity)
        
        // Position tracking
        let contentHeight = scrollView.contentSize.height
        let viewHeight = scrollView.bounds.height
        onScrollPositionChanged?(currentOffset, contentHeight, viewHeight)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            stopActiveTracking()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        stopActiveTracking()
    }
    
    // MARK: - Performance Tracking
    
    private func startActiveTracking() {
        guard !isTrackingActive else { return }
        isTrackingActive = true
        displayLink?.isPaused = false
    }
    
    private func stopActiveTracking() {
        isTrackingActive = false
        displayLink?.isPaused = true
        velocityTracker.reset()
        
        // Return toolbar to visible state when scrolling stops
        animateToolbarTo(visible: true, velocity: 0)
    }
    
    // MARK: - Toolbar Animation (120fps)
    
    private func updateToolbarVisibility() {
        let velocity = velocityTracker.smoothedVelocity
        let direction = velocityTracker.scrollDirection
        
        guard abs(velocity) > velocityThreshold else { return }
        
        let shouldHideToolbar: Bool
        switch direction {
        case .down:
            shouldHideToolbar = true
        case .up:
            shouldHideToolbar = false
        case .none:
            return
        }
        
        if shouldHideToolbar != !toolbarVisible {
            animateToolbarTo(visible: !shouldHideToolbar, velocity: velocity)
        }
        
        // Notify scroll direction change
        onScrollChanged?(direction == .up)
    }
    
    private func animateToolbarTo(visible: Bool, velocity: CGFloat) {
        toolbarVisible = visible
        let targetOffset = visible ? 0 : -toolbarHeight
        
        // Use DisplayLinkAnimator for smooth 120fps animation
        displayLinkAnimator.animateTo(targetOffset, velocity: velocity)
        
        // Update the published property when animation completes
        displayLinkAnimator.onAnimationComplete = { [weak self] in
            self?.toolbarOffset = targetOffset
        }
    }
    
    // MARK: - Public API
    
    /// Get current scroll performance metrics
    func getPerformanceMetrics() -> (velocity: CGFloat, direction: ScrollDirection, fps: Double) {
        let fps = displayLink?.duration ?? 0 > 0 ? 1 / (displayLink?.duration ?? 1) : 0
        return (
            velocity: velocityTracker.velocity,
            direction: velocityTracker.scrollDirection,
            fps: fps
        )
    }
    
    /// Force toolbar visibility state
    func setToolbarVisible(_ visible: Bool, animated: Bool = true) {
        if animated {
            animateToolbarTo(visible: visible, velocity: 0)
        } else {
            toolbarVisible = visible
            toolbarOffset = visible ? 0 : -toolbarHeight
            displayLinkAnimator.setValue(toolbarOffset)
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        displayLink?.invalidate()
        displayLink = nil
        webView?.scrollView.delegate = nil
    }
}

// MARK: - SwiftUI Integration

/// SwiftUI ViewModifier for enhanced scroll coordination
struct EnhancedScrollModifier: ViewModifier {
    @StateObject private var coordinator = EnhancedScrollCoordinator()
    @State private var webView: WKWebView?
    
    let onScrollChanged: ((Bool) -> Void)?
    let onScrollPositionChanged: ((CGFloat, CGFloat, CGFloat) -> Void)?
    
    func body(content: Content) -> some View {
        content
            .onReceive(coordinator.$toolbarOffset) { offset in
                // This allows SwiftUI views to respond to toolbar animations
            }
            .onAppear {
                setupCoordinator()
            }
    }
    
    private func setupCoordinator() {
        coordinator.onScrollChanged = onScrollChanged
        coordinator.onScrollPositionChanged = onScrollPositionChanged
        
        // Find and attach to WebView (this should be improved with proper dependency injection)
        if let webView = findWebView() {
            coordinator.attachToWebView(webView)
        }
    }
    
    private func findWebView() -> WKWebView? {
        // This is a simplified approach - in production, pass WebView reference properly
        return nil
    }
}

extension View {
    /// Apply enhanced scroll coordination with 120fps performance
    func enhancedScrollCoordination(
        onScrollChanged: ((Bool) -> Void)? = nil,
        onScrollPositionChanged: ((CGFloat, CGFloat, CGFloat) -> Void)? = nil
    ) -> some View {
        modifier(EnhancedScrollModifier(
            onScrollChanged: onScrollChanged,
            onScrollPositionChanged: onScrollPositionChanged
        ))
    }
}