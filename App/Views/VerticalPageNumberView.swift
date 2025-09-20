//  VerticalPageNumberView.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import UIKit

/// A custom view that displays page numbers in a vertical layout inspired by SwiftUI VStack.
/// Shows current page number over total pages, mimicking the LiquidGlassBottomBar design.
final class VerticalPageNumberView: UIView {
    
    // MARK: - UI Elements
    
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
    
    // MARK: - Properties
    
    /// Tighten the visual gap between the two number rows. Negative is intentional
    /// to compensate for UILabel top/bottom padding so the two lines feel closer
    /// together, similar to compact line spacing.
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
    
    /// Callback for when the view is tapped
    var onTap: (() -> Void)?
    
    // MARK: - Initialization
    
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
    
    // MARK: - Setup
    
    private func setupViews() {
        // Add subviews
        addSubview(currentPageLabel)
        addSubview(totalPagesLabel)
        addSubview(separatorLabel)
        
        // Enable user interaction and add tap gesture
        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        // Set up constraints for centered layout within the view
        NSLayoutConstraint.activate([
            // Current page label at top, horizontally centered
            currentPageLabel.topAnchor.constraint(equalTo: topAnchor),
            currentPageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            // Total pages label at bottom, aligned with current page label
            totalPagesLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            totalPagesLabel.centerXAnchor.constraint(equalTo: currentPageLabel.centerXAnchor),
            
            // Ensure both number labels have the same width for proper alignment
            currentPageLabel.widthAnchor.constraint(equalTo: totalPagesLabel.widthAnchor),
            
            // Separator positioned immediately after the number labels
            separatorLabel.centerYAnchor.constraint(equalTo: currentPageLabel.centerYAnchor),
            separatorLabel.leadingAnchor.constraint(equalTo: currentPageLabel.trailingAnchor),
            
            // Control the vertical spacing between the two rows; negative value intentionally
            // tightens the gap to better match the compact toolbar design.
            totalPagesLabel.topAnchor.constraint(equalTo: currentPageLabel.bottomAnchor, constant: interRowSpacing),
            
            // Set a minimum width to ensure proper centering in toolbar
            widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            
            // View bounds accommodate all content with proper padding
            leadingAnchor.constraint(lessThanOrEqualTo: currentPageLabel.leadingAnchor),
            trailingAnchor.constraint(greaterThanOrEqualTo: separatorLabel.trailingAnchor)
        ])
        
        // Set content compression resistance to prevent shrinking
        currentPageLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        totalPagesLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        separatorLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        updateColors()
    }
    
    // MARK: - Actions
    
    @objc private func handleTap() {
        onTap?()
    }
    
    // MARK: - Updates
    
    private func updateDisplay() {
        // Format numbers without grouping separators, like the SwiftUI example
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        
        // Handle special case where currentPage is 0 (unknown page)
        if currentPage == 0 {
            currentPageLabel.text = "?"
        } else {
            currentPageLabel.text = formatter.string(from: NSNumber(value: currentPage)) ?? "\(currentPage)"
        }
        
        // Handle special case where totalPages is 0 (unknown total)
        if totalPages == 0 {
            totalPagesLabel.text = "?"
        } else {
            totalPagesLabel.text = formatter.string(from: NSNumber(value: totalPages)) ?? "\(totalPages)"
        }
        
        // Update accessibility
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
    
    // MARK: - Intrinsic Content Size
    
    override var intrinsicContentSize: CGSize {
        let currentSize = currentPageLabel.intrinsicContentSize
        let totalSize = totalPagesLabel.intrinsicContentSize
        let separatorSize = separatorLabel.intrinsicContentSize
        
        // Width is the wider number label plus separator
        let width = max(currentSize.width, totalSize.width) + separatorSize.width
        let height = currentSize.height + totalSize.height + interRowSpacing
        
        return CGSize(width: width, height: height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Force the view to be as small as possible to minimize UIBarButtonItem padding
        invalidateIntrinsicContentSize()
    }
    
    // MARK: - Trait Collection Changes
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            // Font size changed, invalidate intrinsic content size
            invalidateIntrinsicContentSize()
        }
    }
}
