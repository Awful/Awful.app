//  NavigationConfigurator.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import AwfulTheming
import SwiftUI
import UIKit

struct NavigationConfigurator: UIViewControllerRepresentable {
    let theme: Theme
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            if let navigationController = uiViewController.navigationController {
                // Configure navigation bar
                let navAppearance = UINavigationBarAppearance()
                navAppearance.configureWithOpaqueBackground()
                navAppearance.backgroundColor = theme[uicolor: "navigationBarTintColor"]
                navAppearance.shadowColor = .clear

                let textColor = theme[uicolor: "navigationBarTextColor"]!
                navAppearance.titleTextAttributes = [.foregroundColor: textColor]

                // Use the app's custom back image from assets instead of the system chevron.
                if let backImage = UIImage(named: "back") {
                    let indicator: UIImage
                    if #available(iOS 26.0, *) {
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
                if #available(iOS 26.0, *) {
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

extension View {
    /// Colors a navigation-bar toolbar button with `color` on iOS < 26. On iOS 26+ it applies no
    /// color, letting the Liquid Glass bar render the button black/white dynamically for legibility,
    /// matching the app's main Forums bar. Pair with `liquidGlassNavigationTint` so SwiftUI doesn't
    /// stamp a per-item tint that would override the bar's cleared `tintColor` (see NavigationConfigurator).
    @ViewBuilder
    func liquidGlassBarButtonColor(_ color: Color?) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            foregroundColor(color)
        }
    }

    /// Tints the navigation stack with `color` on iOS < 26. On iOS 26+ the tint is omitted so the
    /// Liquid Glass bar's buttons follow the bar's cleared `tintColor` and render black/white
    /// dynamically. Content sets its own colors, so dropping the ambient tint here is safe.
    @ViewBuilder
    func liquidGlassNavigationTint(_ color: Color?) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            tint(color)
        }
    }
}
