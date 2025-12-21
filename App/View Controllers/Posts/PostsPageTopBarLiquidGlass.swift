//  PostsPageTopBarLiquidGlass.swift
//
//  Copyright 2025 Awful Contributors

import AwfulSettings
import AwfulTheming
import UIKit

@available(iOS 26.0, *)
final class PostsPageTopBarLiquidGlass: UIView, PostsPageTopBarProtocol {
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [parentForumButton, previousPostsButton, scrollToEndButton])
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var parentForumButton: UIButton = {
        let button = PostsPageTopBarLiquidGlass.createCapsuleButton()
        button.accessibilityLabel = LocalizedString("posts-page.parent-forum-button.accessibility-label")
        button.accessibilityHint = LocalizedString("posts-page.parent-forum-button.accessibility-hint")
        button.setTitle(LocalizedString("posts-page.parent-forum-button.title"), for: .normal)
        return button
    }()

    private lazy var previousPostsButton: UIButton = {
        let button = PostsPageTopBarLiquidGlass.createCapsuleButton()
        button.accessibilityLabel = LocalizedString("posts-page.previous-posts-button.accessibility-label")
        button.setTitle(LocalizedString("posts-page.previous-posts-button.title"), for: .normal)
        return button
    }()

    private let scrollToEndButton: UIButton = {
        let button = PostsPageTopBarLiquidGlass.createCapsuleButton()
        button.accessibilityLabel = LocalizedString("posts-page.scroll-to-end-button.accessibility-label")
        button.setTitle(LocalizedString("posts-page.scroll-to-end-button.title"), for: .normal)
        return button
    }()
    
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        parentForumButton.addTarget(self, action: #selector(didTapParentForum), for: .primaryActionTriggered)
        previousPostsButton.addTarget(self, action: #selector(didTapPreviousPosts), for: .primaryActionTriggered)
        scrollToEndButton.addTarget(self, action: #selector(didTapScrollToEnd), for: .primaryActionTriggered)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            parentForumButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            previousPostsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            scrollToEndButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
        
        updateButtonsEnabled()
    }
    
    private static func createCapsuleButton() -> UIButton {
        let button = GlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private class GlassButton: UIButton {
        private let glassView: UIVisualEffectView
        private let label: UILabel

        override init(frame: CGRect) {
            let glassEffect = UIGlassEffect()
            glassView = UIVisualEffectView(effect: glassEffect)
            glassView.translatesAutoresizingMaskIntoConstraints = false
            glassView.isUserInteractionEnabled = false
            glassView.layer.cornerRadius = 16
            glassView.layer.masksToBounds = true
            glassView.layer.cornerCurve = .continuous
            glassView.layer.shadowOpacity = 0

            label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.preferredFontForTextStyle(.footnote, sizeAdjustment: 0, weight: .medium)
            label.numberOfLines = 1
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.85
            label.lineBreakMode = .byTruncatingTail
            label.textAlignment = .center
            label.isUserInteractionEnabled = false

            super.init(frame: frame)

            backgroundColor = .clear

            insertSubview(glassView, at: 0)
            glassView.contentView.addSubview(label)

            NSLayoutConstraint.activate([
                glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
                glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
                glassView.topAnchor.constraint(equalTo: topAnchor),
                glassView.bottomAnchor.constraint(equalTo: bottomAnchor),

                label.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -12),
                label.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 6),
                label.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -6),

                heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func setTitle(_ title: String?, for state: UIControl.State) {
            if state == .normal {
                label.text = title
            }
        }

        override var isEnabled: Bool {
            didSet {
                label.alpha = isEnabled ? 1.0 : 0.5
            }
        }
    }
    
    func themeDidChange(_ theme: Theme) {
        for button in [parentForumButton, previousPostsButton, scrollToEndButton] {
            button.setNeedsUpdateConfiguration()
        }
    }
    
    private func updateButtonsEnabled() {
        parentForumButton.isEnabled = goToParentForum != nil
        previousPostsButton.isEnabled = showPreviousPosts != nil
        scrollToEndButton.isEnabled = scrollToEnd != nil
    }
    
    @objc private func didTapParentForum(_ sender: UIButton) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        goToParentForum?()
    }
    var goToParentForum: (() -> Void)? {
        didSet { updateButtonsEnabled() }
    }
    
    @objc private func didTapPreviousPosts(_ sender: UIButton) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        showPreviousPosts?()
    }
    var showPreviousPosts: (() -> Void)? {
        didSet { updateButtonsEnabled() }
    }
    
    @objc private func didTapScrollToEnd(_ sender: UIButton) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        scrollToEnd?()
    }
    var scrollToEnd: (() -> Void)? {
        didSet { updateButtonsEnabled() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

protocol PostsPageTopBarProtocol: UIView {
    var goToParentForum: (() -> Void)? { get set }
    var showPreviousPosts: (() -> Void)? { get set }
    var scrollToEnd: (() -> Void)? { get set }

    func themeDidChange(_ theme: Theme)
}
