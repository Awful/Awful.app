//  NavigationBar.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import UIKit

/// Long-tapping the back button of an AwfulNavigationBar will pop its navigation controller to its root view controller.
final class NavigationBar: UINavigationBar {

    private lazy var bottomBorder: HairlineView = {
        let bottomBorder = HairlineView()
        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomBorder, constrainEdges: [.bottom, .left, .right])
        return bottomBorder
    }()

    var bottomBorderColor: UIColor? {
        get { return bottomBorder.backgroundColor }
        set { bottomBorder.backgroundColor = newValue }
    }

    // MARK: Content blur

    /// The blur behind the transparent bar on screens that ask for one
    /// (`NavigationBarScrollTransitioning.usesNavigationBarContentBlur`), spanning the status bar
    /// too. Created on first use, kept at the back of the bar so it follows the bar's transform
    /// and alpha (immersive mode) but sits under everything the bar draws.
    private var contentBlur: NavigationBarContentBlurView?

    /// 0 while the bar rests opaque, up to 1 once it's transparent over the content.
    var contentBlurAlpha: CGFloat = 0 {
        didSet {
            guard contentBlurAlpha != oldValue else { return }
            if contentBlur == nil {
                guard contentBlurAlpha > 0 else { return }
                let blur = NavigationBarContentBlurView()
                blur.overrideUserInterfaceStyle = contentBlurUserInterfaceStyle
                insertSubview(blur, at: 0)
                contentBlur = blur
                setNeedsLayout()
            }
            contentBlur?.alpha = contentBlurAlpha
        }
    }

    /// The light/dark of the content beneath the bar, so the blur's slight wash matches it.
    var contentBlurUserInterfaceStyle: UIUserInterfaceStyle = .unspecified {
        didSet { contentBlur?.overrideUserInterfaceStyle = contentBlurUserInterfaceStyle }
    }

    private func layoutContentBlur() {
        guard let contentBlur else { return }
        let statusBarHeight = window?.safeAreaInsets.top ?? 0
        contentBlur.frame = CGRect(x: 0, y: -statusBarHeight, width: bounds.width, height: bounds.height + statusBarHeight)
        if subviews.first !== contentBlur {
            sendSubviewToBack(contentBlur)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // For whatever reason, translucent navbars with a barTintColor do not necessarily blur their backgrounds. An iPad 3, for example, blurs a bar without a barTintColor but is simply semitransparent with a barTintColor. The semitransparent, non-blur effect looks awful, so just turn it off.
        // iOS 26: Allow translucency for liquid glass effect
        if #available(iOS 26.0, *) {
            isTranslucent = true
        } else {
            isTranslucent = false
        }

        // Setting the barStyle to UIBarStyleBlack results in an appropriate status bar style.
        barStyle = .black
        
        backIndicatorImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
        backIndicatorTransitionMaskImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
        
        titleTextAttributes = [.font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)]
        
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(didLongPress)))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// When set, `layoutSubviews` forces this color as `tintColor` and
    /// recolors all internal labels on every layout pass. Used by
    /// NavigationController for iPad sidebar where iOS 26 flat rendering
    /// ignores appearance APIs and colors elements with the app tintColor.
    var forcedTintColor: UIColor?

    private static let sidebarToggleOverlayTag = 9999

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutContentBlur()

        guard let forced = forcedTintColor else { return }

        if tintColor != forced {
            tintColor = forced
        }

        // Force tintColor on every subview in the nav bar so the flat
        // rendering's buttons pick up the correct color regardless of
        // which view they inherit tintColor from.
        func forceTint(in view: UIView) {
            if view.tintColor != forced {
                view.tintColor = forced
            }
            // Also catch the system sidebar toggle: find SF Symbol images
            // with vibrancy rendering and overlay with .alwaysOriginal.
            // Skip our own replacement (identified by tag).
            if let imageView = view as? UIImageView,
               imageView.tag != Self.sidebarToggleOverlayTag,
               let image = imageView.image,
               image.isSymbolImage,
               String(describing: image).contains("sidebar.leading") {
                // Use both isHidden and alpha to prevent UIKit from
                // resetting visibility during its own layout passes.
                imageView.isHidden = true
                imageView.alpha = 0
                if let parent = imageView.superview {
                    if let existing = parent.viewWithTag(Self.sidebarToggleOverlayTag) as? UIImageView {
                        existing.image = UIImage(systemName: "sidebar.leading")?
                            .withTintColor(forced, renderingMode: .alwaysOriginal)
                    } else {
                        let replacement = UIImageView(
                            image: UIImage(systemName: "sidebar.leading")?
                                .withTintColor(forced, renderingMode: .alwaysOriginal)
                        )
                        replacement.tag = Self.sidebarToggleOverlayTag
                        replacement.isUserInteractionEnabled = false
                        replacement.translatesAutoresizingMaskIntoConstraints = false
                        parent.addSubview(replacement)
                        NSLayoutConstraint.activate([
                            replacement.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
                            replacement.centerYAnchor.constraint(equalTo: parent.centerYAnchor),
                        ])
                    }
                }
            }
            for child in view.subviews {
                forceTint(in: child)
            }
        }
        forceTint(in: self)
    }

    @objc fileprivate func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        guard backItem != nil else { return }
        guard let nav = delegate as? UINavigationController else { return }
        
        // Try to find the back button's view without accessing its private `_view` ivar.
        guard let leftmost = subviews.lazy
            .filter({$0.bounds.width < self.bounds.width / 2})
            .min(by: {$0.frame.minX < $1.frame.minX || $0.bounds.width > $1.bounds.width}),
            leftmost.bounds.contains(sender.location(in: leftmost))
            else { return }
        nav.popToRootViewController(animated: true)
    }
}

/// A blur that fades out towards its bottom edge: what the transparent iOS 26 bar sits on over
/// the web-content screens instead of the system's soft edge effect.
///
/// The system effect can't be toned: on iOS 27 it washes the content in the bar's light or dark
/// regardless of what's beneath, so a light theme puts a white haze over a dark image while the
/// sampled title and status bar have gone white. A blur's own wash is much milder, and the bar
/// points this view's trait at the sampled content (`NavigationBar.contentBlurUserInterfaceStyle`)
/// so what little there is always matches.
final class NavigationBarContentBlurView: UIView {
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    private let fade = CAGradientLayer()

    /// How much of the blur shows at its strongest, at the top.
    private static let peakStrength: CGFloat = 0.55

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        // Part strength through the status bar and the top of the bar (full strength there reads
        // as a frosted band under the status bar), then off by the bar's bottom.
        let peak = UIColor.black.withAlphaComponent(Self.peakStrength).cgColor
        fade.colors = [peak, peak, UIColor.clear.cgColor]
        fade.locations = [0, 0.4, 1]
        fade.startPoint = CGPoint(x: 0.5, y: 0)
        fade.endPoint = CGPoint(x: 0.5, y: 1)
        effectView.layer.mask = fade
        addSubview(effectView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.frame = effectView.bounds
        CATransaction.commit()
    }
}
