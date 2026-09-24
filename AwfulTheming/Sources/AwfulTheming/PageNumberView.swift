//  PageNumberView.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import UIKit

/// The "current / total" page counter shown between the paging arrows of a bottom toolbar.
///
/// On iOS 26+ it's the bar item's custom view whether or not Liquid Glass is on: a plain-title
/// `UIBarButtonItem` is sized by UIKit, which grows it with Dynamic Type until iOS 27 evicts the
/// neighbouring toolbar buttons into an overflow menu. This view keeps a fixed-size font, so its
/// width stays ours. With Reduce Liquid Glass the item's `hidesSharedBackground` leaves it flat.
public final class PageNumberView: UIView {

    private static let minWidth: CGFloat = 60
    private static let heightModern: CGFloat = 39  // iOS 26+
    private static let heightLegacy: CGFloat = 44  // iOS < 26

    /// The page count deliberately ignores Dynamic Type: at larger text sizes it grows wide
    /// enough that iOS 27 evicts the neighbouring toolbar buttons into an overflow menu. This
    /// is the default body size, so nothing changes at the default text setting; the large
    /// content viewer (long-press) covers accessibility sizes.
    public static let fontPointSize: CGFloat = 17

    /// The fixed-size font shared by the pill and the plain-title page item, in the theme's
    /// rounded design when it asks for one (matching `UIFont.preferredFontForTextStyle`).
    public static func font() -> UIFont {
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

    public var currentPage: Int = 1 {
        didSet {
            updateDisplay()
        }
    }

    public var totalPages: Int = 1 {
        didSet {
            updateDisplay()
        }
    }

    public var textColor: UIColor = .label {
        didSet {
            updateColors()
        }
    }

    /// Stands in for the bar item's `isEnabled`, which a custom view doesn't pick up: dims the
    /// label and ignores taps.
    public var isEnabled: Bool = true {
        didSet {
            guard isEnabled != oldValue else { return }
            updateColors()
            if isEnabled {
                accessibilityTraits.remove(.notEnabled)
            } else {
                accessibilityTraits.insert(.notEnabled)
            }
        }
    }

    public var onTap: (() -> Void)?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        updateDisplay()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        updateDisplay()
    }

    /// Wraps the view for use as a `UIBarButtonItem.customView`, with a point of breathing room
    /// on each side so the item's platter doesn't clip it.
    public func makeBarButtonItemContainer() -> UIView {
        let containerView = UIView()
        containerView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: widthAnchor, constant: 2),
            containerView.heightAnchor.constraint(equalTo: heightAnchor, constant: 2)
        ])
        return containerView
    }

    private func setupViews() {
        addSubview(pageLabel)
        isUserInteractionEnabled = true
        isAccessibilityElement = true
        accessibilityTraits = .button
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
        guard isEnabled else { return }
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
        // Matches the dimming UIKit gives a disabled bar button item's title.
        pageLabel.textColor = isEnabled ? textColor : textColor.withAlphaComponent(0.35)
    }

    public func updateTheme() {
        applyFont()
    }

    public override var intrinsicContentSize: CGSize {
        let labelSize = pageLabel.intrinsicContentSize
        return CGSize(width: max(labelSize.width, Self.minWidth), height: Self.currentHeight)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}
