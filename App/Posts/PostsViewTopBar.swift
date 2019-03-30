//  PostsViewTopBar.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class PostsViewTopBar: UIView {
    private var observers: [NSKeyValueObservation] = []
    
    private let bottomBorder: CALayer = CALayer()
    
    let parentForumButton = UIButton()
    let previousPostsButton = UIButton()
    let scrollToBottomButton = UIButton()
    
    override init(frame: CGRect) {
        var enforcedHeightFrame = frame
        enforcedHeightFrame.size.height = 40
        super.init(frame: enforcedHeightFrame)
        
        parentForumButton.setTitle("Parent Forum", for: UIControl.State())
        parentForumButton.accessibilityLabel = "Parent forum"
        parentForumButton.accessibilityHint = "Opens this thread's forum"
        parentForumButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        addSubview(parentForumButton)
        
        previousPostsButton.setTitle("Previous Posts", for: UIControl.State())
        previousPostsButton.accessibilityLabel = "Previous posts"
        previousPostsButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        addSubview(previousPostsButton)
        
        scrollToBottomButton.setTitle("Scroll To End", for: UIControl.State())
        scrollToBottomButton.accessibilityLabel = "Scroll to end"
        scrollToBottomButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        addSubview(scrollToBottomButton)
        
        observers += UserDefaults.standard.observeSeveral {
            $0.observe(\.isAlternateThemeEnabled, \.isDarkModeEnabled) {
                [unowned self] defaults in
                self.configureBarColor()
            }
        }
        
        configureBarColor()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        let buttonWidth = floor((bounds.width - 2) / 3)
        let leftoverWidth = bounds.width - buttonWidth * 3 - 2
        let buttonHeight = bounds.height
        
        parentForumButton.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight)
        
        previousPostsButton.frame = CGRect(x: parentForumButton.frame.maxX + 1, y: 0, width: buttonWidth + leftoverWidth, height: buttonHeight)
        
        scrollToBottomButton.frame = CGRect(x: previousPostsButton.frame.maxX + 1, y: 0, width: buttonWidth, height: buttonHeight)
        
        configureBarColor()
    }
    
    private func configureBarColor() {
        print("PostsViewTopBar configureBarColor entry")
        if UserDefaults.standard.isAlternateThemeEnabled && UserDefaults.standard.isDarkModeEnabled {
            print("adding border")
            bottomBorder.frame = CGRect(x: 0, y: frame.size.height - 0.5, width: frame.size.width, height: 0.5)
            bottomBorder.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).cgColor
            bottomBorder.removeFromSuperlayer()
            layer.addSublayer(bottomBorder)
        } else {
            print("removing border")
            bottomBorder.removeFromSuperlayer()
        }
    }
}
