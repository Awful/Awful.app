//  AttachmentEditView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A card-style view that shows existing attachment info with options to keep or delete it.
final class AttachmentEditView: UIView {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
        iv.backgroundColor = .secondarySystemFill
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.text = "Current Attachment"
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

    private let actionSegmentedControl: UISegmentedControl = {
        let items = ["Keep", "Delete"]
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    var onActionChanged: ((AttachmentAction) -> Void)?

    func updateTextColor(_ color: UIColor?) {
        titleLabel.textColor = color
        detailLabel.textColor = color?.withAlphaComponent(0.7)
    }

    func updateSegmentedControlColors(selectedColor: UIColor?) {
        // Set normal state text color to white
        actionSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)

        // Set selected state text color to white with the selected background color
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
        // Background color will be set by the parent view controller based on theme
        layer.cornerRadius = 8

        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(actionSegmentedControl)

        actionSegmentedControl.addTarget(self, action: #selector(actionChanged), for: .valueChanged)

        NSLayoutConstraint.activate([
            // Image view on the left
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),

            // Title label
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // Detail label below title
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            // Segmented control at the bottom
            actionSegmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            actionSegmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            actionSegmentedControl.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            actionSegmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    @objc private func actionChanged() {
        let action: AttachmentAction = actionSegmentedControl.selectedSegmentIndex == 0 ? .keep : .delete
        onActionChanged?(action)
    }

    func configure(filename: String, filesize: String?, image: UIImage? = nil) {
        titleLabel.text = "Current Attachment"
        if let filesize = filesize {
            detailLabel.text = "\(filename) • \(filesize)"
        } else {
            detailLabel.text = filename
        }

        if let image = image {
            // Display the actual attachment image
            imageView.image = image
            imageView.tintColor = nil
            imageView.contentMode = .scaleAspectFit
        } else {
            // Show a generic document icon as fallback
            let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .light)
            imageView.image = UIImage(systemName: "doc.fill", withConfiguration: config)
            imageView.tintColor = .tertiaryLabel
            imageView.contentMode = .center
        }
    }

    var selectedAction: AttachmentAction {
        return actionSegmentedControl.selectedSegmentIndex == 0 ? .keep : .delete
    }
}
