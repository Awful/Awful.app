//  PageNumberView.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import UIKit

final class PageNumberView: UIView {

    private static let minWidth: CGFloat = 60
    private static let heightModern: CGFloat = 39  // iOS 26+
    private static let heightLegacy: CGFloat = 44  // iOS < 26

    private static var currentHeight: CGFloat {
        if #available(iOS 26.0, *) {
            return heightModern
        } else {
            return heightLegacy
        }
    }

    private let pageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .body)
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

    var textColor: UIColor = .label {
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
            widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minWidth),
            heightAnchor.constraint(equalToConstant: Self.currentHeight)
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

    func updateTheme() {
        pageLabel.font = UIFont.preferredFontForTextStyle(.body, sizeAdjustment: 0, weight: .regular)
    }
    
    override var intrinsicContentSize: CGSize {
        let labelSize = pageLabel.intrinsicContentSize
        return CGSize(width: max(labelSize.width, Self.minWidth), height: Self.currentHeight)
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
