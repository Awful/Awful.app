//  SettingsAvatarHeader.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import FLAnimatedImage
import Nuke
import UIKit

final class SettingsAvatarHeader: UIView {
    
    @IBOutlet private var avatarImageView: FLAnimatedImageView!
    @IBOutlet private var insetConstraints: [NSLayoutConstraint] = []
    @IBOutlet private var usernameLabel: UILabel!

    private var observer: NSKeyValueObservation?
    
    class func newFromNib() -> SettingsAvatarHeader {
        return Bundle.main.loadNibNamed("SettingsAvatarHeader", owner: nil, options: nil)![0] as! SettingsAvatarHeader
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonAwake()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        commonAwake()
    }
    
    private func commonAwake() {
        let defaults = UserDefaults.standard
        observer = defaults.observeOnMain(\.loggedInUsername) {
            [weak self] defaults, change in
            self?.usernameLabel.text = defaults.loggedInUsername
        }
        usernameLabel.text = defaults.loggedInUsername
    }

    var horizontalPadding: CGFloat {
        get { return insetConstraints[0].constant }
        set { insetConstraints.forEach { $0.constant = newValue } }
    }

    func configure(avatarURL: URL?, horizontalPadding: CGFloat, textColor: UIColor?) {
        self.horizontalPadding = horizontalPadding
        usernameLabel.textColor = textColor

        guard let avatarURL = avatarURL else {
            Nuke.cancelRequest(for: avatarImageView)
            avatarImageView.image = nil
            avatarImageView.isHidden = true
            return
        }

        avatarImageView.isHidden = false

        Nuke.loadImage(with: avatarURL, into: avatarImageView, completion: {
            [weak self] response, error in
            self?.avatarImageView.isHidden = response?.image == nil
        })
    }
    
    // MARK: Target-action
    
    @IBOutlet private var tapGestureRecognizer: UITapGestureRecognizer?
    private var target: Any?
    private var action: Selector?
    
    func setTarget(_ target: Any?, action: Selector?) {
        if let action = action {
            self.target = target
            self.action = action
            tapGestureRecognizer?.isEnabled = true
        } else {
            self.target = nil
            self.action = nil
            tapGestureRecognizer?.isEnabled = false
        }
    }
    
    @IBAction private func didTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            UIApplication.shared.sendAction(action!, to: target, from: self, for: nil)
        }
    }
}
