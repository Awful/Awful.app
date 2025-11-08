//  VerticalPageNumberView.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import UIKit

final class VerticalPageNumberView: UIView {
    private let currentPageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFontForTextStyle(.footnote, fontName: nil, sizeAdjustment: 0, weight: .medium)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let totalPagesLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFontForTextStyle(.footnote, fontName: nil, sizeAdjustment: 0, weight: .medium)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let separatorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = " /"
        label.textAlignment = .center
        label.font = UIFont.preferredFontForTextStyle(.footnote, fontName: nil, sizeAdjustment: 0, weight: .medium)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    private let interRowSpacing: CGFloat = -2

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
        addSubview(currentPageLabel)
        addSubview(totalPagesLabel)
        addSubview(separatorLabel)
        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        NSLayoutConstraint.activate([
            currentPageLabel.topAnchor.constraint(equalTo: topAnchor),
            currentPageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            totalPagesLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            totalPagesLabel.centerXAnchor.constraint(equalTo: currentPageLabel.centerXAnchor),
            currentPageLabel.widthAnchor.constraint(equalTo: totalPagesLabel.widthAnchor),
            separatorLabel.centerYAnchor.constraint(equalTo: currentPageLabel.centerYAnchor),
            separatorLabel.leadingAnchor.constraint(equalTo: currentPageLabel.trailingAnchor),
            totalPagesLabel.topAnchor.constraint(equalTo: currentPageLabel.bottomAnchor, constant: interRowSpacing),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            leadingAnchor.constraint(lessThanOrEqualTo: currentPageLabel.leadingAnchor),
            trailingAnchor.constraint(greaterThanOrEqualTo: separatorLabel.trailingAnchor)
        ])
        currentPageLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        totalPagesLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        separatorLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        updateColors()
    }
    @objc private func handleTap() {
        onTap?()
    }
    private func updateDisplay() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        if currentPage == 0 {
            currentPageLabel.text = "?"
        } else {
            currentPageLabel.text = formatter.string(from: NSNumber(value: currentPage)) ?? "\(currentPage)"
        }
        if totalPages == 0 {
            totalPagesLabel.text = "?"
        } else {
            totalPagesLabel.text = formatter.string(from: NSNumber(value: totalPages)) ?? "\(totalPages)"
        }
        let currentPageText = currentPage == 0 ? "?" : "\(currentPage)"
        let totalPagesText = totalPages == 0 ? "?" : "\(totalPages)"
        accessibilityLabel = "Page \(currentPageText) of \(totalPagesText)"
        accessibilityHint = "Opens page picker"
    }
    
    private func updateColors() {
        currentPageLabel.textColor = textColor
        totalPagesLabel.textColor = textColor
        separatorLabel.textColor = textColor
    }
    override var intrinsicContentSize: CGSize {
        let currentSize = currentPageLabel.intrinsicContentSize
        let totalSize = totalPagesLabel.intrinsicContentSize
        let separatorSize = separatorLabel.intrinsicContentSize
        let width = max(currentSize.width, totalSize.width) + separatorSize.width
        let height = currentSize.height + totalSize.height + interRowSpacing
        
        return CGSize(width: width, height: height)
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
