//  SwiftUINigglyPullControl.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import SwiftUI
import UIKit
import Lottie

/// SwiftUI niggly-based pull control for top pull-to-refresh behavior
struct SwiftUINigglyPullControl: View {
    let theme: Theme
    let pullProgress: CGFloat
    let isVisible: Bool
    let isRefreshing: Bool
    let onRefreshTriggered: () -> Void
    
    @State private var currentState: NigglyState = .ready
    @State private var hasTriggeredRefresh = false
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    
    // MARK: - State Management
    enum NigglyState {
        case ready      // At rest, static first frame
        case armed      // Pull threshold reached, static first frame
        case refreshing // Active refresh with continuous looping
        case finished   // Refresh completed
    }
    
    var body: some View {
        Group {
            if isVisible {
                NigglyLottieView(
                    theme: theme,
                    pullProgress: pullProgress,
                    currentState: currentState,
                    onRefreshTriggered: {
                        // This callback is not used - state management is handled externally
                        print("🔄 NigglyLottieView: onRefreshTriggered called (unused)")
                    }
                )
                .frame(width: 60, height: 60) // SwiftUI container - keep reasonable size for visibility
                .scaleEffect(0.5) // Force the entire control to be half size
                .opacity(fadeOpacity)
                .animation(.easeInOut(duration: 0.3), value: fadeOpacity)
                .onChange(of: pullProgress) { progress in
                    updateState(for: progress)
                }
                .onChange(of: isRefreshing) { refreshing in
                    if refreshing {
                        currentState = .refreshing
                    } else {
                        resetState()
                    }
                }
            }
        }
        .background(Color.clear)
    }
    
    // MARK: - Computed Properties
    private var fadeOpacity: CGFloat {
        // Fade-in based on pull distance, minimum 30 points
        return min(1.0, pullProgress * 2.0) // More aggressive fade-in for top pull
    }
    
    // MARK: - State Management
    private func updateState(for progress: CGFloat) {
        // Don't update if already refreshing or finished
        guard currentState != .refreshing && currentState != .finished else { return }
        
        // If explicitly refreshing, force refreshing state
        if isRefreshing {
            currentState = .refreshing
            return
        }
        
        let threshold: CGFloat = 0.7 // Pull threshold for triggering (matches main view)
        
        if progress >= threshold {
            // Reached trigger threshold - show static frame, ready to refresh on release
            if currentState != .armed && !hasTriggeredRefresh {
                currentState = .armed
                print("🔄 SwiftUINigglyPullControl: Setting to armed state at progress: \(progress)")
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        } else if progress > 0.1 {
            // Normal pulling - show static first frame
            currentState = .ready
        } else {
            // Reset to ready state
            if !hasTriggeredRefresh {
                currentState = .ready
            }
        }
    }
    
    private func resetState() {
        currentState = .ready
        hasTriggeredRefresh = false
    }
}

// MARK: - Niggly Lottie View
private struct NigglyLottieView: UIViewRepresentable {
    let theme: Theme
    let pullProgress: CGFloat
    let currentState: SwiftUINigglyPullControl.NigglyState
    let onRefreshTriggered: () -> Void
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animation = LottieAnimation.named("niggly60")
        print("🔄 NigglyLottieView: makeUIView - animation loaded: \(animation != nil)")
        if let animation = animation {
            print("🔄 NigglyLottieView: Animation duration: \(animation.duration), endFrame: \(animation.endFrame)")
        }
        
        let animationView = LottieAnimationView(
            animation: animation,
            configuration: LottieConfiguration(renderingEngine: .mainThread)
        )
        
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.animationSpeed = 1
        animationView.backgroundBehavior = .pauseAndRestore
        
        // Set size constraints - smaller than original for better UX
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        animationView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        // Force the view frame size as well
        animationView.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        
        // Set initial static state
        animationView.currentFrame = 0
        animationView.pause()
        
