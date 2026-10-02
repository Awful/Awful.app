//  AttachmentPreviewView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AttachmentPreviewView")

/// A card-style view that shows a preview of a new forum attachment, optionally with a button to remove it.
final class AttachmentPreviewView: AttachmentCardView {

    private let removeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// Explains where the attachment ends up. Hidden while resizing.
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.text = LocalizedString("compose.attachment.preview-subtitle")
        return label
    }()

    private lazy var labelStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = AttachmentCardLayout.titleDetailSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    var onRemove: (() -> Void)?

    /// False for read-only cards, such as on the preview screens.
    var showsRemoveButton = true {
        didSet { removeButton.isHidden = !showsRemoveButton }
    }

    func showResizingPlaceholder() {
        titleLabel.text = LocalizedString("compose.attachment.resizing-title")
        subtitleLabel.isHidden = true
        detailLabel.text = LocalizedString("compose.attachment.resizing-message")
        imageView.image = nil
        imageView.backgroundColor = .secondarySystemFill
    }

    /// A card for screens that only show the attachment, such as the post previews.
    static func readOnly(showing attachment: ForumAttachment) -> AttachmentPreviewView {
        let card = AttachmentPreviewView()
        card.showsRemoveButton = false
        card.configure(with: attachment)
        return card
    }

    /// Positions a read-only card just above a scroll view's content, in the
    /// `AttachmentCardLayout.previewBlockHeight` band that the scroll view's top content inset leaves.
    func layOutAboveContent(in view: UIView) {
        let x = view.safeAreaInsets.left + AttachmentCardLayout.previewSideMargin
        frame = CGRect(
            x: x,
            y: -AttachmentCardLayout.previewVerticalMargin - AttachmentCardLayout.previewHeight,
            width: view.bounds.width - x - view.safeAreaInsets.right - AttachmentCardLayout.previewSideMargin,
            height: AttachmentCardLayout.previewHeight
        )
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        imageView.contentMode = .scaleAspectFill
        titleLabel.text = LocalizedString("compose.attachment.preview-title")

        addSubview(imageView)
        addSubview(labelStack)
        addSubview(removeButton)

        removeButton.addTarget(self, action: #selector(didTapRemove), for: .touchUpInside)

        // Below required priority so the card can collapse to zero height while hidden.
        let imageBottomConstraint = imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AttachmentCardLayout.cardPadding)
        imageBottomConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AttachmentCardLayout.cardPadding),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: AttachmentCardLayout.cardPadding),
            imageBottomConstraint,
            imageView.widthAnchor.constraint(equalToConstant: AttachmentCardLayout.imageSize),
            imageView.heightAnchor.constraint(equalToConstant: AttachmentCardLayout.imageSize),

            labelStack.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: AttachmentCardLayout.imageSpacing),
            labelStack.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            labelStack.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -8),

            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AttachmentCardLayout.cardPadding),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: AttachmentCardLayout.actionButtonSize),
            removeButton.heightAnchor.constraint(equalToConstant: AttachmentCardLayout.actionButtonSize),
        ])
    }

    @objc private func didTapRemove() {
        onRemove?()
    }

    override func updateTextColor(_ color: UIColor?) {
        super.updateTextColor(color)
        subtitleLabel.textColor = color?.withAlphaComponent(0.7)
    }

    /// Styles the card as a bordered panel in the theme's colors.
    func applyTheme(_ theme: Theme) {
        backgroundColor = theme["backgroundColor"]
        layer.borderColor = (theme["listSecondaryTextColor"] as UIColor?)?.cgColor
        layer.borderWidth = 1
        updateTextColor(theme["listTextColor"])
    }

    func configure(with attachment: ForumAttachment) {
        titleLabel.text = LocalizedString("compose.attachment.preview-title")
        subtitleLabel.isHidden = false
        imageView.backgroundColor = .clear
        imageView.image = attachment.image

        if let image = attachment.image {
            let width = Int(image.size.width * image.scale)
            let height = Int(image.size.height * image.scale)

            do {
                let (data, _, _) = try attachment.imageData()
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                let sizeString = formatter.string(fromByteCount: Int64(data.count))
                detailLabel.text = "\(width) × \(height) • \(sizeString)"
            } catch {
                logger.error("Failed to get image data for attachment preview: \(error.localizedDescription)")
                detailLabel.text = "\(width) × \(height)"
            }
        }
    }
}
