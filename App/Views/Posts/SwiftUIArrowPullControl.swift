//  SwiftUIArrowPullControl.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import SwiftUI
import UIKit

/// SwiftUI arrow-based pull control that matches the UIKit PostsPageRefreshArrowView
struct SwiftUIArrowPullControl: View {
    let theme: Theme
    let pullProgress: CGFloat
    let isVisible: Bool
    let onRefreshTriggered: () -> Void
    
    @State private var currentState: ArrowState = .ready
    @State private var hasTriggeredRefresh = false
    @State private var triggeredStateStartTime: Date?
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    
    // MARK: - State Management
    enum ArrowState {
        case ready      // Arrow pointing up (-90°)
        case armed      // Arrow pointing up, ready to trigger
        case triggered  // Arrow pointing right (0°)
        case refreshing // Spinner visible
    }
    
    private struct Angles {
        static let waiting: Double = -90 // Point up when waiting (pull down to activate)
        static let triggered: Double = 0 // Point right when triggered (ready to release)
    }
    
    var body: some View {
        Group {
            if isVisible {
                ZStack {
                    // Arrow Image
                    if currentState != .refreshing {
                        Image("arrowright")
                            .renderingMode(.template)
                            .foregroundColor(Color(theme[uicolor: "tintColor"] ?? .systemBlue))
                            .rotationEffect(.degrees(rotationAngle))
                            .animation(.spring(response: 0.3, dampingFraction: 1.0), value: rotationAngle)
                            .opacity(currentState == .refreshing ? 0 : 1)
                    }
                    
                    // Activity Indicator for refreshing state
                    if currentState == .refreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(theme[uicolor: "tintColor"] ?? .systemBlue)))
                            .scaleEffect(1.2)
                    }
                }
                .frame(width: 44, height: 44)
                .opacity(isVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: isVisible)
                .onChange(of: pullProgress) { progress in
                    updateState(for: progress)
                }
            }
        }
        .background(Color.clear)
    }
    
    // MARK: - Computed Properties
    private var rotationAngle: Double {
        switch currentState {
        case .ready:
            return Angles.waiting // Point up - pull more
        case .armed:
            return Angles.waiting // Point up - pull more  
        case .triggered:
            return Angles.triggered // Point right - release to trigger
        case .refreshing:
            return Angles.triggered // Point right during refresh
        }
    }
    
    // MARK: - State Management
    private func updateState(for progress: CGFloat) {
        // Don't update if already refreshing
        guard currentState != .refreshing else { return }
        
        // Only log significant state changes
        if progress >= 0.8 && currentState != .triggered {
            print("🔄 ArrowPullControl: Progress \(progress) - reaching triggered state")
        } else if progress < 0.3 && currentState == .triggered {
            print("🔄 ArrowPullControl: Progress \(progress) - potential release from triggered state")
        }
        
        let newState: ArrowState
        
        if progress >= 0.8 {
            // Armed state - arrow pointing right, ready to trigger when released
            newState = .triggered
            
            // Provide haptic feedback when first reaching triggered state
            if currentState != .triggered && !hasTriggeredRefresh {
                print("🔄 ArrowPullControl: Reached triggered state - providing haptic feedback")
                triggeredStateStartTime = Date()
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        } else if progress > 0.3 {
            // Normal pull state - arrow pointing up
            newState = .ready
            
            // If we were triggered and now we're pulling less, user is disarming
            if currentState == .triggered && !hasTriggeredRefresh {
                // Check if user held triggered state long enough before reducing pull
                if let startTime = triggeredStateStartTime, Date().timeIntervalSince(startTime) > 0.1 {
                    print("🔄 ArrowPullControl: User held triggered state and reduced pull - firing refresh!")
                    triggerRefresh()
                    return
                } else {
                    print("🔄 ArrowPullControl: User disarming by reducing pull (too quickly)")
                }
            }
        } else {
            // Lower pull or release - check if we should trigger or just reset
            if currentState == .triggered && !hasTriggeredRefresh {
                // User released while in triggered state - fire the action!
                print("🔄 ArrowPullControl: User released in triggered state - firing refresh!")
                triggerRefresh()
                return
            } else {
                print("🔄 ArrowPullControl: Resetting state (progress=\(progress))")
                resetState()
                return
            }
        }
        
        // Always update state for proper disarming behavior
        if newState != currentState && !hasTriggeredRefresh {
            print("🔄 ArrowPullControl: Updating state from \(currentState) to \(newState)")
            currentState = newState
        }
    }
    
    // This method triggers the navigation when user releases in triggered state
    private func triggerRefresh() {
        print("🔄 ArrowPullControl: triggerRefresh() called")
        hasTriggeredRefresh = true
        currentState = .refreshing
        onRefreshTriggered()
        
        // Reset immediately since this triggers navigation, not refresh
        DispatchQueue.main.async {
            resetState()
        }
    }
    
    private func resetState() {
        currentState = .ready
        hasTriggeredRefresh = false
        triggeredStateStartTime = nil
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        SwiftUIArrowPullControl(
            theme: Theme.defaultTheme(),
            pullProgress: 0.0,
            isVisible: true,
            onRefreshTriggered: {}
        )
        
        SwiftUIArrowPullControl(
            theme: Theme.defaultTheme(),
            pullProgress: 0.5,
            isVisible: true,
            onRefreshTriggered: {}
        )
        
        SwiftUIArrowPullControl(
            theme: Theme.defaultTheme(),
            pullProgress: 1.0,
            isVisible: true,
            onRefreshTriggered: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}