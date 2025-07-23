import UIKit
import SwiftUI

/// High-performance 120fps animator using CADisplayLink for smooth toolbar animations
/// Optimized for ProMotion displays with velocity-based easing curves
final class DisplayLinkAnimator: ObservableObject {
    private var displayLink: CADisplayLink?
    private var animationStartTime: TimeInterval = 0
    private var animationDuration: TimeInterval = 0.3
    private var startValue: CGFloat = 0
    private var targetValue: CGFloat = 0
    private var currentValue: CGFloat = 0
    private var velocity: CGFloat = 0
    private var isAnimating = false
    
    @Published var animatedValue: CGFloat = 0
    
    /// Completion handler called when animation finishes
    var onAnimationComplete: (() -> Void)?
    
    init() {
        setupDisplayLink()
    }
    
    deinit {
        stopAnimation()
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: 120,
            preferred: 120
        )
        displayLink?.isPaused = true
        displayLink?.add(to: .current, forMode: .common)
    }
    
    /// Animate to target value with velocity-based timing
    /// - Parameters:
    ///   - target: Target value to animate towards
    ///   - velocity: Current scroll velocity (affects animation curve)
    ///   - duration: Animation duration (adaptive based on velocity)
    func animateTo(_ target: CGFloat, velocity: CGFloat = 0, duration: TimeInterval? = nil) {
        guard abs(target - currentValue) > 0.1 else { return }
        
        self.velocity = velocity
        startValue = currentValue
        targetValue = target
        
        // Adaptive duration based on velocity and distance
        if let customDuration = duration {
            animationDuration = customDuration
        } else {
            let distance = abs(target - currentValue)
            let velocityFactor = min(abs(velocity) / 1000, 1.0) // Normalize velocity
            animationDuration = 0.2 + (0.3 * velocityFactor) + (distance / 200 * 0.1)
            animationDuration = min(animationDuration, 0.6) // Cap max duration
        }
        
        animationStartTime = CACurrentMediaTime()
        isAnimating = true
        displayLink?.isPaused = false
    }
    
    /// Stop current animation at current position
    func stopAnimation() {
        isAnimating = false
        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
    }
    
    /// Immediately set value without animation
    func setValue(_ value: CGFloat) {
        currentValue = value
        animatedValue = value
        if isAnimating {
            isAnimating = false
            displayLink?.isPaused = true
        }
    }
    
    @objc private func displayLinkFired() {
        guard isAnimating else {
            displayLink?.isPaused = true
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - animationStartTime
        let progress = min(elapsed / animationDuration, 1.0)
        
        if progress >= 1.0 {
            // Animation complete
            currentValue = targetValue
            animatedValue = targetValue
            isAnimating = false
            displayLink?.isPaused = true
            onAnimationComplete?()
        } else {
            // Apply velocity-influenced easing curve
            let easedProgress = velocityInfluencedEasing(progress, velocity: velocity)
            currentValue = startValue + (targetValue - startValue) * easedProgress
            animatedValue = currentValue
        }
    }
    
    /// Custom easing function that considers scroll velocity for natural motion
    private func velocityInfluencedEasing(_ t: CGFloat, velocity: CGFloat) -> CGFloat {
        let absVelocity = abs(velocity)
        
        if absVelocity < 100 {
            // Low velocity: smooth ease-out
            return easeOut(t)
        } else if absVelocity < 500 {
            // Medium velocity: spring-like motion
            return easeOutSpring(t)
        } else {
            // High velocity: more aggressive easing
            return easeOutQuart(t)
        }
    }
    
    private func easeOut(_ t: CGFloat) -> CGFloat {
        return 1 - pow(1 - t, 3)
    }
    
    private func easeOutSpring(_ t: CGFloat) -> CGFloat {
        let c4 = (2 * CGFloat.pi) / 3
        return t == 0 ? 0 : t == 1 ? 1 : pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1
    }
    
    private func easeOutQuart(_ t: CGFloat) -> CGFloat {
        return 1 - pow(1 - t, 4)
    }
}

/// SwiftUI ViewModifier for animated toolbar positioning
struct AnimatedToolbarModifier: ViewModifier {
    @StateObject private var animator = DisplayLinkAnimator()
    let targetOffset: CGFloat
    let velocity: CGFloat
    
    func body(content: Content) -> some View {
        content
            .offset(y: animator.animatedValue)
            .onAppear {
                animator.setValue(targetOffset)
            }
            .onChange(of: targetOffset) { newTarget in
                animator.animateTo(newTarget, velocity: velocity)
            }
    }
}

extension View {
    /// Apply high-performance 120fps toolbar animation
    func animatedToolbarOffset(_ offset: CGFloat, velocity: CGFloat = 0) -> some View {
        modifier(AnimatedToolbarModifier(targetOffset: offset, velocity: velocity))
    }
}