//  NavigationStateManager.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NavigationStateManager")

/// Manages navigation state to prevent automatic restoration after user actions
/// Based on research-proven patterns for SwiftUI NavigationStack coordination
@MainActor
class NavigationGestureStateManager: ObservableObject {
    @Published private(set) var suppressRestorationUntil: Date = .distantPast
    
    private let restorationCooldownDuration: TimeInterval = 3.0  // Shorter cooldown since we're more intelligent now
    
    /// Records a user-initiated navigation action to prevent automatic restoration
    func recordUserNavigationAction(withVelocity velocity: CGPoint = .zero) {
        // Adaptive suppression timing based on gesture confidence
        let velocityConfidence = min(abs(velocity.x) / 1000.0, 1.0) // Normalize velocity (0-1)
        let confidenceMultiplier = velocityConfidence > 0.5 ? 1.5 : 1.0 // Boost for high-confidence gestures
        let adaptiveSuppressionDuration = restorationCooldownDuration * confidenceMultiplier
        
        self.suppressRestorationUntil = Date().addingTimeInterval(adaptiveSuppressionDuration)
        logger.info("🧭 User navigation action recorded (velocity: \(velocity.x), confidence: \(velocityConfidence), duration: \(adaptiveSuppressionDuration)s) - suppressing restoration until \(self.suppressRestorationUntil)")
        
        // Also clear any SwiftUI internal restoration data by posting notification
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("UserNavigationActionDetected"), object: nil)
            
            // DISABLED: Force-clear always causes overshoot - relying purely on intelligent detection
            // DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            //     NotificationCenter.default.post(name: Notification.Name("ForceClearNavigationStack"), object: nil)
            // }
        }
    }
    
    /// Checks if restoration should be suppressed based on recent user actions
    var shouldSuppressRestoration: Bool {
        let now = Date()
        let shouldSuppress = now < self.suppressRestorationUntil
        let timeRemaining = self.suppressRestorationUntil.timeIntervalSince(now)
        
        if shouldSuppress {
            logger.info("🧭 Suppressing restoration due to recent user action - \(timeRemaining)s remaining")
        } else {
            logger.info("🧭 No suppression needed - \(abs(timeRemaining))s since last user action")
        }
        return shouldSuppress
    }
    
    /// Clears the suppression state (typically used when restoration is desired)
    func clearSuppressionState() {
        self.suppressRestorationUntil = .distantPast
        logger.info("🧭 Restoration suppression cleared")
    }
}
