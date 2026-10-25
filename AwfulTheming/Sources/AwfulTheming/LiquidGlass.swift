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

    /// True on iOS 26+ regardless of "Reduce Liquid Glass". That setting hides the shared glass
    /// background behind the app's own bar button items (the iPad sidebar hides it whatever the
    /// setting, since iOS 27 started drawing platters there), but the system back button doesn't
    /// expose `hidesSharedBackground` and keeps its platter — and the platter's vibrancy washes
    /// out its chevron, and rubs off onto a neighbouring text item (Edit) when a push transition
    /// hands the bar back. So bar-button glyph colours have to be baked in either way.
    public static var affectsBarButtonPlatters: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return true
    }

    /// True on iOS 26+ regardless of "Reduce Liquid Glass". The navigation bar keeps its iOS 26
    /// behaviour either way — translucent, with the opaque→clear scroll transition — because that
    /// transition is what keeps the bar-button platters correct at every scroll offset. What the
    /// setting reduces is the app's own chrome: flat bar buttons (`hidesSharedBackground`) and no
    /// soft scroll-edge blur. An opaque bar instead leaves the one platter the app can't hide —
    /// the system back button's — stuck pale on a dark bar, with no API to tone it.
    public static var usesGlassNavigationBar: Bool { affectsBarButtonPlatters }
}

public extension UIViewController {
    /// True on iOS 26+ while this screen is in the iPad split view's sidebar column, whatever "Reduce Liquid Glass" says. That setting only swaps the app's own bar appearances, while UIKit keeps rendering the sidebar column as a flat glass panel (vibrancy-tinted labels and buttons, asymmetric title layout), so the sidebar mitigations key off this rather than `LiquidGlass.isEnabled`.
    ///
    /// A window narrow enough to collapse the split view makes the tab bar controller the whole screen, styled like the iPhone's, so this goes false then. It's also false before the screen joins the tab bar controller, which is why a screen building its bar items from it adopts `PadSidebarAdapting` to build them again. `splitViewController` is nil during initial setup (the tab bar controller joins the split view after its children are configured), which counts as expanded. The idiom is the device's, as a trait collection's is unspecified until it reaches a window.
    var isInPadSidebar: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return UIDevice.current.userInterfaceIdiom == .pad
            && tabBarController != nil
            && splitViewController?.isCollapsed != true
    }
}

/// A screen whose bar items differ in the iPad sidebar (see `isInPadSidebar`). As it appears, and whenever the split view collapses or expands, its navigation controller calls `padSidebarDidChange()` if `isInPadSidebar` no longer matches `barButtonItemsAreForPadSidebar`, before restyling the bar around the screen's items.
@MainActor
public protocol PadSidebarAdapting: UIViewController {
    /// Whether the screen's bar items were last built for the iPad sidebar.
    var barButtonItemsAreForPadSidebar: Bool { get }

    /// Rebuilds the screen's bar items for where it is now.
    func padSidebarDidChange()
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
