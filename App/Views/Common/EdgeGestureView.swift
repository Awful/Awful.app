//  EdgeGestureView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "EdgeGestureView")

/// iOS 17 compatible UIViewRepresentable wrapper for edge gestures
/// Based on research-proven patterns for SwiftUI NavigationStack coordination
public struct EdgeGestureView: UIViewRepresentable {
    let onEdgeSwipe: (CGPoint) -> Void  // Now includes velocity
    let onDragProgress: ((CGFloat) -> Void)?
    
    // Convenience initializer for backward compatibility
    public init(onEdgeSwipe: @escaping () -> Void, onDragProgress: ((CGFloat) -> Void)? = nil) {
        self.onEdgeSwipe = { _ in onEdgeSwipe() }  // Ignore velocity
        self.onDragProgress = onDragProgress
    }
    
    // New initializer with velocity support
    public init(onEdgeSwipe: @escaping (CGPoint) -> Void, onDragProgress: ((CGFloat) -> Void)? = nil) {
        self.onEdgeSwipe = onEdgeSwipe
        self.onDragProgress = onDragProgress
    }
    
    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = true
        
        // Use regular UIPanGestureRecognizer instead of UIScreenEdgePanGestureRecognizer
        // to avoid SwiftUI navigation gesture conflicts
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator, 
            action: #selector(context.coordinator.handleEdgeSwipe)
        )
        panGesture.delegate = context.coordinator
        view.addGestureRecognizer(panGesture)
        
        logger.info("📱 EdgeGestureView created with UIPanGestureRecognizer (edge detection in handler)")
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let parent: EdgeGestureView
        
        public init(_ parent: EdgeGestureView) {
            self.parent = parent
        }
        
        @objc func handleEdgeSwipe(_ recognizer: UIPanGestureRecognizer) {
            let location = recognizer.location(in: recognizer.view)
            let translation = recognizer.translation(in: recognizer.view)
            let velocity = recognizer.velocity(in: recognizer.view)
            
            // Only process edge gestures - much stricter edge detection
            let edgeThreshold: CGFloat = 20  // Much smaller edge area
            let startLocation = recognizer.location(in: recognizer.view)
            
            // For .began state, must start within edge threshold and be moving right
            if recognizer.state == .began {
                let isFromEdge = startLocation.x <= edgeThreshold
                if !isFromEdge {
                    // Not from edge, ignore this gesture entirely
                    recognizer.state = .cancelled
                    return
                }
                logger.info("📱 Edge gesture began from x: \(startLocation.x)")
            }
            
            // For other states, only continue if translation is positive (rightward)
            if recognizer.state != .began && translation.x <= 0 {
                return
            }
            
            switch recognizer.state {
            case .began:
                logger.info("📱 Edge gesture began from x: \(location.x)")
                // Start interactive feedback
                DispatchQueue.main.async {
                    self.parent.onDragProgress?(0.0)
                }
                
            case .changed:
                logger.info("📱 Edge gesture changed: translation=\(translation.x), velocity=\(velocity.x)")
                
                // Calculate progress (0.0 to 1.0) based on translation
                // UIKit typically considers 40% of screen width as completion threshold
                let screenWidth = recognizer.view?.bounds.width ?? 375
                let progress = min(max(translation.x / (screenWidth * 0.4), 0.0), 1.0)
                
                // Provide interactive feedback
                DispatchQueue.main.async {
                    self.parent.onDragProgress?(progress)
                }
                
            case .ended:
                let screenWidth = recognizer.view?.bounds.width ?? 375
                let progress = translation.x / (screenWidth * 0.4)
                let hasSignificantVelocity = velocity.x > 300  // Higher threshold for velocity
                let hasSignificantDistance = translation.x > 50  // Reasonable distance threshold
                let hasSignificantProgress = progress > 0.5     // UIKit-like 50% rule
                
                let shouldComplete = hasSignificantVelocity || (hasSignificantDistance && hasSignificantProgress)
                
                if shouldComplete {
                    logger.info("📱 Edge gesture completed - triggering navigation dismissal (progress: \(progress), velocity: \(velocity.x))")
                    DispatchQueue.main.async {
                        self.parent.onDragProgress?(1.0) // Complete the animation
                        // Small delay to let visual feedback complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Pass velocity information to callback
                            self.parent.onEdgeSwipe(velocity)
                        }
                    }
                } else {
                    logger.info("📱 Edge gesture cancelled - snapping back (progress: \(progress), velocity: \(velocity.x))")
                    // Animate back to 0
                    DispatchQueue.main.async {
                        self.parent.onDragProgress?(0.0)
                    }
                }
                
            case .cancelled, .failed:
                logger.info("📱 Edge gesture cancelled or failed - snapping back")
                DispatchQueue.main.async {
                    self.parent.onDragProgress?(0.0)
                }
                
            case .possible:
                logger.info("📱 Edge gesture in .possible state")
                
            default:
                break
            }
        }
        
        // Only allow simultaneous recognition with non-scroll gestures
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                              shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Don't interfere with WebView scrolling
            let allowSimultaneous = !(otherGestureRecognizer.view is UIScrollView)
            logger.info("📱 Simultaneous gesture with \(type(of: otherGestureRecognizer)): \(allowSimultaneous)")
            return allowSimultaneous
        }
        
        public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // Only begin if touch is truly at the edge
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let location = panGesture.location(in: panGesture.view)
            let isAtEdge = location.x <= 20  // Very strict edge detection
            logger.info("📱 Edge gesture should begin check: x=\(location.x), isAtEdge=\(isAtEdge)")
            return isAtEdge
        }
        
        // Only require scroll views to wait, not all gestures
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                              shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Don't interfere with WebView scrolling - only require failure for navigation gestures
            let shouldWait = otherGestureRecognizer.view is UIScrollView
            if !shouldWait {
                logger.info("📱 Allowing \(type(of: otherGestureRecognizer)) to proceed without waiting")
            }
            return false  // Don't force other gestures to wait
        }
        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            let location = touch.location(in: gestureRecognizer.view)
            let shouldReceive = location.x <= 20  // Only receive touches at the very edge
            logger.info("📱 Edge gesture received touch at x: \(location.x), shouldReceive: \(shouldReceive)")
            return shouldReceive
        }
    }
}
