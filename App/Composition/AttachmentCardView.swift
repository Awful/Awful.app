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

/// Base class for attachment card views with common UI elements and styling
class AttachmentCardView: UIView {

    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = AttachmentCardLayout.imageCornerRadius
        iv.backgroundColor = .secondarySystemFill
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureCardAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureCardAppearance()
    }

    /// Updates the text color for title and detail labels
    func updateTextColor(_ color: UIColor?) {
        titleLabel.textColor = color
        detailLabel.textColor = color?.withAlphaComponent(0.7)
    }

    /// Configures the card's appearance with standard styling
    private func configureCardAppearance() {
        backgroundColor = .clear
        layer.cornerRadius = AttachmentCardLayout.cardCornerRadius
    }
}
