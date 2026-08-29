//  LiquidGlassTitleView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US

import UIKit

@available(iOS 26.0, *)
final class LiquidGlassTitleView: UIView {

    private static let lineSpacing: CGFloat = -2
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 8
    private static let minVerticalPadding: CGFloat = 3
    private static let phoneWidth: CGFloat = 320
    private static let defaultHeight: CGFloat = 56
    private static let maxAncestorUnclipDepth = 8
    // Mid-transition the bar sits deeper: transition hosts add ~3 levels.
    private static let maxBarSearchDepth = 16

    private var visualEffectView: UIVisualEffectView = {
        let effect = UIGlassEffect()
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        // Capsule shape must come from cornerConfiguration: glass ignores
        // layer.cornerRadius (FB18629279), and clipping a glass view corrupts
        // its shadow into a grey wash (see PostsPageTopBarLiquidGlass.GlassButton).
        view.cornerConfiguration = .capsule()
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.baselineAdjustment = .alignCenters
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    /// The height the navigation bar most recently offered via `sizeThatFits(_:)`
    /// (or, failing that, the superview's height observed in `layoutSubviews`).
    /// The capsule never reports a height beyond this. Overhanging the bar's
    /// content area is fine — see `unclipAncestors()` for how the overhang
    /// survives transitions unclipped.
    private var grantedHeight: CGFloat? {
        didSet {
            if grantedHeight != oldValue {
                invalidateIntrinsicContentSize()
            }
        }
    }

    var title: String? {
        get { titleLabel.text }
        set {
            guard newValue != titleLabel.text else { return }
            titleLabel.text = newValue
            largeContentTitle = newValue
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
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: titleLabel.font ?? UIFont.preferredFont(forTextStyle: .callout)
        ]

        titleLabel.attributedText = NSAttributedString(string: text, attributes: attributes)
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
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

        // Preferred 8pt vertical padding that relaxes (down to 3pt) when the
        // bar grants less height than the capsule would like.
        let preferredTopPadding = titleLabel.topAnchor.constraint(
            equalTo: visualEffectView.contentView.topAnchor, constant: Self.verticalPadding)
        preferredTopPadding.priority = .defaultHigh

        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.centerYAnchor.constraint(equalTo: visualEffectView.contentView.centerYAnchor),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: visualEffectView.contentView.topAnchor, constant: Self.minVerticalPadding),
            preferredTopPadding,
            titleLabel.leadingAnchor.constraint(equalTo: visualEffectView.contentView.leadingAnchor, constant: Self.horizontalPadding),
            titleLabel.trailingAnchor.constraint(equalTo: visualEffectView.contentView.trailingAnchor, constant: -Self.horizontalPadding)
        ])

        isAccessibilityElement = false
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityTraits = .header

        // At accessibility sizes the title drops to a single truncated line;
        // long-press then shows the full title in the large content viewer.
        showsLargeContentViewer = true
        addInteraction(UILargeContentViewerInteraction())

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: LiquidGlassTitleView, _) in
            self.updateTitleDisplay()
        }
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

        // Prefer two lines, but drop to one when the bar's granted height
        // can't fit two even at minimum padding.
        var lines = 2
        var labelSize = measuredLabelSize(maxWidth: labelMaxWidth, lines: lines)
        if let granted = grantedHeight,
           labelSize.height + Self.minVerticalPadding * 2 > granted {
            lines = 1
            labelSize = measuredLabelSize(maxWidth: labelMaxWidth, lines: lines)
        }
        if titleLabel.numberOfLines != lines {
            titleLabel.numberOfLines = lines
        }

        let width = min(maxW, labelSize.width + Self.horizontalPadding * 2)
        var height = max(Self.defaultHeight, labelSize.height + Self.verticalPadding * 2)
        if let granted = grantedHeight {
            height = min(height, granted)
        }
        return CGSize(width: width, height: height)
    }

    private func measuredLabelSize(maxWidth: CGFloat, lines: Int) -> CGSize {
        let previousLines = titleLabel.numberOfLines
        titleLabel.numberOfLines = lines
        let size = titleLabel.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        titleLabel.numberOfLines = previousLines
        return size
    }

    override var intrinsicContentSize: CGSize {
        return contentFittingSize()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if size.height.isFinite, size.height > 0 {
            grantedHeight = size.height
        }
        var fit = contentFittingSize()
        if size.width.isFinite, size.width > 0 {
            fit.width = min(fit.width, size.width)
        }
        if size.height.isFinite, size.height > 0 {
            fit.height = min(fit.height, size.height)
        }
        return fit
    }

    /// The capsule deliberately overhangs the bar's content area, so any
    /// clipping between it and the screen shears its top off at the bar's
    /// top edge (and corrupts the glass shadow into a grey wash — see the
    /// cornerConfiguration comment above). Two distinct places clip:
    ///
    /// 1. Transient containers UIKit hosts the live view in (seen on
    ///    interactive pops) — handled by walking our own superview chain.
    /// 2. The animated push/pop, where what's on screen is not the live view
    ///    at all: the bar renders a `_UIPortalView` COPY of its content
    ///    inside a clipped sibling container (`ViewControllerMatchingView`),
    ///    unreachable from our ancestor chain — handled by sweeping the
    ///    bar's subtree and un-clipping just the portal's ancestors, which
    ///    leaves the bar buttons' own (legitimate) clipping untouched.
    ///
    /// All of these are transient, so clipping is never restored.
    private func unclipAncestors() {
        var ancestor = superview
        var depth = 0
        var bar: UINavigationBar?
        while let view = ancestor, depth < Self.maxBarSearchDepth {
            if let navigationBar = view as? UINavigationBar {
                bar = navigationBar
                break
            }
            if depth < Self.maxAncestorUnclipDepth {
                if view.clipsToBounds { view.clipsToBounds = false }
                if view.layer.masksToBounds { view.layer.masksToBounds = false }
            }
            ancestor = view.superview
            depth += 1
        }
        if let bar {
            unclipPortalAncestors(in: bar)
        }
    }

    @discardableResult
    private func unclipPortalAncestors(in view: UIView) -> Bool {
        var containsPortal = NSStringFromClass(type(of: view)).contains("PortalView")
        for subview in view.subviews {
            if unclipPortalAncestors(in: subview) {
                containsPortal = true
            }
        }
        if containsPortal {
            if view.clipsToBounds { view.clipsToBounds = false }
            if view.layer.masksToBounds { view.layer.masksToBounds = false }
        }
        return containsPortal
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard superview != nil else { return }
        unclipAncestors()
        // Transition containers (and the portal copy) can be assembled just
        // after we're reparented, which doesn't re-fire didMoveToSuperview;
        // re-walk next pass.
        DispatchQueue.main.async { [weak self] in self?.unclipAncestors() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Safety net for sizing paths that never offer a bounded height: the
        // superview is the bar's content view, whose height is the space
        // actually available.
        if let superview,
           superview.bounds.height > 0,
           bounds.height > superview.bounds.height,
           grantedHeight != superview.bounds.height {
            grantedHeight = superview.bounds.height
            superview.setNeedsLayout()
        }

        // UIKit can re-enable clipping mid-transition (interactive pops
        // relayout the bar per frame), so reassert every layout pass.
        unclipAncestors()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // maxWidth depends on the window (iPad); re-measure once attached.
        if window != nil {
            invalidateIntrinsicContentSize()
            superview?.setNeedsLayout()
            unclipAncestors()
        }
    }
}
