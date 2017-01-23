//
//  NigglyRefreshView.swift
//  Awful
//
//  Created by Nolan Waite on 2016-06-22.
//  Copyright © 2016 Awful Contributors. All rights reserved.
//

import PullToRefresh
import SpriteKit
import UIKit

private let verticalMargin: CGFloat = 10

final class NigglyRefreshView: UIView, RefreshViewAnimator {
    private let atlas: SKTextureAtlas
    private let sceneView: SKView
    private let node: SKSpriteNode
    
    override init(frame: CGRect) {
        atlas = SKTextureAtlas(named: "niggly-throbber")
        node = SKSpriteNode(texture: atlas.textureNamed("niggly-throbber0"))
        let scene = SKScene(size: node.size)
        node.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        scene.addChild(node)
        
        sceneView = SKView(frame: CGRect(origin: .zero, size: scene.size))
        sceneView.presentScene(scene)
        
        var frame = frame
        if frame.width == 0 {
            frame.size.width = intrinsicSize.width
        }
        if frame.height == 0 {
            frame.size.height = intrinsicSize.height
        }
        super.init(frame: frame)
        
        addSubview(sceneView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backgroundColor: UIColor? {
        didSet {
            let color = backgroundColor ?? .white
            sceneView.backgroundColor = color
            sceneView.scene?.backgroundColor = color
            node.color = color
        }
    }
    
    override func layoutSubviews() {
        sceneView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    func animateState(_ state: State) {
        switch state {
        case .initial:
            node.removeAllActions()
            
        case .releasing(let progress) where progress < 1:
            node.speed = 0
            node.run(makeNigglyRefreshAction(atlas: atlas), withKey: actionKey)
            
        case .loading, .releasing:
            node.speed = 1
            
        case .finished:
            node.speed = 0
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIViewNoIntrinsicMetric, height: intrinsicSize.height)
    }
}

final class NigglyLoadMoreView: UIView {
    private let sceneView: SKView
    private let node: SKSpriteNode
    
    override init(frame: CGRect) {
        let atlas = SKTextureAtlas(named: "niggly-throbber")
        node = SKSpriteNode(texture: atlas.textureNamed("niggly-throbber0"))
        let scene = SKScene(size: node.size)
        node.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        scene.addChild(node)
        
        sceneView = SKView(frame: CGRect(origin: .zero, size: scene.size))
        sceneView.presentScene(scene)
        
        var frame = frame
        if frame.width == 0 {
            frame.size.width = intrinsicSize.width
        }
        if frame.height == 0 {
            frame.size.height = intrinsicSize.height
        }
        super.init(frame: frame)
        
        addSubview(sceneView)
        
        node.run(makeNigglyRefreshAction(atlas: atlas), withKey: actionKey)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backgroundColor: UIColor? {
        didSet {
            let color = backgroundColor ?? .white
            sceneView.backgroundColor = color
            sceneView.scene?.backgroundColor = color
            node.color = color
        }
    }
    
    override func layoutSubviews() {
        sceneView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIViewNoIntrinsicMetric, height: intrinsicSize.height)
    }
}

private func makeNigglyRefreshAction(atlas: SKTextureAtlas) -> SKAction {
    let textures = (0...30).map { atlas.textureNamed("niggly-throbber\($0)") }
    return SKAction.repeatForever(SKAction.animate(with: textures, timePerFrame: 0.04))
}

private let actionKey = "niggly"
private let intrinsicSize = CGSize(width: 36, height: 36)
