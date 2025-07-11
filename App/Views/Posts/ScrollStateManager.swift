//  ScrollStateManager.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import SwiftUI
import Combine

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
    
    // MARK: - Internal State
    private var scrollPosition: CGFloat = 0
    private var scrollContentHeight: CGFloat = 0
    private var scrollViewHeight: CGFloat = 0
    private var hasScrolledDown: Bool = false
    private var lastScrollDirection: ScrollDirection = .none
    
    // MARK: - Throttling
    private var scrollThrottleWorkItem: DispatchWorkItem?
    private var uiUpdateWorkItem: DispatchWorkItem?
    private let scrollThrottleDelay: TimeInterval = 0.016 // ~60fps
    private let uiUpdateDelay: TimeInterval = 0.1 // Toolbar animations
    
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
        
        // Only process if direction actually changed
        guard newDirection != lastScrollDirection else { 
            return 
        }
        lastScrollDirection = newDirection
        
        // Cancel previous UI update
        uiUpdateWorkItem?.cancel()
        
        // Schedule new UI update with debouncing
        let workItem = DispatchWorkItem { [weak self] in
            self?.updateToolbarVisibility(isScrollingUp: isScrollingUp)
        }
        uiUpdateWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + uiUpdateDelay, execute: workItem)
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
    
    // MARK: - Private Methods
    private func updateToolbarVisibility(isScrollingUp: Bool) {
        if isScrollingUp {
            // Scrolling up - show all bars
            if !isTopBarVisible {
                isTopBarVisible = true
            }
            // Show subtoolbar only if user has scrolled down first
            if hasScrolledDown && !isSubToolbarVisible {
                isSubToolbarVisible = true
            }
            if !isBottomBarVisible {
                isBottomBarVisible = true
            }
        } else {
            // Scrolling down - hide all bars
            hasScrolledDown = true
            
            if isTopBarVisible {
                isTopBarVisible = false
            }
            if isSubToolbarVisible {
                isSubToolbarVisible = false
            }
            if isBottomBarVisible {
                isBottomBarVisible = false
            }
        }
    }
    
    private func updateScrollPosition(offset: CGFloat, contentHeight: CGFloat, viewHeight: CGFloat) {
        scrollPosition = offset
        scrollContentHeight = contentHeight
        scrollViewHeight = viewHeight
        
        // Check if we're near the bottom
        let bottomOffset = offset + viewHeight
        let newIsNearBottom = contentHeight > 0 && bottomOffset >= contentHeight - 100
        
        // Only update if changed to reduce published events
        if newIsNearBottom != isNearBottom {
            isNearBottom = newIsNearBottom
        }
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
        
        scrollPosition = 0
        scrollContentHeight = 0
        scrollViewHeight = 0
    }
}