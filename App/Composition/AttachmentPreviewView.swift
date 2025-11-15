//  AttachmentPreviewView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AttachmentPreviewView")

/// A card-style view that shows a preview of an attached image with options to remove it.
final class AttachmentPreviewView: UIView, AttachmentCardView {

    let imageView: UIImageView = {
        let iv = AttachmentPreviewView.createImageView()
        iv.contentMode = .scaleAspectFill
        return iv
    }()

    let titleLabel: UILabel = AttachmentPreviewView.createTitleLabel(text: LocalizedString("compose.attachment.preview-title"))

    let detailLabel: UILabel = AttachmentPreviewView.createDetailLabel()

    private let removeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    var onRemove: (() -> Void)?

    func showResizingPlaceholder() {
        titleLabel.text = LocalizedString("compose.attachment.resizing-title")
        detailLabel.text = LocalizedString("compose.attachment.resizing-message")
        imageView.image = nil
        imageView.backgroundColor = .secondarySystemFill
    }

    init() {
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        configureCardAppearance()

        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(removeButton)

        removeButton.addTarget(self, action: #selector(didTapRemove), for: .touchUpInside)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AttachmentCardLayout.cardPadding),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: AttachmentCardLayout.cardPadding),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AttachmentCardLayout.cardPadding),
            imageView.widthAnchor.constraint(equalToConstant: AttachmentCardLayout.imageSize),
            imageView.heightAnchor.constraint(equalToConstant: AttachmentCardLayout.imageSize),

            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: AttachmentCardLayout.imageSpacing),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: AttachmentCardLayout.labelTopPadding),
            titleLabel.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -8),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AttachmentCardLayout.titleDetailSpacing),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AttachmentCardLayout.cardPadding),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: AttachmentCardLayout.actionButtonSize),
            removeButton.heightAnchor.constraint(equalToConstant: AttachmentCardLayout.actionButtonSize)
        ])
    }

    @objc private func didTapRemove() {
        onRemove?()
    }

    func configure(with attachment: ForumAttachment) {
        titleLabel.text = LocalizedString("compose.attachment.preview-title")
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
