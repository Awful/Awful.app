//  AttachmentEditView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A card-style view that shows existing attachment info with options to keep or delete it.
final class AttachmentEditView: UIView, AttachmentCardView {

    let imageView: UIImageView = {
        let iv = AttachmentEditView.createImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    let titleLabel: UILabel = AttachmentEditView.createTitleLabel(text: LocalizedString("compose.attachment.edit-title"))

    let detailLabel: UILabel = AttachmentEditView.createDetailLabel()

    private let actionSegmentedControl: UISegmentedControl = {
        let items = [
            LocalizedString("compose.attachment.action-keep"),
            LocalizedString("compose.attachment.action-delete")
        ]
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    var onActionChanged: ((AttachmentAction) -> Void)?

    func updateSegmentedControlColors(selectedColor: UIColor?) {
        actionSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)

        if let selectedColor = selectedColor {
            actionSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            actionSegmentedControl.selectedSegmentTintColor = selectedColor
        }
    }

    enum AttachmentAction {
        case keep
        case delete
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
        addSubview(actionSegmentedControl)

        actionSegmentedControl.addTarget(self, action: #selector(actionChanged), for: .valueChanged)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AttachmentCardLayout.cardPadding),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: AttachmentCardLayout.cardPadding),
            imageView.widthAnchor.constraint(equalToConstant: AttachmentCardLayout.imageSize),
            imageView.heightAnchor.constraint(equalToConstant: AttachmentCardLayout.imageSize),

            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: AttachmentCardLayout.imageSpacing),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: AttachmentCardLayout.labelTopPadding),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AttachmentCardLayout.cardPadding),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AttachmentCardLayout.titleDetailSpacing),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            actionSegmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AttachmentCardLayout.cardPadding),
            actionSegmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AttachmentCardLayout.cardPadding),
            actionSegmentedControl.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: AttachmentCardLayout.imageSpacing),
            actionSegmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AttachmentCardLayout.cardPadding)
        ])
    }

    @objc private func actionChanged() {
        let action: AttachmentAction = actionSegmentedControl.selectedSegmentIndex == 0 ? .keep : .delete
        onActionChanged?(action)
    }

    func configure(filename: String, filesize: String?, image: UIImage? = nil) {
        titleLabel.text = LocalizedString("compose.attachment.edit-title")
        if let filesize = filesize {
            detailLabel.text = "\(filename) • \(filesize)"
        } else {
            detailLabel.text = filename
        }

        if let image = image {
            imageView.image = image
            imageView.tintColor = nil
            imageView.contentMode = .scaleAspectFit
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .light)
            imageView.image = UIImage(systemName: "doc.fill", withConfiguration: config)
            imageView.tintColor = .tertiaryLabel
            imageView.contentMode = .center
        }
    }
}
