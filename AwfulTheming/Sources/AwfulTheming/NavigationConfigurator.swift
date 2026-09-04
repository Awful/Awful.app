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
                        // Glass vibrancy ignores tintColor on the dark platter; bake the colour in.
                        indicator = backImage.withTintColor(textColor, renderingMode: .alwaysOriginal)
                    } else {
                        indicator = backImage
                    }
                    navAppearance.setBackIndicatorImage(indicator, transitionMaskImage: indicator)
                }

                // Ensure text-based bar button items adopt theme font (rounded if enabled)
                let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
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

                if #available(iOS 26.0, *), LiquidGlass.isEnabled {
                    // Nothing scrolls beneath this bar, so the glass bar-button circles take
                    // their light/dark from the bar's trait: dark circles on a dark bar.
                    navigationController.navigationBar.overrideUserInterfaceStyle = theme.navigationBarUserInterfaceStyle
                } else {
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

/// Applies `foregroundColor(_:)`. Under Liquid Glass (iOS 26+ and not disabled by the user) the
/// glass platter's vibrancy would tint the label with the bar colour behind it, so the button is
/// also drawn under `glassEffect(.identity)`, which keeps the colour as given. `@AppStorage` keeps
/// the choice live: toggling "Reduce Liquid Glass" re-evaluates without relaunching.
private struct LiquidGlassBarButtonColorModifier: ViewModifier {
    let color: Color?
    @AppStorage(Settings.disableLiquidGlass) private var disableLiquidGlass

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !disableLiquidGlass {
            content.foregroundColor(color).glassEffect(.identity)
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
    /// Colors a navigation-bar toolbar button with `color`, drawn so the Liquid Glass platter's
    /// vibrancy can't retint it (see NavigationConfigurator for the bar side).
    public func liquidGlassBarButtonColor(_ color: Color?) -> some View {
        modifier(LiquidGlassBarButtonColorModifier(color: color))
    }

    /// Tints the navigation stack with `color` on iOS < 26 and when the user has disabled Liquid
    /// Glass. When glass is in effect the tint is omitted: the bar buttons are coloured by
    /// `liquidGlassBarButtonColor` instead. Content sets its own colors, so dropping the ambient
    /// tint there is safe.
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