        // Configure colors based on theme - use nigglyColor
        let mainColor = ColorValueProvider(theme["nigglyColor"]!.lottieColorValue)
        let mainOutline = AnimationKeypath(keys: ["**", "**", "**", "Color"])
        animationView.setValueProvider(mainColor, keypath: mainOutline)
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // Update animation based on current state - matches UIKit implementation behavior
        print("🔄 NigglyLottieView: updateUIView called with currentState: \(currentState), isPlaying: \(uiView.isAnimationPlaying)")
        
        switch currentState {
        case .ready:
            // At rest or pulling - show static first frame (like UIKit)
            print("🔄 NigglyLottieView: Setting to ready state - paused at frame 0")
            uiView.pause()
            uiView.currentFrame = 0
            
        case .armed:
            // Pull threshold reached - start looping animation to show it's "armed"
            print("🔄 NigglyLottieView: Setting to armed state - should loop continuously")
            uiView.loopMode = .loop
            if !uiView.isAnimationPlaying {
                print("🔄 NigglyLottieView: Starting loop animation for armed state")
                uiView.play()
            } else {
                print("🔄 NigglyLottieView: Animation already playing in armed state")
            }
            
        case .refreshing:
            // Continuous looping animation during refresh (like UIKit)
            print("🔄 NigglyLottieView: Setting to refreshing state - should loop continuously")
            print("🔄 NigglyLottieView: Current frame: \(uiView.currentFrame), isPlaying: \(uiView.isAnimationPlaying)")
            print("🔄 NigglyLottieView: Animation exists: \(uiView.animation != nil)")
            if let animation = uiView.animation {
                print("🔄 NigglyLottieView: Animation startFrame: \(animation.startFrame), endFrame: \(animation.endFrame)")
            }
            
            // Force restart the animation to ensure it plays
            uiView.stop()
            
            // Ensure loop mode is set for continuous looping
            uiView.loopMode = .loop
            print("🔄 NigglyLottieView: Set loopMode to .loop, current loopMode: \(uiView.loopMode)")
            
            // Play without completion handler to allow infinite looping
            uiView.play()
            print("🔄 NigglyLottieView: Called play() without completion for infinite loop")
            print("🔄 NigglyLottieView: Forced play() call - now playing: \(uiView.isAnimationPlaying)")
            
            // Add a timer to check if animation is progressing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔄 NigglyLottieView: After 0.5s - frame: \(uiView.currentFrame), playing: \(uiView.isAnimationPlaying)")
            }
            
        case .finished:
            // Stop animation and reset
            print("🔄 NigglyLottieView: Setting to finished state - paused at frame 0")
            uiView.pause()
            uiView.currentFrame = 0
        }
        
        // Trigger refresh callback when reaching full pull in armed state
        if currentState == .armed && pullProgress >= 1.0 {
            onRefreshTriggered()
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        Text("Niggly Pull Control States")
            .font(.title2)
            .padding()
        
        VStack(spacing: 20) {
            // Ready state
            VStack {
                Text("Ready (0% pull)")
                SwiftUINigglyPullControl(
                    theme: Theme.defaultTheme(),
                    pullProgress: 0.0,
                    isVisible: true,
                    isRefreshing: false,
                    onRefreshTriggered: {}
                )
            }
            
            // Pulling state
            VStack {
                Text("Pulling (50% pull)")
                SwiftUINigglyPullControl(
                    theme: Theme.defaultTheme(),
                    pullProgress: 0.5,
                    isVisible: true,
                    isRefreshing: false,
                    onRefreshTriggered: {}
                )
            }
            
            // Triggered state
            VStack {
                Text("Triggered (100% pull)")
                SwiftUINigglyPullControl(
                    theme: Theme.defaultTheme(),
                    pullProgress: 1.0,
                    isVisible: true,
                    isRefreshing: false,
                    onRefreshTriggered: {}
                )
            }
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}