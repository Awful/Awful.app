//  PageNumberView.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import AwfulTheming
import UIKit

final class PageNumberView: UIView {

    private static let minWidth: CGFloat = 60
    private static let heightModern: CGFloat = 39  // iOS 26+
    private static let heightLegacy: CGFloat = 44  // iOS < 26

    /// The page count deliberately ignores Dynamic Type: at larger text sizes it grows wide
    /// enough that iOS 27 evicts the neighbouring toolbar buttons into an overflow menu. This
    /// is the default body size, so nothing changes at the default text setting; the large
    /// content viewer (long-press) covers accessibility sizes.
    static let fontPointSize: CGFloat = 17

    /// The fixed-size font shared by the pill and the plain-title page item, in the theme's
    /// rounded design when it asks for one (matching `UIFont.preferredFontForTextStyle`).
    static func font() -> UIFont {
        let font = UIFont.systemFont(ofSize: fontPointSize, weight: .regular)
        guard Theme.defaultTheme().roundedFonts,
              let rounded = font.fontDescriptor.withDesign(.rounded) else { return font }
        return UIFont(descriptor: rounded, size: fontPointSize)
    }

    private static let currentHeight: CGFloat = {
        if #available(iOS 26.0, *) {
            return heightModern
        } else {
            return heightLegacy
        }
    }()

    private let pageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = false
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
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

        pageLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        showsLargeContentViewer = true
        addInteraction(UILargeContentViewerInteraction())

        applyFont()
        updateColors()
    }

    private func applyFont() {
        pageLabel.font = Self.font()
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
        largeContentTitle = accessibilityLabel
    }

    private func updateColors() {
        pageLabel.textColor = textColor
    }

    func updateTheme() {
        applyFont()
    }
    
    override var intrinsicContentSize: CGSize {
        let labelSize = pageLabel.intrinsicContentSize
        return CGSize(width: max(labelSize.width, Self.minWidth), height: Self.currentHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}
