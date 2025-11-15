//  AttachmentCardView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Shared layout constants for attachment card views
enum AttachmentCardLayout {
    static let imageSize: CGFloat = 60
    static let imageCornerRadius: CGFloat = 4
    static let cardCornerRadius: CGFloat = 8
    static let cardPadding: CGFloat = 12
    static let imageSpacing: CGFloat = 12
    static let labelTopPadding: CGFloat = 16
    static let titleDetailSpacing: CGFloat = 4
    static let actionButtonSize: CGFloat = 30
}

/// Protocol defining common behavior for attachment card views
protocol AttachmentCardView: UIView {
    var imageView: UIImageView { get }
    var titleLabel: UILabel { get }
    var detailLabel: UILabel { get }

    func updateTextColor(_ color: UIColor?)
}

extension AttachmentCardView {
    /// Default implementation for updating text colors
    func updateTextColor(_ color: UIColor?) {
        titleLabel.textColor = color
        detailLabel.textColor = color?.withAlphaComponent(0.7)
    }

    /// Creates a standard image view for attachment cards
    static func createImageView() -> UIImageView {
        let iv = UIImageView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = AttachmentCardLayout.imageCornerRadius
        iv.backgroundColor = .secondarySystemFill
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }

    /// Creates a standard title label for attachment cards
    static func createTitleLabel(text: String) -> UILabel {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    /// Creates a standard detail label for attachment cards
    static func createDetailLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    /// Configures the card's appearance with standard styling
    func configureCardAppearance() {
        backgroundColor = .clear
        layer.cornerRadius = AttachmentCardLayout.cardCornerRadius
    }
}
