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
    // MARK: - Batched UI State (Reduced @Published properties)
    @Published private(set) var uiState: UIState = UIState()
    
    struct UIState {
        var isTopBarVisible: Bool = true
        var isSubToolbarVisible: Bool = false
        var isBottomBarVisible: Bool = true
        var frogPullProgress: CGFloat = 0
        var isNearBottom: Bool = false
        var hasUserScrolled: Bool = false
        var topBarOffset: CGFloat = 0
        var bottomBarOffset: CGFloat = 0
    }
    
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
    
    // MARK: - Programmatic Scrolling State
    private var isProgrammaticScrolling: Bool = false
    private var programmaticScrollWorkItem: DispatchWorkItem?
    
    // MARK: - Smooth Animation State
    private var scrollVelocity: CGFloat = 0
    private var lastScrollUpdateTime: TimeInterval = 0
    private var smoothScrollDistance: CGFloat = 0
    private let maxToolbarOffset: CGFloat = 120 // Maximum distance toolbars can be offset
    private var isAnimatingToVisible: Bool = false
    
    // MARK: - Throttling
    private var uiUpdateWorkItem: DispatchWorkItem?
    private let uiUpdateDelay: TimeInterval = 0.033 // 30fps for UI updates
    
    // MARK: - Computed Properties
    var topInset: CGFloat {
        // No insets - toolbars are pure overlays
        0
    }
    
    var bottomInset: CGFloat {
        // No insets - toolbars are pure overlays
        0
    }
    
    // MARK: - Convenience Properties for Backward Compatibility
    var isTopBarVisible: Bool { uiState.isTopBarVisible }
    var isSubToolbarVisible: Bool { uiState.isSubToolbarVisible }
    var isBottomBarVisible: Bool { uiState.isBottomBarVisible }
    var frogPullProgress: CGFloat { uiState.frogPullProgress }
    var isNearBottom: Bool { uiState.isNearBottom }
    var hasUserScrolled: Bool { uiState.hasUserScrolled }
    var topBarOffset: CGFloat { uiState.topBarOffset }
    var bottomBarOffset: CGFloat { uiState.bottomBarOffset }
    
    // MARK: - Enums
    private enum ScrollDirection {
        case up, down, none
    }
    
    // MARK: - Scroll Handling
    func handleScrollChange(isScrollingUp: Bool) {
        let newDirection: ScrollDirection = isScrollingUp ? .up : .down
        
        // Ignore scroll events during programmatic scrolling
        guard !isProgrammaticScrolling else {
            return
        }
        
        // Mark that user has scrolled (batched update)
        if !uiState.hasUserScrolled {
            var newState = uiState
            newState.hasUserScrolled = true
            uiState = newState
        }
        
        // Only process if direction actually changed and we're in immersive mode
        guard newDirection != lastScrollDirection, isImmersiveMode else { 
            return 
        }
        
        // Increased threshold to reduce noise
        let minThreshold: CGFloat = 50.0 // Further increased from 40.0
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem) // Even longer debounce
    }
    
    func handleScrollPositionChanged(offset: CGFloat, contentHeight: CGFloat, viewHeight: CGFloat) {
        // Use immediate updates for critical calculations
        let scrollDelta = abs(offset - lastScrollPosition)
        if scrollDelta > 0 {
            accumulatedScrollDistance += scrollDelta
        }
        
        lastScrollPosition = offset
        scrollPosition = offset
        scrollContentHeight = contentHeight
        scrollViewHeight = viewHeight
        
        // Direct update for near bottom detection (no async dispatch)
        let bottomOffset = offset + viewHeight
        let newIsNearBottom = contentHeight > 0 && bottomOffset >= contentHeight - 200 // Increased threshold
        
        // Only update if changed to reduce UI rebuilds
        if newIsNearBottom != uiState.isNearBottom {
            var newState = uiState
            newState.isNearBottom = newIsNearBottom
            uiState = newState
        }
    }
    
    func handlePullChanged(fraction: CGFloat, isLastPage: Bool) {
        // Update last page state
        self.isLastPage = isLastPage
        
        // Only update frog progress if we're on the last page and near bottom
        if isLastPage && uiState.isNearBottom {
            let newProgress = min(fraction, 1.0)
            if abs(newProgress - uiState.frogPullProgress) > 0.1 { // Increased threshold to reduce updates
                var newState = uiState
                newState.frogPullProgress = newProgress
                uiState = newState
            }
        } else if uiState.frogPullProgress > 0 {
            var newState = uiState
            newState.frogPullProgress = 0
            uiState = newState
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
            var newState = uiState
            newState.topBarOffset = 0
            newState.bottomBarOffset = 0
            uiState = newState
        }
    }
    
    // MARK: - Programmatic Scrolling Control
    func beginProgrammaticScrolling() {
        isProgrammaticScrolling = true
        programmaticScrollWorkItem?.cancel()
        
        // Auto-reset after a reasonable delay to prevent getting stuck
        let workItem = DispatchWorkItem { [weak self] in
            self?.isProgrammaticScrolling = false
        }
        programmaticScrollWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem) // 5 second timeout to handle longer scroll operations
    }
    
    func endProgrammaticScrolling() {
        programmaticScrollWorkItem?.cancel()
        isProgrammaticScrolling = false
    }
    
    // MARK: - Private Methods
    private func updateToolbarVisibility(isScrollingUp: Bool) {
        // Only update in immersive mode - in normal mode bars are always visible
        guard isImmersiveMode else { return }
        
        // Batch all UI updates into a single state change
        var newState = uiState
        
        if isScrollingUp {
            // Scrolling up - show all bars
            newState.isTopBarVisible = true
            newState.isBottomBarVisible = true
            newState.isSubToolbarVisible = hasScrolledDown // Only show subtoolbar if user has scrolled down before
            newState.topBarOffset = 0
            newState.bottomBarOffset = 0
        } else {
            // Scrolling down - hide all bars
            hasScrolledDown = true
            newState.isTopBarVisible = false
            newState.isBottomBarVisible = false
            newState.isSubToolbarVisible = false
            newState.topBarOffset = -maxToolbarOffset
            newState.bottomBarOffset = maxToolbarOffset
        }
        
        // Single state update instead of multiple @Published changes
        uiState = newState
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
        uiUpdateWorkItem?.cancel()
        programmaticScrollWorkItem?.cancel()
        
        // Reset all UI state in a single batch update
        uiState = UIState()
        
        // Reset internal state
        hasScrolledDown = false
        lastScrollDirection = .none
        scrollVelocity = 0
        lastScrollUpdateTime = 0
        smoothScrollDistance = 0
        isAnimatingToVisible = false
        isProgrammaticScrolling = false
        
        scrollPosition = 0
        scrollContentHeight = 0
        scrollViewHeight = 0
        lastScrollPosition = 0
        accumulatedScrollDistance = 0
    }
}