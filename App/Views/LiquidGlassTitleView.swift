//  LiquidGlassTitleView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US

import UIKit

@available(iOS 26.0, *)
final class LiquidGlassTitleView: UIView {

    private static let lineSpacing: CGFloat = -2
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 8
    private static let defaultWidth: CGFloat = 320
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
        guard let text = titleLabel.text, !text.isEmpty else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = Self.lineSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: titleLabel.font ?? UIFont.preferredFont(forTextStyle: .callout)
        ]

        titleLabel.attributedText = NSAttributedString(string: text, attributes: attributes)
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
    
    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = bounds.height / 2
        visualEffectView.layer.cornerRadius = cornerRadius
        visualEffectView.layer.masksToBounds = true
        visualEffectView.layer.cornerCurve = .continuous
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: Self.defaultWidth, height: Self.defaultHeight)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: Self.defaultWidth, height: Self.defaultHeight)
    }
}
