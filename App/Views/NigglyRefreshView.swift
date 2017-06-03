//  NigglyRefreshView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PullToRefresh
import SpriteKit
import UIKit

private let verticalMargin: CGFloat = 10

final class NigglyRefreshView: UIView {
    fileprivate let spriteSheetView = makeSpriteSheetView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        spriteSheetView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spriteSheetView)
        
        NSLayoutConstraint.activate([
            spriteSheetView.centerXAnchor.constraint(equalTo: centerXAnchor),
            spriteSheetView.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
    }
    
    override func layoutSubviews() {
        spriteSheetView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    override var intrinsicContentSize: CGSize {
        let spriteSheetSize = spriteSheetView.intrinsicContentSize
        let margin: CGFloat = 6
        return CGSize(width: UIViewNoIntrinsicMetric, height: spriteSheetSize.height + (margin * 2))
    }
    
    func startAnimating() {
        spriteSheetView.startAnimating()
    }
}

extension NigglyRefreshView {
    final class RefreshAnimator: RefreshViewAnimator {
        private let view: NigglyRefreshView
        
        init(view: NigglyRefreshView) {
            self.view = view
        }
        
        func animateState(_ state: State) {
            switch state {
            case .initial:
                view.spriteSheetView.startAnimating()
                view.spriteSheetView.pause()
                
            case .releasing(let progress) where progress < 1:
                view.spriteSheetView.pause()
                
            case .loading, .releasing:
                view.spriteSheetView.resume()
                
            case .finished:
                view.spriteSheetView.stopAnimating()
            }
        }
    }
}

private func makeSpriteSheetView() -> SpriteSheetView {
    let image = UIImage(named: "niggly-throbber")!
    let view = SpriteSheetView(spriteSheet: image)
    view.frameRate = 25
    return view
}
