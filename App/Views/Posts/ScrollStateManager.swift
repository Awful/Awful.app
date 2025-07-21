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
    private var lastScrollPosition: CGFloat = 0
    
    // MARK: - Programmatic Scrolling State
    private var isProgrammaticScrolling: Bool = false
    private var programmaticScrollWorkItem: DispatchWorkItem?
    
    // MARK: - Smooth Animation State
    private var scrollVelocity: CGFloat = 0
    private var lastScrollUpdateTime: TimeInterval = 0
    private var smoothScrollDistance: CGFloat = 0
    private let maxToolbarOffset: CGFloat = 120 // Maximum distance toolbars can be offset
    private var isAnimatingToVisible: Bool = false
    
    // MARK: - Throttling - removed for direct scroll mapping
    
    // MARK: - Computed Properties
    var topInset: CGFloat {
        // In immersive mode, provide inset for top navigation bar + safe area
        // This ensures first post is visible below the navigation bar
        if isImmersiveMode {
            // Navigation bar height (44) + safe area (varies by device) + padding
            return 44 // Minimal inset to just clear navigation bar
        }
        return 0
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
        // Ignore scroll events during programmatic scrolling
        guard !isProgrammaticScrolling, isImmersiveMode else {
            return
        }
        
        // Mark that user has scrolled
        if !uiState.hasUserScrolled {
            var newState = uiState
            newState.hasUserScrolled = true
            uiState = newState
        }
    }
    
    func handleScrollPositionChanged(offset: CGFloat, contentHeight: CGFloat, viewHeight: CGFloat) {
        let scrollDelta = offset - lastScrollPosition
        lastScrollPosition = offset
        scrollPosition = offset
        scrollContentHeight = contentHeight
        scrollViewHeight = viewHeight
        
        // Update near bottom detection
        let bottomOffset = offset + viewHeight
        let newIsNearBottom = contentHeight > 0 && bottomOffset >= contentHeight - 200
        
        var newState = uiState
        if newIsNearBottom != uiState.isNearBottom {
            newState.isNearBottom = newIsNearBottom
        }
        
        // In immersive mode, directly map scroll movement to toolbar offsets
        if isImmersiveMode && !isProgrammaticScrolling && abs(scrollDelta) > 2 {
            // Simple 1:1 mapping: scroll down = hide toolbars, scroll up = show toolbars
            let newTopOffset = max(-maxToolbarOffset, min(0, uiState.topBarOffset - scrollDelta))
            let newBottomOffset = max(0, min(maxToolbarOffset, uiState.bottomBarOffset + scrollDelta))
            
            newState.topBarOffset = newTopOffset
            newState.bottomBarOffset = newBottomOffset
            
            // Update visibility flags based on offsets
            newState.isTopBarVisible = newTopOffset > -maxToolbarOffset * 0.9
            newState.isBottomBarVisible = newBottomOffset < maxToolbarOffset * 0.9
            newState.isSubToolbarVisible = newState.isTopBarVisible && uiState.hasUserScrolled
        }
        
        uiState = newState
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
    // Toolbar visibility is now handled directly in handleScrollPositionChanged
    
    
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
    
    // MARK: - Toolbar Management
    func showToolbarsOnPageLoad() {
        // Show all toolbars when a new page loads
        // Hide subtoolbar to prevent it from showing after navigation
        var newState = uiState
        newState.isTopBarVisible = true
        newState.isBottomBarVisible = true
        newState.isSubToolbarVisible = false // Hide subtoolbar on navigation
        newState.topBarOffset = 0
        newState.bottomBarOffset = 0
        uiState = newState
    }
    
    // MARK: - Reset
    func reset() {
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
    }
}