//  PostsPageTopBar.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class PostsPageTopBar: UIView {

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [parentForumButton, previousPostsButton, scrollToEndButton])
        stackView.distribution = .fillEqually
        return stackView
    }()

    private lazy var parentForumButton: UIButton = {
        let parentForumButton = UIButton(type: .system)
        parentForumButton.accessibilityLabel = LocalizedString("posts-page.parent-forum-button.accessibility-label")
        parentForumButton.accessibilityHint = LocalizedString("posts-page.parent-forum-button.accessibility-hint")
        parentForumButton.setTitle(LocalizedString("posts-page.parent-forum-button.title"), for: .normal)
        parentForumButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        return parentForumButton
    }()

    private lazy var previousPostsButton: UIButton = {
        let previousPostsButton = UIButton(type: .system)
        previousPostsButton.accessibilityLabel = LocalizedString("posts-page.previous-posts-button.accessibility-label")
        previousPostsButton.setTitle(LocalizedString("posts-page.previous-posts-button.title"), for: .normal)
        previousPostsButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        return previousPostsButton
    }()

    private let scrollToEndButton: UIButton = {
        let scrollToEndButton = UIButton(type: .system)
        scrollToEndButton.accessibilityLabel = LocalizedString("posts-page.scroll-to-end-button.accessibility-label")
        scrollToEndButton.setTitle(LocalizedString("posts-page.scroll-to-end-button.title"), for: .normal)
        scrollToEndButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        return scrollToEndButton
    }()

    private let bottomBorder = HairlineView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        parentForumButton.addTarget(self, action: #selector(didTapParentForum), for: .primaryActionTriggered)
        previousPostsButton.addTarget(self, action: #selector(didTapPreviousPosts), for: .primaryActionTriggered)
        scrollToEndButton.addTarget(self, action: #selector(didTapScrollToEnd), for: .primaryActionTriggered)

        addSubview(stackView, constrainEdges: .all)
        addSubview(bottomBorder, constrainEdges: [.bottom, .left, .right])

        updateButtonsEnabled()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        stackView.spacing = 1 / max(traitCollection.displayScale, 1)
    }

    func themeDidChange(_ theme: Theme) {
        backgroundColor = theme["postsTopBarBackgroundColor"]
        bottomBorder.backgroundColor = theme["topBarBottomBorderColor"]
        for button in [parentForumButton, previousPostsButton, scrollToEndButton] {
            button.backgroundColor = theme["postsTopBarBackgroundColor"]
            button.setTitleColor(theme["postsTopBarTextColor"], for: .normal)
            button.setTitleColor(theme["postsTopBarTextColor"]?.withAlphaComponent(0.5), for: .disabled)
        }
    }

    private func updateButtonsEnabled() {
        parentForumButton.isEnabled = goToParentForum != nil
        previousPostsButton.isEnabled = showPreviousPosts != nil
        scrollToEndButton.isEnabled = scrollToEnd != nil
    }

    @objc private func didTapParentForum(_ sender: UIButton) {
        if UserDefaults.standard.enableHaptics {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        self.goToParentForum?()
    }
    var goToParentForum: (() -> Void)? {
        didSet { updateButtonsEnabled() }
    }

    @objc private func didTapPreviousPosts(_ sender: UIButton) {
        if UserDefaults.standard.enableHaptics {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        self.showPreviousPosts?()
    }
    var showPreviousPosts: (() -> Void)? {
        didSet { updateButtonsEnabled() }
    }

    @objc private func didTapScrollToEnd(_ sender: UIButton) {
        if UserDefaults.standard.enableHaptics {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        self.scrollToEnd?()
    }
    var scrollToEnd: (() -> Void)? {
        didSet { updateButtonsEnabled() }
    }

    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
