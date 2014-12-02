//  SettingsAvatarHeader.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class SettingsAvatarHeader: UIView {
    
    // Strong reference in case we temporarily remove it
    @IBOutlet private var avatarImageView: FLAnimatedImageView!
    
    @IBOutlet private(set) weak var usernameLabel: UILabel!
    @IBOutlet private var avatarConstraints: [NSLayoutConstraint]!
    @IBOutlet private var insetConstraints: [NSLayoutConstraint]!
    
    /// Only the `insets.left` value is used, though it is applied to both the left and the right.
    var contentEdgeInsets: UIEdgeInsets = UIEdgeInsetsZero {
        didSet(oldInsets) {
            if contentEdgeInsets.left != oldInsets.left {
                setNeedsUpdateConstraints()
            }
        }
    }
    
    class func newFromNib() -> SettingsAvatarHeader {
        return NSBundle.mainBundle().loadNibNamed("SettingsAvatarHeader", owner: nil, options: nil)[0] as SettingsAvatarHeader
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
    
    override func intrinsicContentSize() -> CGSize {
        let usernameHeight = usernameLabel.intrinsicContentSize().height + 8
        if hasAvatar {
            return CGSize(width: UIViewNoIntrinsicMetric, height: max(avatarImageView.intrinsicContentSize().height, usernameHeight))
        } else {
            return CGSize(width: UIViewNoIntrinsicMetric, height: usernameHeight)
        }
    }
    
    private var hasAvatar: Bool {
        return avatarImageView.image != nil
    }
    
    func setAvatarImage(image: AnyObject?) {
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
    
    @IBOutlet private weak var tapGestureRecognizer: UITapGestureRecognizer!
    private var target: AnyObject!
    private var action: Selector?
    
    func setTarget(target: AnyObject!, action: String?) {
        if let action = action {
            self.target = target
            self.action = Selector(action)
            tapGestureRecognizer.enabled = true
        } else {
            self.target = nil
            self.action = nil
            tapGestureRecognizer.enabled = false
        }
    }
    
    @IBAction func didTap(sender: UITapGestureRecognizer) {
        if sender.state == .Ended {
            UIApplication.sharedApplication().sendAction(action!, to: target, from: self, forEvent: nil)
        }
    }
}

private var KVOContext = 0
