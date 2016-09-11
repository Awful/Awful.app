//  PostsViewTopBar.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class PostsViewTopBar: UIView {
    let parentForumButton = UIButton()
    let previousPostsButton = UIButton()
    let scrollToBottomButton = UIButton()
    
    override init(frame: CGRect) {
        var enforcedHeightFrame = frame
        enforcedHeightFrame.size.height = 40
        super.init(frame: enforcedHeightFrame)
        
        parentForumButton.setTitle("Parent Forum", for: UIControlState())
        parentForumButton.accessibilityLabel = "Parent forum"
        parentForumButton.accessibilityHint = "Opens this thread's forum"
        parentForumButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        addSubview(parentForumButton)
        
        previousPostsButton.setTitle("Previous Posts", for: UIControlState())
        previousPostsButton.accessibilityLabel = "Previous posts"
        previousPostsButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        addSubview(previousPostsButton)
        
        scrollToBottomButton.setTitle("Scroll To End", for: UIControlState())
        scrollToBottomButton.accessibilityLabel = "Scroll to end"
        scrollToBottomButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        addSubview(scrollToBottomButton)
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
    }
}
