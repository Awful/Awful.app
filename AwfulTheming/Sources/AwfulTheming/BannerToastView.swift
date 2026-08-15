//  BannerToastView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A transient message pinned to the bottom of a host view, above the keyboard, with an optional action. Tap the banner to dismiss it early; it auto-dismisses after a few seconds.
public final class BannerToastView: UIView {

    /// How the banner offers its action, if it has one.
    public enum Action {
        /// A button after the message, e.g. "Use Original".
        case button(title: String)
        /// A tappable run within the message itself, e.g. "has a poll" in "This thread has a poll".
        /// `actionName` is what VoiceOver offers, since the link text on its own ("has a poll") doesn't read as something you can do.
        case link(text: String, actionName: String)
    }

    /// Shows a banner near the bottom of `hostView`, above the keyboard when one is up, replacing any banner already shown there.
    /// Pass `action`/`onAction` for a tappable action; omit both for a plain informational toast.
    /// Pass `bottomInset` to clear chrome the safe area doesn't know about, such as a toolbar laid out inside a subview.
    @discardableResult
    public static func show(
        in hostView: UIView,
        theme: Theme,
        message: String,
        action: Action? = nil,
        duration: TimeInterval = 5,
        bottomInset: CGFloat = 0,
        onAction: (() -> Void)? = nil
    ) -> BannerToastView {
        for existing in hostView.subviews.compactMap({ $0 as? BannerToastView }) {
            existing.dismiss(animated: false)
        }

        let banner = BannerToastView(theme: theme, message: message, action: action, onAction: onAction)
        banner.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(banner)

        // Sit above whichever comes first: the keyboard (its layout guide includes any input accessory view) or the bottom safe area. The lower-priority equality pulls the banner as far down as those allow.
        let restToBottom = banner.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -8 - bottomInset)
        restToBottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            banner.bottomAnchor.constraint(lessThanOrEqualTo: hostView.keyboardLayoutGuide.topAnchor, constant: -8),
            banner.bottomAnchor.constraint(lessThanOrEqualTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -8 - bottomInset),
            restToBottom,
            // Centred on the safe area rather than the host's full width: on iPad an open sidebar
            // sits over the left of the posts view and shows up as a left safe-area inset, so
            // centring on `hostView` would push the banner off to the side. Constraining to the
            // guide also means it re-centres by itself as the sidebar comes and goes. On iPhone the
            // horizontal insets are symmetric, so this is the same as before.
            banner.centerXAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.centerXAnchor),
            banner.leadingAnchor.constraint(greaterThanOrEqualTo: hostView.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(lessThanOrEqualTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
        ])

        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: 8)
        UIView.animate(withDuration: 0.25) {
            banner.alpha = 1
            banner.transform = .identity
        }

        let dismissal = DispatchWorkItem { [weak banner] in
            banner?.dismiss()
        }
        banner.scheduledDismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: dismissal)

        UIAccessibility.post(notification: .announcement, argument: message)
        return banner
    }

    private let onAction: (() -> Void)?
    private var scheduledDismissal: DispatchWorkItem?
    /// The label carrying the message, kept around so a tap can be mapped back onto `linkRange`.
    private let label = UILabel()
    /// The run of `label`'s text that acts as the action, when the banner was built with `.link`.
    private var linkRange: NSRange?
    /// The glass background on iOS 26+, kept around so `layoutSubviews` can keep it a pill. Nil on the legacy path, where the background is drawn by the banner itself.
    private var visualEffectView: UIVisualEffectView?

    private init(theme: Theme, message: String, action: Action?, onAction: (() -> Void)?) {
        self.onAction = onAction
        super.init(frame: .zero)

        let background: UIColor? = theme["sheetBackgroundColor"] ?? theme["listBackgroundColor"]
        let textColor: UIColor? = theme["listTextColor"]
        let borderColor: UIColor? = theme["listSecondaryTextColor"]
        let tintColor: UIColor? = theme["tintColor"]

        // Glass brings its own material, edge and shadow, so the drawn-on background is for the
        // fallback path only. Reduce Transparency turns the material into a flat fill that loses
        // the pill's edge entirely, so it drops back too.
        let usesGlass: Bool
        if #available(iOS 26.0, *), !UIAccessibility.isReduceTransparencyEnabled {
            usesGlass = true
        } else {
            usesGlass = false
        }

        let contentParent: UIView
        if usesGlass, #available(iOS 26.0, *) {
            let effectView = UIVisualEffectView(effect: UIGlassEffect())
            effectView.translatesAutoresizingMaskIntoConstraints = false
            // Match the banner's themed contents rather than the system appearance: the posts page
            // can be dark under a light system, or the reverse.
            effectView.overrideUserInterfaceStyle = theme[string: "mode"] == "dark" ? .dark : .light
            addSubview(effectView)
            NSLayoutConstraint.activate([
                effectView.topAnchor.constraint(equalTo: topAnchor),
                effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
                effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            visualEffectView = effectView
            contentParent = effectView.contentView
        } else {
            backgroundColor = background
            layer.cornerRadius = 12
            layer.borderWidth = 1
            layer.borderColor = borderColor?.cgColor
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.15
            layer.shadowRadius = 6
            layer.shadowOffset = CGSize(width: 0, height: 2)
            contentParent = self
        }

        let font = UIFont.bannerToast(.subheadline, rounded: theme.roundedFonts)
        let actionFont = UIFont.bannerToast(.subheadline, weight: .semibold, rounded: theme.roundedFonts)

        label.textColor = textColor
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2

        // The link is styled in place and hit-tested in `didTapBanner`, rather than being its own
        // control, so the sentence stays one run of text that wraps as a sentence should.
        if case .link(let text, _) = action, let range = message.range(of: text) {
            let attributed = NSMutableAttributedString(string: message, attributes: [
                .font: font,
                .foregroundColor: textColor as Any,
            ])
            let linkRange = NSRange(range, in: message)
            attributed.addAttributes([
                .font: actionFont,
                .foregroundColor: tintColor as Any,
            ], range: linkRange)
            label.attributedText = attributed
            self.linkRange = linkRange
        } else {
            label.text = message
        }

        let stack = UIStackView(arrangedSubviews: [label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        // Wider on the glass path: the text has to clear the ends of the pill, which curve in much further than a 12pt corner does.
        let horizontalMargin: CGFloat = usesGlass ? 20 : 14
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: horizontalMargin, bottom: 10, trailing: horizontalMargin)
        contentParent.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentParent.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentParent.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentParent.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentParent.bottomAnchor),
        ])

        if case .button(let title) = action {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.setTitleColor(tintColor, for: .normal)
            button.titleLabel?.font = actionFont
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.addTarget(self, action: #selector(didTapAction), for: .primaryActionTriggered)
            stack.addArrangedSubview(button)
        }

        if case .link(_, let actionName) = action {
            // A styled run of text is invisible to VoiceOver, so offer the action explicitly — this is what the button used to give us for free.
            isAccessibilityElement = true
            accessibilityLabel = message
            accessibilityCustomActions = [UIAccessibilityCustomAction(name: actionName) { [weak self] _ in
                self?.didTapAction()
                return true
            }]
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapBanner))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        // A pill, like the liquid glass title view. Clipping happens on the effect view rather than
        // on the banner, whose transform-based show/dismiss animation shouldn't be masked.
        if let visualEffectView {
            visualEffectView.layer.cornerRadius = bounds.height / 2
            visualEffectView.layer.masksToBounds = true
            visualEffectView.layer.cornerCurve = .continuous
        }
    }

    @objc private func didTapAction() {
        onAction?()
        dismiss()
    }

    @objc private func didTapBanner(_ recognizer: UITapGestureRecognizer) {
        if let linkRange, linkFrame(for: linkRange)?.contains(recognizer.location(in: label)) == true {
            didTapAction()
        } else {
            dismiss()
        }
    }

    /// Where `range` of the label's text lands within the label, or nil if it can't be laid out.
    ///
    /// A throwaway TextKit stack matching the label's own configuration. We test against the text's
    /// bounding rect rather than asking for the character index at the touch, since the latter snaps
    /// to the nearest character and so answers "yes, the link" for taps well past the end of the line.
    private func linkFrame(for range: NSRange) -> CGRect? {
        guard let attributedText = label.attributedText, label.bounds.width > 0 else { return nil }

        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: label.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.lineBreakMode = label.lineBreakMode
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var frame = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        // TextKit lays out from the top; UILabel centres its text in whatever height it was given.
        let usedHeight = layoutManager.usedRect(for: textContainer).height
        frame.origin.y += (label.bounds.height - usedHeight) / 2
        return frame
    }

    public func dismiss(animated: Bool = true) {
        scheduledDismissal?.cancel()
        scheduledDismissal = nil
        guard animated else { return removeFromSuperview() }
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 8)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
}

