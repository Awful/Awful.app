//  NigglyRefreshLottieView.swift
//
//  Copyright 2022 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Combine
import PullToRefresh
import Lottie
import UIKit

final class NigglyRefreshLottieView: UIView, Themeable {

    var theme: Theme {
        didSet {
            if oldValue != theme {
                themeDidChange()
            }
        }
    }

    private let animationView: LottieAnimationView = .init(
        animation: .named("niggly60"),
        configuration: .init(renderingEngine: .mainThread)
    )

    init(theme: Theme) {
        self.theme = theme
        super.init(frame: .zero)
        
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func commonInit() {
        backgroundColor = theme["backgroundColor"]!

        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.animationSpeed = 1
        animationView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(animationView)

        directionalLayoutMargins = .init(top: 6, leading: 0, bottom: 6, trailing: 0)
        let marginGuide = layoutMarginsGuide
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            marginGuide.bottomAnchor.constraint(equalTo: animationView.bottomAnchor),

            animationView.centerXAnchor.constraint(equalTo: centerXAnchor),

            animationView.widthAnchor.constraint(equalToConstant: 40),
            animationView.heightAnchor.constraint(equalToConstant: 40),
        ])

        themeDidChange()
    }
    
    func themeDidChange() {
        let color = ColorValueProvider(theme["nigglyColor"]!.lottieColorValue)
        let mainOutline = AnimationKeypath(keys: ["**", "**", "**", "Color"])
        animationView.setValueProvider(color, keypath: mainOutline)
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
