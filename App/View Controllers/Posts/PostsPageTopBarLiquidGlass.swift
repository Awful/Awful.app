//  PostsPageTopBarLiquidGlass.swift
//
//  Copyright 2025 Awful Contributors

import AwfulSettings
import AwfulTheming
import UIKit

@available(iOS 26.0, *)
final class PostsPageTopBarLiquidGlass: UIView {
    
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
            
            // Ensure buttons have a minimum height for good touch targets
            parentForumButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            previousPostsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            scrollToEndButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
        
        updateButtonsEnabled()
    }
    
    private static func createCapsuleButton() -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = UIFont.preferredFontForTextStyle(.footnote, sizeAdjustment: 0, weight: .medium)
            return updated
        }
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configurationUpdateHandler = { button in
            guard var config = button.configuration else { return }
            
            // Use toolbarTextColor from theme
            let toolbarTextColor = Theme.defaultTheme()["toolbarTextColor"] ?? UIColor.label
            
            // Set glass effect background
            config.background.backgroundColor = UIColor.clear
            config.background.strokeColor = UIColor.clear
            config.background.strokeWidth = 0
            
            // Apply glass effect as custom view
            let glassEffect = UIGlassEffect()
            let glassView = UIVisualEffectView(effect: glassEffect)
            glassView.layer.cornerRadius = 16 // Capsule shape
            glassView.layer.masksToBounds = true
            config.background.customView = glassView
            
            // Update text colors based on state
            switch button.state {
            case .disabled:
                config.baseForegroundColor = toolbarTextColor.withAlphaComponent(0.5)
            case .highlighted:
                config.baseForegroundColor = toolbarTextColor.withAlphaComponent(0.8)
            default:
                config.baseForegroundColor = toolbarTextColor
            }
            
            button.configuration = config
        }
        return button
    }
    
    func themeDidChange(_ theme: Theme) {
        // Update button colors and glass effects to match new theme
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
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

