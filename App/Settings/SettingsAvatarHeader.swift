//  SettingsAvatarHeader.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import FLAnimatedImage
import UIKit

class SettingsAvatarHeader: UIView {
    
    // Strong reference in case we temporarily remove it
    @IBOutlet fileprivate var avatarImageView: FLAnimatedImageView!
    
    @IBOutlet fileprivate(set) weak var usernameLabel: UILabel!
    @IBOutlet fileprivate var avatarConstraints: [NSLayoutConstraint]!
    @IBOutlet fileprivate var insetConstraints: [NSLayoutConstraint]!
    
    /// Only the `insets.left` value is used, though it is applied to both the left and the right.
    var contentEdgeInsets: UIEdgeInsets = .zero {
        didSet(oldInsets) {
            if contentEdgeInsets.left != oldInsets.left {
                setNeedsUpdateConstraints()
            }
        }
    }
    
    class func newFromNib() -> SettingsAvatarHeader {
        return Bundle.main.loadNibNamed("SettingsAvatarHeader", owner: nil, options: nil)![0] as! SettingsAvatarHeader
    }
    
    override func updateConstraints() {
        if hasAvatar {
            addConstraints(avatarConstraints)
        }
        for constraint in insetConstraints {
            constraint.constant = contentEdgeInsets.left
        }
        super.updateConstraints()
    }
    
    override var intrinsicContentSize: CGSize {
        let usernameHeight = usernameLabel.intrinsicContentSize.height + 8
        if hasAvatar {
            return CGSize(width: UIViewNoIntrinsicMetric, height: max(avatarImageView.intrinsicContentSize.height, usernameHeight))
        } else {
            return CGSize(width: UIViewNoIntrinsicMetric, height: usernameHeight)
        }
    }
    
    fileprivate var hasAvatar: Bool {
        return avatarImageView.image != nil
    }
    
    func setAvatarImage(_ image: AnyObject?) {
        if let image = image as? FLAnimatedImage {
            avatarImageView.animatedImage = image
        } else {
            avatarImageView.image = image as? UIImage
        }
        
        if hasAvatar {
            addSubview(avatarImageView)
            setNeedsUpdateConstraints()
            invalidateIntrinsicContentSize()
            avatarImageView.startAnimating()
        } else {
            avatarImageView.removeFromSuperview()
        }
    }
    
    // MARK: Target-action
    
    @IBOutlet fileprivate weak var tapGestureRecognizer: UITapGestureRecognizer!
    fileprivate var target: AnyObject?
    fileprivate var action: Selector?
    
    func setTarget(_ target: AnyObject?, action: Selector?) {
        if let action = action {
            self.target = target
            self.action = action
            tapGestureRecognizer.isEnabled = true
        } else {
            self.target = nil
            self.action = nil
            tapGestureRecognizer.isEnabled = false
        }
    }
    
    @IBAction func didTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            UIApplication.shared.sendAction(action!, to: target, from: self, for: nil)
        }
    }
}

private var KVOContext = 0
