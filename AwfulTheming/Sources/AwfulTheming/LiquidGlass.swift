//  LiquidGlass.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import Foundation
import UIKit

/// Whether the system Liquid Glass chrome should be used.
public enum LiquidGlass {
    /// True on iOS 26+ unless the user has turned on "Reduce Liquid Glass".
    public static var isEnabled: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return !UserDefaults.standard.bool(forKey: Settings.disableLiquidGlass.key)
    }

    /// True on iOS 26+ iPad regardless of "Reduce Liquid Glass". That setting only swaps the
    /// app's own bar appearances; UIKit keeps rendering the split view's sidebar column as a
    /// flat glass panel (vibrancy-tinted labels and buttons, asymmetric title layout), so the
    /// sidebar mitigations must key off this rather than `isEnabled`.
    public static var affectsPadSidebar: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}

/// Identifies the background view installed by `setLegacyOpaqueBackground(color:)`.
private final class LegacyBarBackgroundView: UIView {}

/// Shared implementation for `UIToolbar.setLegacyOpaqueBackground(color:)` and
/// `UITabBar.setLegacyOpaqueBackground(color:)`.
private func setLegacyOpaqueBackground(on bar: UIView, color: UIColor?) {
    let existing = bar.subviews.first { $0 is LegacyBarBackgroundView }
    guard let color else {
        existing?.removeFromSuperview()
        return
    }
    let background: UIView
    if let existing {
        background = existing
    } else {
        background = LegacyBarBackgroundView()
        background.autoresizingMask = [.flexibleWidth]
        background.isUserInteractionEnabled = false
        bar.addSubview(background)
    }
    // Extend well below the bar's bounds so the bottom safe area (home-indicator
    // region) is painted too — pre-26 the system extended the bar background there for
    // us. The overshoot past the screen edge is harmless.
    background.frame = CGRect(x: 0, y: 0, width: bar.bounds.width, height: bar.bounds.height + 100)
    background.backgroundColor = color
    bar.sendSubviewToBack(background)
}

public extension UIBarButtonItem {
    /// True for fixed/flexible space items. Never touch `hidesSharedBackground` on these:
    /// a space with the property set joins the shared glass background, merging every
    /// platter into one full-width pill. (A system item like `editButtonItem` also has no
    /// image/title/customView, so the action/menu checks are what tell them apart.)
    var isSpacer: Bool {
        image == nil && title == nil && customView == nil
            && action == nil && primaryAction == nil && menu == nil
    }
}

public extension UIToolbar {
    /// On iOS 26 a toolbar no longer paints its appearance background — the system draws
    /// per-item glass platters over a transparent bar, and an opaque `UIToolbarAppearance`
    /// is ignored. When Liquid Glass is disabled we paint the background ourselves with a
    /// subview pinned to the toolbar's bounds. Pass nil to remove the painted background
    /// (e.g. the user re-enabled Liquid Glass).
    func setLegacyOpaqueBackground(color: UIColor?) {
        AwfulTheming.setLegacyOpaqueBackground(on: self, color: color)
    }
}

public extension UITabBar {
    /// On iOS 26 the tab bar renders as a floating glass pill whose shape and selection
    /// capsule can't be removed via `UITabBarAppearance` (the system ignores overrides).
    /// When Liquid Glass is disabled we paint a full-bleed opaque background behind the
    /// pill so the bar reads as the classic full-width bar. Pass nil to remove the
    /// painted background (e.g. the user re-enabled Liquid Glass).
    func setLegacyOpaqueBackground(color: UIColor?) {
        AwfulTheming.setLegacyOpaqueBackground(on: self, color: color)
    }
}
