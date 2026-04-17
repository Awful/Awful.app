//  LiquidGlassTitleView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US

import UIKit

@available(iOS 26.0, *)
final class LiquidGlassTitleView: UIView {

    private static let lineSpacing: CGFloat = -2
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 8
    private static let phoneWidth: CGFloat = 320
    private static let defaultHeight: CGFloat = 56

    private var visualEffectView: UIVisualEffectView = {
        let effect = UIGlassEffect()
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    var title: String? {
        get { titleLabel.text }
        set {
            titleLabel.text = newValue
            updateTitleDisplay()
        }
    }
    
    var textColor: UIColor? {
        get { titleLabel.textColor }
        set { titleLabel.textColor = newValue }
    }
    
    var font: UIFont? {
        get { titleLabel.font }
        set {
            titleLabel.font = newValue
            updateTitleDisplay()
        }
    }

    func setUseDarkGlass(_ useDark: Bool) {
        visualEffectView.overrideUserInterfaceStyle = useDark ? .dark : .unspecified
    }
    
    private func updateTitleDisplay() {
        guard let text = titleLabel.text, !text.isEmpty else {
            invalidateIntrinsicContentSize()
            return
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = Self.lineSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: titleLabel.font ?? UIFont.preferredFont(forTextStyle: .callout)
        ]

        titleLabel.attributedText = NSAttributedString(string: text, attributes: attributes)
        invalidateIntrinsicContentSize()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        addSubview(visualEffectView)
        visualEffectView.contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: visualEffectView.contentView.topAnchor, constant: Self.verticalPadding),
            titleLabel.leadingAnchor.constraint(equalTo: visualEffectView.contentView.leadingAnchor, constant: Self.horizontalPadding),
            titleLabel.trailingAnchor.constraint(equalTo: visualEffectView.contentView.trailingAnchor, constant: -Self.horizontalPadding),
            titleLabel.bottomAnchor.constraint(equalTo: visualEffectView.contentView.bottomAnchor, constant: -Self.verticalPadding)
        ])

        isAccessibilityElement = false
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityTraits = .header
    }
    
    private var maxWidth: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let windowWidth = window?.bounds.width {
                return windowWidth - 400
            }
        }
        return Self.phoneWidth
    }

    private func contentFittingSize() -> CGSize {
        let maxW = maxWidth
        let labelMaxWidth = maxW - Self.horizontalPadding * 2
        let labelSize = titleLabel.sizeThatFits(CGSize(width: labelMaxWidth, height: .greatestFiniteMagnitude))
        let width = min(maxW, labelSize.width + Self.horizontalPadding * 2)
        let height = max(Self.defaultHeight, labelSize.height + Self.verticalPadding * 2)
        return CGSize(width: width, height: height)
    }

    override var intrinsicContentSize: CGSize {
        return contentFittingSize()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return contentFittingSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = bounds.height / 2
        visualEffectView.layer.cornerRadius = cornerRadius
        visualEffectView.layer.masksToBounds = true
        visualEffectView.layer.cornerCurve = .continuous
    }
}
