//  PageNavigationView.swift
//
//  Copyright © 2026 Awful Contributors. All rights reserved.
//

import UIKit

/// Previous/next arrows either side of a `PageNumberView`, laid out as a single bar button item's
/// custom view.
///
/// On iOS 26+ each image bar button item takes a fixed slot of about 56pt (a 48pt button plus
/// spacing) that neither `width` nor iOS 27's `isPaddingRemoved` shrinks. As three separate items the
/// paging pill was too wide for a 320pt screen (an iPhone 14 with Display Zoom), and iOS 27 moved the
/// forward arrow into an overflow menu. Laid out here, it matches the separate items' geometry when
/// there's room and tightens up when there isn't (see `maximumWidth`).
public final class PageNavigationView: UIView {

    /// Each arrow's slot, from the pill's edge inward. With the item's standard padding this centres
    /// the arrows where the separate bar button items had them.
    private static let regularArrowWidth: CGFloat = 41

    /// Still leaves a little room either side of the 26pt arrow images.
    private static let compactArrowWidth: CGFloat = 36

    /// Extra tappable room on each arrow's side facing the counter, keeping the counter as far from
    /// the arrows as the separate bar button items did. Without the glass pill (Reduce Liquid Glass)
    /// UIKit spaced those items further apart.
    private var regularInnerPadding: CGFloat { hidesSharedBackground ? 22 : 16 }

    public let pageNumberView: PageNumberView

    private let backButton = UIButton(configuration: .plain())
    private let forwardButton = UIButton(configuration: .plain())
    private let stack = UIStackView()
    private lazy var backWidthConstraint = backButton.widthAnchor.constraint(equalToConstant: 0)
    private lazy var forwardWidthConstraint = forwardButton.widthAnchor.constraint(equalToConstant: 0)

    /// The widest the arrows and counter may be together. When their usual layout doesn't fit,
    /// the room between the arrows and the counter goes first, then the arrows narrow, then the
    /// counter's text shrinks.
    public var maximumWidth: CGFloat = .greatestFiniteMagnitude {
        didSet {
            guard maximumWidth != oldValue else { return }
            fitToMaximumWidth()
        }
    }

    /// Mirrors the bar item's `hidesSharedBackground`, to match the spacing the separate items had.
    public var hidesSharedBackground = false {
        didSet {
            guard hidesSharedBackground != oldValue else { return }
            fitToMaximumWidth()
        }
    }

    /// The arrows and the counter's text.
    public var textColor: UIColor = .label {
        didSet {
            pageNumberView.textColor = textColor
            backButton.setNeedsUpdateConfiguration()
            forwardButton.setNeedsUpdateConfiguration()
        }
    }

    public var isBackEnabled: Bool {
        get { backButton.isEnabled }
        set { backButton.isEnabled = newValue }
    }

    public var isForwardEnabled: Bool {
        get { forwardButton.isEnabled }
        set { forwardButton.isEnabled = newValue }
    }

    public init(
        pageNumberView: PageNumberView,
        backImage: UIImage?,
        forwardImage: UIImage?,
        onBack: @escaping () -> Void,
        onForward: @escaping () -> Void
    ) {
        self.pageNumberView = pageNumberView
        super.init(frame: .zero)

        configure(backButton, image: backImage, accessibilityLabel: "Previous page", action: onBack)
        configure(forwardButton, image: forwardImage, accessibilityLabel: "Next page", action: onForward)

        for view in [backButton, pageNumberView, forwardButton] {
            stack.addArrangedSubview(view)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            backWidthConstraint,
            forwardWidthConstraint,
        ])

        pageNumberView.contentDidChange = { [weak self] in self?.fitToMaximumWidth() }
        fitToMaximumWidth()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(_ button: UIButton, image: UIImage?, accessibilityLabel: String, action: @escaping () -> Void) {
        // Bar items always tint their images; a button only tints template images.
        let image = image?.withRenderingMode(.alwaysTemplate)
        button.configuration?.image = image
        button.configurationUpdateHandler = { [unowned self] button in
            button.configuration?.baseForegroundColor = button.isEnabled
                ? self.textColor
                : self.textColor.withAlphaComponent(PageNumberView.disabledAlpha)
        }
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        button.accessibilityLabel = accessibilityLabel

        // Bar items get the large content viewer for free; a custom view's controls don't.
        button.showsLargeContentViewer = true
        button.largeContentTitle = accessibilityLabel
        button.largeContentImage = image
        button.addInteraction(UILargeContentViewerInteraction())
    }

    /// Squeezes the usual layout into `maximumWidth`, giving up the arrows' inner padding, then
    /// arrow width, then counter width, so the counter's text is the last thing to shrink.
    private func fitToMaximumWidth() {
        let counterWidth = pageNumberView.naturalWidth
        var excess = 2 * (Self.regularArrowWidth + regularInnerPadding) + counterWidth - maximumWidth

        let innerPadding = max(0, regularInnerPadding - max(0, excess) / 2)
        excess -= 2 * (regularInnerPadding - innerPadding)

        let arrowWidth = max(Self.compactArrowWidth, Self.regularArrowWidth - max(0, excess) / 2)
        excess -= 2 * (Self.regularArrowWidth - arrowWidth)

        // The padding goes on the side facing the counter: trailing for back, leading for forward.
        backButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: innerPadding)
        forwardButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: innerPadding, bottom: 0, trailing: 0)
        backWidthConstraint.constant = arrowWidth + innerPadding
        forwardWidthConstraint.constant = arrowWidth + innerPadding
        pageNumberView.maximumWidth = excess > 0 ? max(0, counterWidth - excess) : .greatestFiniteMagnitude
        invalidateIntrinsicContentSize()
    }
}
