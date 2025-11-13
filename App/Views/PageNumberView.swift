//  PageNumberView.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import UIKit

final class PageNumberView: UIView {
    private let pageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFontForTextStyle(.body, sizeAdjustment: 0, weight: .regular)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    var currentPage: Int = 1 {
        didSet {
            updateDisplay()
        }
    }

    var totalPages: Int = 1 {
        didSet {
            updateDisplay()
        }
    }

    var textColor: UIColor = {
        return .label
    }() {
        didSet {
            updateColors()
        }
    }

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        updateDisplay()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        updateDisplay()
    }

    private func setupViews() {
        addSubview(pageLabel)
        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)

        NSLayoutConstraint.activate([
            pageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            pageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            pageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            pageLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            heightAnchor.constraint(equalToConstant: {
                if #available(iOS 26.0, *) {
                    return 39
                } else {
                    return 44
                }
            }())
        ])

        pageLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        updateColors()
    }

    @objc private func handleTap() {
        onTap?()
    }

    private func updateDisplay() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false

        let currentPageText: String
        if currentPage == 0 {
            currentPageText = "?"
        } else {
            currentPageText = formatter.string(from: NSNumber(value: currentPage)) ?? "\(currentPage)"
        }

        let totalPagesText: String
        if totalPages == 0 {
            totalPagesText = "?"
        } else {
            totalPagesText = formatter.string(from: NSNumber(value: totalPages)) ?? "\(totalPages)"
        }

        pageLabel.text = "\(currentPageText) / \(totalPagesText)"
        accessibilityLabel = "Page \(currentPageText) of \(totalPagesText)"
        accessibilityHint = "Opens page picker"
    }

    private func updateColors() {
        pageLabel.textColor = textColor
    }

    override var intrinsicContentSize: CGSize {
        let labelSize = pageLabel.intrinsicContentSize
        let height: CGFloat
        if #available(iOS 26.0, *) {
            height = 39
        } else {
            height = 44
        }
        return CGSize(width: max(labelSize.width, 60), height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            invalidateIntrinsicContentSize()
        }
    }
}
