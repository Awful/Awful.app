//  SettingsAvatarHeader.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import Combine
import FLAnimatedImage
import NukeExtensions
import UIKit

final class SettingsAvatarHeader: UIView {
    
    @IBOutlet private var avatarImageView: FLAnimatedImageView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var usernameLabel: UILabel!

    private var cancellables: Set<AnyCancellable> = []
    @FoilDefaultStorageOptional(Settings.username) private var username

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
        $username
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.usernameLabel.text = $0 }
            .store(in: &cancellables)
    }

    func configure(avatarURL: URL?, horizontalPadding: CGFloat, textColor: UIColor?) {
        stackView.layoutMargins = .init(top: 0, left: horizontalPadding, bottom: 0, right: horizontalPadding)

        usernameLabel.textColor = textColor

        guard let avatarURL = avatarURL else {
            NukeExtensions.cancelRequest(for: avatarImageView)
            avatarImageView.image = nil
            avatarImageView.isHidden = true
            return
        }

        avatarImageView.isHidden = false

        NukeExtensions.loadImage(with: avatarURL, into: avatarImageView, completion: {
            [weak self] result in
            self?.avatarImageView.isHidden = {
                switch result {
                case .success: return false
                case .failure: return true
                }
            }()
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