extension BannerToastView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Let the action button handle its own taps.
        !(touch.view is UIControl)
    }
}

private extension UIFont {
    /**
     A Dynamic Type font for the banner, in the theme's rounded design when it asks for one.

     SwiftUI screens get this from `applyFontDesign(if:)`, but the banner is UIKit and has to ask.
     It reads the theme it was handed rather than `Theme.defaultTheme()`, since the banner shows over
     the posts page, whose theme is forum-specific.

     Note the descriptor is taken at the *default* content size category and scaled by `UIFontMetrics`
     afterwards. `preferredFontDescriptor(withTextStyle:)` on its own already returns a scaled size,
     so handing that to the metrics would scale it a second time.
     */
    static func bannerToast(
        _ textStyle: UIFont.TextStyle,
        weight: UIFont.Weight? = nil,
        rounded: Bool
    ) -> UIFont {
        var descriptor = UIFontDescriptor.preferredFontDescriptor(
            withTextStyle: textStyle,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        )
        if let weight {
            descriptor = descriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight]
            ])
        }
        if rounded, let roundedDescriptor = descriptor.withDesign(.rounded) {
            descriptor = roundedDescriptor
        }
        // Scaling through the metrics keeps `adjustsFontForContentSizeCategory` working, which a
        // font built straight from a descriptor doesn't get.
        return UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(for: UIFont(descriptor: descriptor, size: 0))
    }
}
