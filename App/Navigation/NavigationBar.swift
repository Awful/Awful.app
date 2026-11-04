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

    // MARK: Vertical bar top fill

    /// What the bar's background looks like right now (its colour at its current opacity), for
    /// `verticalBarTopFill`. Nil leaves the fill off.
    var verticalBarTopFillColor: UIColor? {
        didSet {
            guard verticalBarTopFillColor != oldValue else { return }
            setNeedsLayout()
        }
    }

    /// With the status bar moved into the vertical bar on the folded iPhone Duo, UIKit still lays the bar out a little way down from the top of the screen but only extends its background part of the way up, leaving a strip of whatever's behind (see `VerticalBar`). This covers that strip in the bar's own colour. Kept at the back so it follows the bar's transform and alpha (immersive mode).
    private var verticalBarTopFill: UIView?

    private func layoutVerticalBarTopFill() {
        // `frame` would include the immersive-mode transform; the gap is the untransformed one.
        let gap = center.y - bounds.height / 2
        guard VerticalBar.isActive(in: traitCollection), gap > 0, let color = verticalBarTopFillColor else {
            verticalBarTopFill?.isHidden = true
            return
        }
        let fill: UIView
        if let existing = verticalBarTopFill {
            fill = existing
        } else {
            fill = UIView()
            fill.isUserInteractionEnabled = false
            verticalBarTopFill = fill
        }
        // Inserted once, behind the bar's own background.
        if fill.superview !== self {
            insertSubview(fill, at: 0)
        }
        fill.isHidden = false
        fill.backgroundColor = color
        fill.frame = CGRect(x: 0, y: -gap, width: bounds.width, height: gap)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        VerticalBar.registerForChanges(self, action: #selector(UIView.setNeedsLayout))

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

    /// Called at the end of every layout pass, after the bar's own work.
    var didLayoutSubviews: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutVerticalBarTopFill()
        defer { didLayoutSubviews?() }

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
