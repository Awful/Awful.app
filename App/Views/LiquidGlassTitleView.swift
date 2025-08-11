//  LiquidGlassTitleView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A custom navigation title view with iOS 26's liquid glass effect in a capsule shape.
@available(iOS 26.0, *)
final class LiquidGlassTitleView: UIView {
    
    // MARK: - UI Elements
    
    private var visualEffectView: UIVisualEffectView = {
        // Use iOS 26's new UIGlassEffect for authentic Liquid Glass appearance
        let effect = UIGlassEffect()
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var visualEffectViewConstraints: [NSLayoutConstraint] = []
    private var titleLabelConstraints: [NSLayoutConstraint] = []
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return label
    }()
    
    // MARK: - Properties
    
    var title: String? {
        get { titleLabel.text }
        set {
            titleLabel.text = newValue
            invalidateIntrinsicContentSize()
            setNeedsLayout()
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
            updateLineSpacing()
        }
    }
    
    /// Sets whether to use dark glass appearance (useful for light mode themes)
    func setUseDarkGlass(_ useDark: Bool) {
        // Deactivate existing constraints
        NSLayoutConstraint.deactivate(visualEffectViewConstraints + titleLabelConstraints)
        
        // Remove old visual effect view
        visualEffectView.removeFromSuperview()
        
        // Create new visual effect view with appropriate style
        let newEffectView = UIVisualEffectView()
        newEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set the interface style before applying the effect
        newEffectView.overrideUserInterfaceStyle = useDark ? .dark : .unspecified
        
        // Apply the glass effect after setting the style
        let effect = UIGlassEffect()
        newEffectView.effect = effect
        
        // Replace the visual effect view
        visualEffectView = newEffectView
        
        // Re-setup view hierarchy and constraints
        setupVisualEffectViewAndConstraints()
        
        // Re-apply corner radius for capsule shape
        setNeedsLayout()
    }
    
    private func setupVisualEffectViewAndConstraints() {
        // Add visual effect view
        addSubview(visualEffectView)
        
        // Add title label to the content view of the visual effect
        visualEffectView.contentView.addSubview(titleLabel)
        
        // Create constraints
        visualEffectViewConstraints = [
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        
        titleLabelConstraints = [
            titleLabel.topAnchor.constraint(equalTo: visualEffectView.contentView.topAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: visualEffectView.contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: visualEffectView.contentView.trailingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: visualEffectView.contentView.bottomAnchor, constant: -6)
        ]
        
        // Activate constraints
        NSLayoutConstraint.activate(visualEffectViewConstraints + titleLabelConstraints)
        
        // Configure appearance
        updateLineSpacing()
        
        // Make view interactive (for accessibility)
        isAccessibilityElement = false
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityTraits = .header
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        setupVisualEffectViewAndConstraints()
    }
    
    private func updateLineSpacing() {
        guard let text = titleLabel.text, !text.isEmpty else { return }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        // Tighter line spacing than default
        paragraphStyle.lineSpacing = -2
        paragraphStyle.lineBreakMode = .byTruncatingTail
        
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: titleLabel.font ?? UIFont.preferredFont(forTextStyle: .callout)
        ]
        
        titleLabel.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Apply capsule shape with corner radius
        let cornerRadius = bounds.height / 2
        visualEffectView.layer.cornerRadius = cornerRadius
        visualEffectView.layer.masksToBounds = true
        
        // Apply corner configuration for proper glass capsule shape
        visualEffectView.layer.cornerCurve = .continuous
    }
    
    override var intrinsicContentSize: CGSize {
        let labelSize = titleLabel.intrinsicContentSize
        // Add padding: 12 points horizontal on each side, 6 points vertical on each side
        let width = labelSize.width + 24
        let height = labelSize.height + 12
        
        // Ensure minimum size for the capsule to look good
        return CGSize(
            width: max(width, 100),
            height: max(height, 32)
        )
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelSize = titleLabel.sizeThatFits(CGSize(width: size.width - 24, height: size.height - 12))
        return CGSize(
            width: min(labelSize.width + 24, size.width),
            height: min(labelSize.height + 12, size.height)
        )
    }
}