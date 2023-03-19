//  NigglyRefreshLottieView.swift
//
//  Copyright 2022 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PullToRefresh
import Lottie
import UIKit

private let verticalMargin: CGFloat = 10

final class NigglyRefreshLottieView: UIView {
    private let animationView = LottieAnimationView(
        animation: LottieAnimation.named("niggly60"),
        configuration: LottieConfiguration(renderingEngine: .mainThread))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        var theme: Theme {
            return Theme.defaultTheme()
        }
        
        animationView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        animationView.translatesAutoresizingMaskIntoConstraints = true
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.animationSpeed = 1
        
        addSubview(animationView)
        
        backgroundColor = Theme.defaultTheme()["backgroundColor"]!
        
        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }
    
    override func layoutSubviews() {
        let gray = ColorValueProvider(Theme.defaultTheme()["nigglyColor"]!.lottieColorValue)
        let mainOutline = AnimationKeypath(keys: ["**", "**", "**", "Color"])
    
        animationView.setValueProvider(gray, keypath: mainOutline)
        animationView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    override var intrinsicContentSize: CGSize {
        let spriteSheetSize = animationView.intrinsicContentSize
        let margin: CGFloat = 6
        return CGSize(width: UIView.noIntrinsicMetric, height: spriteSheetSize.height + (margin * 2))
    }
    
    func startAnimating() {
        animationView.play()
    }
    
    func stopAnimating() {
        animationView.stop()
    }
}

extension NigglyRefreshLottieView {
    final class RefreshAnimator: RefreshViewAnimator {
        private let view: NigglyRefreshLottieView
        
        init(view: NigglyRefreshLottieView) {
            self.view = view
        }
        
        func animate(_ state: State) {
            switch state {
            case .initial:
                view.animationView.play()
                view.animationView.pause()
                
            case .releasing(let progress) where progress < 1:
                view.animationView.pause()
                
            case .loading, .releasing:
                view.animationView.play()
                
            case .finished:
                view.animationView.stop()
            }
        }
    }
}
