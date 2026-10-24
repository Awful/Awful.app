//  VerticalBar.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// The vertical bar iOS 27.1 puts down one side of the screen on the folded iPhone Duo. The status
/// bar and the tab bar move into it, so it changes things the app assumed everywhere else: the
/// status bar sits beside the content instead of over the navigation bar, the navigation bar no
/// longer starts at the top of the screen, and the content runs under the bar with a side safe
/// area inset.
///
/// The workarounds for it key off `isActive(in:)`, so none of them apply on any other device or
/// posture. (RootTabBarController checks the tab bar's own shape instead, since what it works
/// around is UIKit's handling of a side-mounted tab bar.)
public enum VerticalBar {

    /// True when the system places a vertical bar in this trait environment.
    public static func isActive(in traitCollection: UITraitCollection) -> Bool {
        // `verticalBarEdge` is new in the iOS 27.1 SDK, and Xcode 27.0's Swift is the same
        // version, so the SDK's UIKit build is what tells them apart. Built against an older
        // SDK there is no vertical bar to handle.
        #if canImport(UIKit, _version: 9127.0.85)
        if #available(iOS 27.1, *) {
            return traitCollection.verticalBarEdge != .unspecified
        }
        #endif
        return false
    }

    /// Sends `action` to `observer` whenever `isActive(in:)` may have changed, as when the iPhone
    /// Duo folds or unfolds. Does nothing where there's no vertical bar.
    @MainActor
    public static func registerForChanges(_ observer: UITraitEnvironment, action: Selector) {
        #if canImport(UIKit, _version: 9127.0.85)
        if #available(iOS 27.1, *), let observer = observer as? UITraitChangeObservable {
            observer.registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge, action: action)
        }
        #endif
    }
}

public extension UIView {

    /// The side safe area insets while there's a vertical bar, zero otherwise. For content laid out
    /// edge to edge that has to keep clear of the bar on the folded iPhone Duo only.
    var verticalBarInsets: UIEdgeInsets {
        guard VerticalBar.isActive(in: traitCollection) else { return .zero }
        return UIEdgeInsets(top: 0, left: safeAreaInsets.left, bottom: 0, right: safeAreaInsets.right)
    }
}

public extension UITextView {

    /// Keeps the text clear of the vertical bar. A text view only scrolls vertically, so UIKit
    /// never insets it by a side safe area and the text would wrap under the bar. Call from
    /// `safeAreaInsetsDidChange`, which runs as the iPhone Duo folds or unfolds.
    func updateVerticalBarTextInsets() {
        let insets = verticalBarInsets
        guard textContainerInset.left != insets.left || textContainerInset.right != insets.right else { return }
        textContainerInset.left = insets.left
        textContainerInset.right = insets.right
    }
}

public extension UIBarButtonItem {

    /// Tints a back button item for the navigation bar, except while there's a vertical bar: the
    /// back button always goes in that, on glass over the content, where the system's own colour
    /// is the one that reads.
    func setBackButtonTint(_ color: UIColor?, in traitCollection: UITraitCollection) {
        tintColor = VerticalBar.isActive(in: traitCollection) ? nil : color
    }
}

public extension UICollectionViewCell {

    /// Paints the whole cell in `color` while there's a vertical bar. UIKit insets a list cell's
    /// content view by the vertical bar's safe area, so a cell that only colours its content view
    /// shows the list's background in a strip down that side. Clears it otherwise, leaving every
    /// other device as it was.
    func updateVerticalBarBackground(_ color: UIColor?) {
        let fill = VerticalBar.isActive(in: traitCollection) ? color : nil
        if backgroundColor != fill {
            backgroundColor = fill
        }
    }

    /// The width a list cell `cellWidth` wide gives its content view. That's narrower than the
    /// cell while there's a vertical bar (see `updateVerticalBarBackground`), so a cell that lays
    /// out in its content view has to measure its height at this width too, or text that wraps
    /// further in the narrower view spills out of the bottom of the cell.
    func contentViewWidth(forCellWidth cellWidth: CGFloat) -> CGFloat {
        guard VerticalBar.isActive(in: traitCollection) else { return cellWidth }
        // The list's own insets: a cell being sized may not be where its own would be right yet.
        let insets = (superview as? UIScrollView)?.safeAreaInsets ?? safeAreaInsets
        return cellWidth - insets.left - insets.right
    }
}
