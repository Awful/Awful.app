//  NavigationConfigurator.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI
import UIKit

/// Themes the `UINavigationBar`/`UIToolbar` backing a SwiftUI `NavigationView`, which SwiftUI can't
/// style directly. Attach with `.background(NavigationConfigurator(theme: theme))` inside a
/// `NavigationView`. Adapted from the app's Search screen.
struct NavigationConfigurator: UIViewControllerRepresentable {
    let theme: Theme

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let navigationController = uiViewController.navigationController else { return }

            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithOpaqueBackground()
            navAppearance.backgroundColor = theme[uicolor: "navigationBarTintColor"]
            navAppearance.shadowColor = .clear

            let textColor = theme[uicolor: "navigationBarTextColor"] ?? .label
            navAppearance.titleTextAttributes = [.foregroundColor: textColor]

            // Replace the system chevron with the app's custom back image (Assets.xcassets → "back",
            // resolved from Bundle.main).
            if let backImage = UIImage(named: "back") {
                let indicator: UIImage
                if #available(iOS 26.0, *) {
                    // Keep it a template so the Liquid Glass bar tints it black/white dynamically
                    // (tintColor is cleared below), matching the app's main navigation bar.
                    indicator = backImage.withRenderingMode(.alwaysTemplate)
                } else {
                    // Pre-glass: tint to the nav bar text color so it matches the title.
                    indicator = backImage.withTintColor(textColor, renderingMode: .alwaysOriginal)
                }
                navAppearance.setBackIndicatorImage(indicator, transitionMaskImage: indicator)
            }

            if #available(iOS 26.0, *) {
                // Liquid Glass: don't force a button color. Clearing tintColor lets the OS pick a
                // legible black/white against the glass content, exactly like the main Forums bar
                // (NavigationController.configureButtonAppearance). Forcing a theme color here — e.g.
                // a white navigationBarTextColor — is hard to read on the glass platter.
                navigationController.navigationBar.tintColor = nil
            } else {
                let buttonAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: textColor]
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

            let isLightBackground = (theme["statusBarBackground"] == "light")
            navigationController.navigationBar.barStyle = isLightBackground ? .default : .black
        }
    }
}

extension View {
    /// Colors a navigation-bar toolbar button with the theme's nav-bar text color on iOS < 26. On
    /// iOS 26+ it applies no color, so the Liquid Glass bar renders the button black/white
    /// dynamically for legibility — matching the app's main Forums bar. Pair with
    /// `glossaryNavigationTint` so SwiftUI doesn't stamp a per-item tint that would override the
    /// bar's cleared `tintColor` (see `NavigationConfigurator`).
    @ViewBuilder
    func glossaryBarButtonColor(_ color: Color?) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            foregroundColor(color)
        }
    }

    /// Tints the navigation stack with the theme tint on iOS < 26. On iOS 26+ the tint is omitted so
    /// the Liquid Glass bar's buttons follow the bar's cleared `tintColor` and render black/white
    /// dynamically. Glossary content sets its own colors, so dropping the ambient tint here is safe.
    @ViewBuilder
    func glossaryNavigationTint(_ color: Color?) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            tint(color)
        }
    }
}
