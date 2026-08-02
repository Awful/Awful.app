//  BannerToastView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import UIKit

/// A transient message pinned to the bottom of a host view, above the keyboard, with an optional action button. Tap the banner to dismiss it early; it auto-dismisses after a few seconds.
final class BannerToastView: UIView {

    /// Shows a banner near the bottom of `hostView`, above the keyboard when one is up, replacing any banner already shown there.
    /// Pass `actionTitle`/`onAction` for a tappable action (e.g. "Use Original"); omit both for a plain informational toast.
    @discardableResult
    static func show(
        in hostView: UIView,
        theme: Theme,
        message: String,
        actionTitle: String? = nil,
        duration: TimeInterval = 5,
        onAction: (() -> Void)? = nil
    ) -> BannerToastView {
        for existing in hostView.subviews.compactMap({ $0 as? BannerToastView }) {
            existing.dismiss(animated: false)
        }

        let banner = BannerToastView(theme: theme, message: message, actionTitle: actionTitle, onAction: onAction)
        banner.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(banner)

        // Sit above whichever comes first: the keyboard (its layout guide includes any input accessory view) or the bottom safe area. The lower-priority equality pulls the banner as far down as those allow.
        let restToBottom = banner.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        restToBottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            banner.bottomAnchor.constraint(lessThanOrEqualTo: hostView.keyboardLayoutGuide.topAnchor, constant: -8),
            banner.bottomAnchor.constraint(lessThanOrEqualTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            restToBottom,
            banner.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            banner.leadingAnchor.constraint(greaterThanOrEqualTo: hostView.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(lessThanOrEqualTo: hostView.trailingAnchor, constant: -12),
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

    private init(theme: Theme, message: String, actionTitle: String?, onAction: (() -> Void)?) {
        self.onAction = onAction
        super.init(frame: .zero)

        let background: UIColor? = theme["sheetBackgroundColor"] ?? theme["listBackgroundColor"]
        let textColor: UIColor? = theme["listTextColor"]
        let borderColor: UIColor? = theme["listSecondaryTextColor"]
        let tintColor: UIColor? = theme["tintColor"]

        backgroundColor = background
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = borderColor?.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)

        let label = UILabel()
        label.text = message
        label.textColor = textColor
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        if let actionTitle {
            let button = UIButton(type: .system)
            button.setTitle(actionTitle, for: .normal)
            button.setTitleColor(tintColor, for: .normal)
            button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.addTarget(self, action: #selector(didTapAction), for: .primaryActionTriggered)
            stack.addArrangedSubview(button)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapBanner))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func didTapAction() {
        onAction?()
        dismiss()
    }

    @objc private func didTapBanner() {
        dismiss()
    }

    func dismiss(animated: Bool = true) {
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
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Let the action button handle its own taps.
        !(touch.view is UIControl)
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: 0)
    }
}
