//  NavigationConfigurator.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import AwfulSettings
import SwiftUI
import UIKit

public struct NavigationConfigurator: UIViewControllerRepresentable {
    let theme: Theme

    public init(theme: Theme) {
        self.theme = theme
    }
    
    public func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        return viewController
    }
    
    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            if let navigationController = uiViewController.navigationController {
                // Configure navigation bar
                let navAppearance = UINavigationBarAppearance()
                navAppearance.configureWithOpaqueBackground()
                navAppearance.backgroundColor = theme[uicolor: "navigationBarTintColor"]
                navAppearance.shadowColor = .clear

                // Custom themes can drop this key, so don't crash the whole screen over it.
                let textColor = theme[uicolor: "navigationBarTextColor"] ?? .label
                navAppearance.titleTextAttributes = [.foregroundColor: textColor]

                // Use the app's custom back image from assets instead of the system chevron.
                if let backImage = UIImage(named: "back") {
                    let indicator: UIImage
                    if #available(iOS 26.0, *), LiquidGlass.isEnabled {
                        // Template so the Liquid Glass bar tints it black/white dynamically
                        // (tintColor is cleared below), matching the app's main navigation bar.
                        indicator = backImage.withRenderingMode(.alwaysTemplate)
                    } else {
                        indicator = backImage
                    }
                    navAppearance.setBackIndicatorImage(indicator, transitionMaskImage: indicator)
                }

                // Ensure text-based bar button items adopt theme font (rounded if enabled)
                let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
                if #available(iOS 26.0, *), LiquidGlass.isEnabled {
                    // Liquid Glass: omit the button color and clear tintColor so the OS renders the
                    // bar buttons black/white against the glass for legibility, like the main Forums
                    // bar. A forced theme color (e.g. a white navigationBarTextColor) is hard to read
                    // on the glass platter. Keep only the font.
                    let fontOnly: [NSAttributedString.Key: Any] = [.font: buttonFont]
                    navAppearance.buttonAppearance.normal.titleTextAttributes = fontOnly
                    navAppearance.buttonAppearance.highlighted.titleTextAttributes = fontOnly
                    navAppearance.doneButtonAppearance.normal.titleTextAttributes = fontOnly
                    navAppearance.doneButtonAppearance.highlighted.titleTextAttributes = fontOnly
                    navAppearance.backButtonAppearance.normal.titleTextAttributes = fontOnly
                    navAppearance.backButtonAppearance.highlighted.titleTextAttributes = fontOnly
                    navigationController.navigationBar.tintColor = nil
                    // Liquid Glass resolves its platters' light/dark from the bar's
                    // trait, not from appearance colors.
                    navigationController.navigationBar.overrideUserInterfaceStyle = theme.userInterfaceStyle
                } else {
                    let buttonAttrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: textColor,
                        .font: buttonFont
                    ]
                    navAppearance.buttonAppearance.normal.titleTextAttributes = buttonAttrs
                    navAppearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttrs
                    navAppearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttrs
                    navAppearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttrs
                    navAppearance.backButtonAppearance.normal.titleTextAttributes = buttonAttrs
                    navAppearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttrs
                    navigationController.navigationBar.tintColor = textColor
                    navigationController.navigationBar.overrideUserInterfaceStyle = .unspecified
                }
                
                navigationController.navigationBar.standardAppearance = navAppearance
                navigationController.navigationBar.scrollEdgeAppearance = navAppearance
                // Drive the bar style from the current theme so status bar
                // icons match the theme while Search is presented.
                let isLightBackground = (theme["statusBarBackground"] == "light")
                navigationController.navigationBar.barStyle = isLightBackground ? .default : .black
                
                // Configure toolbar
                let toolbarAppearance = UIToolbarAppearance()
                toolbarAppearance.configureWithOpaqueBackground()
                toolbarAppearance.backgroundColor = theme[uicolor: "tabBarBackgroundColor"]
                toolbarAppearance.shadowColor = .clear
                
                navigationController.toolbar.standardAppearance = toolbarAppearance
                navigationController.toolbar.compactAppearance = toolbarAppearance
                if #available(iOS 15.0, *) {
                    navigationController.toolbar.scrollEdgeAppearance = toolbarAppearance
                    navigationController.toolbar.compactScrollEdgeAppearance = toolbarAppearance
                }
                
                // Force immediate update
                navigationController.toolbar.setNeedsLayout()
            }
        }
    }
}

