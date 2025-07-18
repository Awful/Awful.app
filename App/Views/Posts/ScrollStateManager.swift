//  ScrollStateManager.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import SwiftUI
import Combine
import QuartzCore

/// Centralized state manager for scroll-related UI updates
/// Reduces the number of @State variables and provides throttling for smooth performance
class ScrollStateManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isTopBarVisible: Bool = true
    @Published private(set) var isSubToolbarVisible: Bool = false
    @Published private(set) var isBottomBarVisible: Bool = true
    @Published private(set) var frogPullProgress: CGFloat = 0
    @Published private(set) var isNearBottom: Bool = false
    @Published private(set) var hasUserScrolled: Bool = false
    
    // MARK: - Smooth Animation Properties
    @Published private(set) var topBarOffset: CGFloat = 0
    @Published private(set) var bottomBarOffset: CGFloat = 0
    
    // MARK: - Internal State
    private var isLastPage: Bool = false
    private var isImmersiveMode: Bool = false
    private var scrollPosition: CGFloat = 0
    private var scrollContentHeight: CGFloat = 0
    private var scrollViewHeight: CGFloat = 0
    private var hasScrolledDown: Bool = false
    private var lastScrollDirection: ScrollDirection = .none
    private var scrollDirectionChangeThreshold: CGFloat = 5.0 // Much lower threshold for smoother following
    private var lastScrollPosition: CGFloat = 0
    private var accumulatedScrollDistance: CGFloat = 0
    private var bounceSuppressionThreshold: CGFloat = 20.0 // Reduced for better responsiveness
    
    // MARK: - Smooth Animation State
    private var scrollVelocity: CGFloat = 0
    private var lastScrollUpdateTime: TimeInterval = 0
    private var smoothScrollDistance: CGFloat = 0
    private let maxToolbarOffset: CGFloat = 120 // Maximum distance toolbars can be offset
    private var isAnimatingToVisible: Bool = false
    
    // MARK: - Throttling
    private var scrollThrottleWorkItem: DispatchWorkItem?
    private var uiUpdateWorkItem: DispatchWorkItem?
    private let scrollThrottleDelay: TimeInterval = 0.008 // ~120fps for smoother performance
    private let uiUpdateDelay: TimeInterval = 0.016 // 60fps for responsive UI updates
    
    // MARK: - Computed Properties
    var topInset: CGFloat {
        // No insets - toolbars are pure overlays
        0
    }
    
    var bottomInset: CGFloat {
        // No insets - toolbars are pure overlays
        0
    }
    
    // MARK: - Enums
    private enum ScrollDirection {
        case up, down, none
    }
    
    // MARK: - Scroll Handling
    func handleScrollChange(isScrollingUp: Bool) {
        let newDirection: ScrollDirection = isScrollingUp ? .up : .down
        
        // Mark that user has scrolled
        if !hasUserScrolled {
            hasUserScrolled = true
        }
        
        // Only process if direction actually changed and we're in immersive mode
        guard newDirection != lastScrollDirection, isImmersiveMode else { 
            return 
        }
        
        // Require minimum accumulated distance for direction changes to prevent oscillation
        let minThreshold: CGFloat = 25.0 // Increased threshold to prevent rapid changes
        if lastScrollDirection != .none && accumulatedScrollDistance < minThreshold {
            return
        }
        
        lastScrollDirection = newDirection
        accumulatedScrollDistance = 0 // Reset after processing
        
        // Cancel previous UI update
        uiUpdateWorkItem?.cancel()
        
        // Schedule new UI update with longer debouncing to prevent rapid state changes
        let workItem = DispatchWorkItem { [weak self] in
            self?.updateToolbarVisibility(isScrollingUp: isScrollingUp)
        }
        uiUpdateWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem) // Increased delay
    }
    
    func handleScrollPositionChanged(offset: CGFloat, contentHeight: CGFloat, viewHeight: CGFloat) {
        // Cancel previous throttled update
        scrollThrottleWorkItem?.cancel()
        
        // Schedule new throttled update
        let workItem = DispatchWorkItem { [weak self] in
            self?.updateScrollPosition(offset: offset, contentHeight: contentHeight, viewHeight: viewHeight)
        }
        scrollThrottleWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + scrollThrottleDelay, execute: workItem)
    }
    
    func handlePullChanged(fraction: CGFloat, isLastPage: Bool) {
        // Update last page state
        self.isLastPage = isLastPage
        
        // Only update frog progress if we're on the last page and near bottom
        if isLastPage && isNearBottom {
            let newProgress = min(fraction, 1.0)
            if abs(newProgress - frogPullProgress) > 0.05 { // Threshold to reduce updates
                frogPullProgress = newProgress
            }
        } else if frogPullProgress > 0 {
            frogPullProgress = 0
        }
    }
    
    func setIsLastPage(_ isLastPage: Bool) {
        self.isLastPage = isLastPage
    }
    
    func setIsImmersiveMode(_ isImmersiveMode: Bool) {
        self.isImmersiveMode = isImmersiveMode
        
        // Initialize offsets when immersive mode is set
        if isImmersiveMode {
            // Start with toolbars visible
            topBarOffset = 0
            bottomBarOffset = 0
        }
    }
    
    // MARK: - Private Methods
    private func updateToolbarVisibility(isScrollingUp: Bool) {
        // Only update in immersive mode - in normal mode bars are always visible
        guard isImmersiveMode else { return }
        
        if isScrollingUp {
            // Scrolling up - show all bars
            isTopBarVisible = true
            isBottomBarVisible = true
            isSubToolbarVisible = hasScrolledDown // Only show subtoolbar if user has scrolled down before
            topBarOffset = 0
            bottomBarOffset = 0
        } else {
            // Scrolling down - hide all bars
            hasScrolledDown = true
            isTopBarVisible = false
            isBottomBarVisible = false
            isSubToolbarVisible = false
            topBarOffset = -maxToolbarOffset
            bottomBarOffset = maxToolbarOffset
        }
    }
    
    private func updateScrollPosition(offset: CGFloat, contentHeight: CGFloat, viewHeight: CGFloat) {
        // Calculate scroll distance for hysteresis
        let scrollDelta = abs(offset - lastScrollPosition)
        if scrollDelta > 0 {
            accumulatedScrollDistance += scrollDelta
        }
        
        lastScrollPosition = offset
        scrollPosition = offset
        scrollContentHeight = contentHeight
        scrollViewHeight = viewHeight
        
        // Check if we're near the bottom with more generous threshold
        let bottomOffset = offset + viewHeight
        let newIsNearBottom = contentHeight > 0 && bottomOffset >= contentHeight - 150
        
        // Only update if changed to reduce published events
        if newIsNearBottom != isNearBottom {
            isNearBottom = newIsNearBottom
        }
    }
    
    // MARK: - Smooth Toolbar Animation
    private func updateToolbarOffsets() {
        // Removed complex smooth animation logic - using simple visibility states instead
        // The UI will handle animations through SwiftUI's animation system
    }
    
    // MARK: - Frog Animation Helpers
    func calculateFrogOffset() -> CGFloat {
        // Simple approach: position frog below the viewport with minimal offset
        guard isNearBottom else { return 50 } // Hide below view when not near bottom
        
        let totalContentHeight = scrollContentHeight
        let viewHeight = scrollViewHeight
        let currentOffset = scrollPosition
        
        // Calculate overscroll for bounce effect
        let viewBottom = currentOffset + viewHeight
        let overscroll = max(0, viewBottom - totalContentHeight)
        
        // Small bounce effect when overscrolling
        let bounceOffset = min(overscroll * 0.3, 20)
        
        // Position just below the visible content with bounce
        return -20 + bounceOffset // Start 20pt below view, bounce up during overscroll
    }
    
    // MARK: - Reset
    func reset() {
        scrollThrottleWorkItem?.cancel()
        uiUpdateWorkItem?.cancel()
        
        isTopBarVisible = true
        isSubToolbarVisible = false
        isBottomBarVisible = true
        frogPullProgress = 0
        isNearBottom = false
        hasScrolledDown = false
        hasUserScrolled = false
        lastScrollDirection = .none
        
        // Reset smooth animation properties
        topBarOffset = 0
        bottomBarOffset = 0
        scrollVelocity = 0
        lastScrollUpdateTime = 0
        smoothScrollDistance = 0
        isAnimatingToVisible = false
        
        scrollPosition = 0
        scrollContentHeight = 0
        scrollViewHeight = 0
        lastScrollPosition = 0
        accumulatedScrollDistance = 0
    }
}