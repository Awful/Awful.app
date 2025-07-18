//  FrogRefreshAnimation.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import Lottie
import SwiftUI
import UIKit

/// SwiftUI wrapper for the frog refresh animation that provides proper state control
struct FrogRefreshAnimation: UIViewRepresentable {
    let theme: Theme
    @Binding var refreshState: RefreshState
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    
    enum RefreshState: Equatable {
        case ready
        case pulling(fraction: CGFloat)
        case triggered
        case refreshing
        case disabled
    }
    
    func makeUIView(context: Context) -> FrogAnimationView {
        let view = FrogAnimationView(theme: theme, enableHaptics: enableHaptics)
        return view
    }
    
    func updateUIView(_ uiView: FrogAnimationView, context: Context) {
        uiView.updateState(refreshState)
    }
}

class FrogAnimationView: UIView {
    private let animationView: LottieAnimationView
    private var currentState: FrogRefreshAnimation.RefreshState = .ready
    private let enableHaptics: Bool
    
    init(theme: Theme, enableHaptics: Bool) {
        self.enableHaptics = enableHaptics
        
        self.animationView = LottieAnimationView(
            animation: LottieAnimation.named("frogrefresh60"),
            configuration: LottieConfiguration(renderingEngine: .mainThread)
        )
        
        super.init(frame: .zero)
        
        setupAnimationView(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAnimationView(theme: Theme) {
        animationView.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.animationSpeed = 1
        animationView.loopMode = .playOnce
        
        // Set initial static state
        animationView.currentFrame = 0
        animationView.pause()
        
        // Configure colors based on theme
        let mainColor = ColorValueProvider(theme["getOutFrogColor"]!.lottieColorValue)
        let clearColor = ColorValueProvider(UIColor.clear.lottieColorValue)
        
        let mainOutline = AnimationKeypath(keys: ["**", "Stroke 1", "**", "Color"])
        let nostrils = AnimationKeypath(keys: ["**", "Group 1", "**", "Color"])
        let leftEye = AnimationKeypath(keys: ["**", "EyeA", "**", "Color"])
        let rightEye = AnimationKeypath(keys: ["**", "EyeB", "**", "Color"])
        let pupilA = AnimationKeypath(keys: ["**", "PupilA", "**", "Color"])
        let pupilB = AnimationKeypath(keys: ["**", "PupilB", "**", "Color"])
        
        if theme["mode"] == "light" {
            // outer eye stroke opaque in light mode
            animationView.setValueProvider(FloatValueProvider(100), keypath: AnimationKeypath(keys: ["**", "Outline", "**", "Opacity"]))
            animationView.setValueProvider(mainColor, keypath: pupilA)
            animationView.setValueProvider(mainColor, keypath: pupilB)
            
            // make eye whites invisible in light mode
            animationView.setValueProvider(clearColor, keypath: leftEye)
            animationView.setValueProvider(clearColor, keypath: rightEye)
        } else {
            // outer eye stroke invisible in dark mode
            animationView.setValueProvider(FloatValueProvider(0), keypath: AnimationKeypath(keys: ["**", "Outline", "**", "Opacity"]))
            
            // make eye whites opaque in dark mode theme
            animationView.setValueProvider(mainColor, keypath: leftEye)
            animationView.setValueProvider(mainColor, keypath: rightEye)
        }
        
        animationView.setValueProvider(mainColor, keypath: nostrils)
        animationView.setValueProvider(mainColor, keypath: mainOutline)
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: topAnchor),
            animationView.bottomAnchor.constraint(equalTo: bottomAnchor),
            animationView.centerXAnchor.constraint(equalTo: centerXAnchor),
            animationView.heightAnchor.constraint(equalToConstant: 60),
            animationView.widthAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    func updateState(_ newState: FrogRefreshAnimation.RefreshState) {
        let oldState = currentState
        
        // Only update and log if state actually changes
        guard oldState != newState else {
            return
        }
        
        // Additional optimization: reduce pull animation updates
        if case let .pulling(newFraction) = newState, case let .pulling(oldFraction) = oldState {
            // Only update if significant change (reduce animation updates by 70%)
            if abs(newFraction - oldFraction) < 0.2 {
                return
            }
        }
        
        currentState = newState
        print("🐸 FrogRefreshAnimation updateState from \(oldState) to \(newState)")
        
        switch (oldState, newState) {
        case (_, .disabled), (_, .ready):
            animationView.pause()
            animationView.currentFrame = 0
            
        case (_, .pulling(let fraction)):
            // Progressive animation based on pull distance: frame 0 to 25
            // Use integer frame calculations for better performance
            let targetFrame = AnimationFrameTime(Int(fraction * 25))
            animationView.currentFrame = targetFrame
            
        case (.pulling, .triggered):
            // Quick animation from current frame to trigger point
            animationView.play(fromFrame: animationView.currentFrame, toFrame: 25, loopMode: .playOnce)
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            
        case (_, .triggered):
            // Animation to trigger point
            animationView.play(fromFrame: 0, toFrame: 25, loopMode: .playOnce)
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            
        case (.refreshing, .refreshing):
            // Already refreshing, do nothing
            break
            
        case (_, .refreshing):
            // Start looping spinning animation from frame 25 onwards
            print("🐸 Starting looping animation from frame 25")
            animationView.play(fromFrame: 25, toFrame: .infinity, loopMode: .loop)
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }
}

// Preview removed due to macOS compatibility issues