//  AttachmentPreviewView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AttachmentPreviewView")

/// A card-style view that shows a preview of an attached image with options to remove it.
final class AttachmentPreviewView: UIView {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.text = "Attachment"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let removeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    var onRemove: (() -> Void)?

    func updateTextColor(_ color: UIColor?) {
        titleLabel.textColor = color
        detailLabel.textColor = color?.withAlphaComponent(0.7)
    }

    func showResizingPlaceholder() {
        titleLabel.text = "Resizing Image..."
        detailLabel.text = "Please wait"
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
        // Background color will be set by the parent view controller based on theme
        layer.cornerRadius = 8

        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(removeButton)

        removeButton.addTarget(self, action: #selector(didTapRemove), for: .touchUpInside)

        NSLayoutConstraint.activate([
            // Image view on the left
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),

            // Title label
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -8),

            // Detail label below title
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            // Remove button on the right
            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 30),
            removeButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    @objc private func didTapRemove() {
        onRemove?()
    }

    func configure(with attachment: ForumAttachment) {
        titleLabel.text = "Attachment"
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
