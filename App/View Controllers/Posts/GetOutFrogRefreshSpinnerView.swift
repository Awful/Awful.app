//  GetOutFrogRefreshSpinnerView.swift
//
//  Copyright 2022 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Lottie

final class GetOutFrogRefreshSpinnerView: UIView, PostsPageRefreshControlContent {
    private let animationView = LottieAnimationView(
        animation: LottieAnimation.named("frogrefresh60"),
        configuration: LottieConfiguration(renderingEngine: .mainThread))
 

    init(theme: Theme) {
    
        super.init(frame: .zero)
        
        animationView.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
    
        animationView.animationSpeed = 1
        
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

        animationView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        animationView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        animationView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        animationView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        animationView.widthAnchor.constraint(equalToConstant: 60).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func transition(from oldState: PostsPageView.RefreshControlState, to newState: PostsPageView.RefreshControlState) {
        
         switch (oldState, newState) {
         case (_, .disabled):
             animationView.currentFrame = 0
             break
         case (_, .ready),
              (_, .awaitingScrollEnd):
             animationView.currentFrame = 0
             break
         case (_, .armed(triggeredFraction: 0.0)):
             animationView.play(fromFrame: 25, toFrame: 0, loopMode: .playOnce)
             break
         case (.armed, .triggered):
             animationView.play(fromFrame: 0, toFrame: 25, loopMode: .playOnce)
             if UserDefaults.standard.enableHaptics {
                 UIImpactFeedbackGenerator(style: .medium).impactOccurred()
             }
             break
         case (.refreshing, .refreshing):
             break
         case (_, .refreshing):
             animationView.play(fromFrame: 25, toFrame: .infinity, loopMode: .playOnce)
             if UserDefaults.standard.enableHaptics {
                 UIImpactFeedbackGenerator(style: .medium).impactOccurred()
             }
         case (_, .armed):
             break
         case (.disabled, _),
              (.ready, _),
              (.armed, _),
              (.awaitingScrollEnd, _),
              (.triggered, _),
              (.refreshing, _):
            break
         }
 
    }

 
    // MARK: PostsPageRefreshControlContent
    
    var state: PostsPageView.RefreshControlState = .ready {
        didSet {
            transition(from: oldValue, to: state)
        }
    }
}

private let indefiniteRotationAnimationKey = "RotateForever"