/// Applies `foregroundColor(_:)` unless Liquid Glass is in effect (iOS 26+ and not disabled by the
/// user), in which case the bar renders the button black/white dynamically. `@AppStorage` keeps the
/// choice live: toggling "Reduce Liquid Glass" re-evaluates without relaunching.
private struct LiquidGlassBarButtonColorModifier: ViewModifier {
    let color: Color?
    @AppStorage(Settings.disableLiquidGlass) private var disableLiquidGlass

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !disableLiquidGlass {
            content
        } else {
            content.foregroundColor(color)
        }
    }
}

/// Applies `tint(_:)` unless Liquid Glass is in effect (iOS 26+ and not disabled by the user).
/// `@AppStorage` keeps the choice live, matching `LiquidGlassBarButtonColorModifier`.
private struct LiquidGlassNavigationTintModifier: ViewModifier {
    let color: Color?
    @AppStorage(Settings.disableLiquidGlass) private var disableLiquidGlass

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !disableLiquidGlass {
            content
        } else {
            content.tint(color)
        }
    }
}

extension View {
    /// Colors a navigation-bar toolbar button with `color` on iOS < 26 and when the user has
    /// disabled Liquid Glass. When glass is in effect it applies no color, letting the Liquid Glass
    /// bar render the button black/white dynamically for legibility, matching the app's main Forums
    /// bar. Pair with `liquidGlassNavigationTint` so SwiftUI doesn't stamp a per-item tint that
    /// would override the bar's cleared `tintColor` (see NavigationConfigurator).
    public func liquidGlassBarButtonColor(_ color: Color?) -> some View {
        modifier(LiquidGlassBarButtonColorModifier(color: color))
    }

    /// Tints the navigation stack with `color` on iOS < 26 and when the user has disabled Liquid
    /// Glass. When glass is in effect the tint is omitted so the Liquid Glass bar's buttons follow
    /// the bar's cleared `tintColor` and render black/white dynamically. Content sets its own
    /// colors, so dropping the ambient tint there is safe.
    public func liquidGlassNavigationTint(_ color: Color?) -> some View {
        modifier(LiquidGlassNavigationTintModifier(color: color))
    }
}

/// Applies `toolbarContent` as the modified view's toolbar, hiding the glass capsule behind each
/// item when the user has disabled Liquid Glass. `@AppStorage` keeps the choice live.
///
/// This has to wrap the whole `toolbar(content:)` call rather than being a per-item
/// `ToolbarContent` extension: runtime-conditional `ToolbarContent` (`buildEither` /
/// `buildLimitedAvailability`) requires iOS 16, and these packages deploy to iOS 15. `ViewBuilder`
/// conditionals are iOS 15-safe, so the availability fork lives at the view level and the toolbar
/// closure stays a single unconditional expression. `sharedBackgroundVisibility(_:)` distributes
/// over the composed toolbar content, hitting every item.
private struct GlassAwareToolbarModifier<ToolbarItems: ToolbarContent>: ViewModifier {
    let toolbarContent: () -> ToolbarItems
    @AppStorage(Settings.disableLiquidGlass) private var disableLiquidGlass

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.toolbar {
                toolbarContent()
                    .sharedBackgroundVisibility(disableLiquidGlass ? .hidden : .automatic)
            }
        } else {
            content.toolbar(content: toolbarContent)
        }
    }
}

public extension View {
    /// Like `toolbar(content:)`, but hides the glass capsule behind each toolbar item when the
    /// user has disabled Liquid Glass. No-op pre-iOS 26 and when glass is enabled.
    func toolbarHidingSharedBackgroundWhenGlassDisabled<Content: ToolbarContent>(
        @ToolbarContentBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(GlassAwareToolbarModifier(toolbarContent: content))
    }
}
