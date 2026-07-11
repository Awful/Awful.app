//  NavigationConfigurator.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI
import UIKit

/// Themes the `UINavigationBar`/`UIToolbar` backing a SwiftUI `NavigationView`, which SwiftUI can't
/// style directly. Attach with `.background(NavigationConfigurator(theme: theme))` inside a
/// `NavigationView`. Adapted from the app's Search screen (minus its app-bundle back-indicator image).
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

            let buttonAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: textColor]
            navAppearance.buttonAppearance.normal.titleTextAttributes = buttonAttrs
            navAppearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttrs
            navAppearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttrs
            navAppearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttrs
            navAppearance.backButtonAppearance.normal.titleTextAttributes = buttonAttrs
            navAppearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttrs

            navigationController.navigationBar.standardAppearance = navAppearance
            navigationController.navigationBar.scrollEdgeAppearance = navAppearance

            let isLightBackground = (theme["statusBarBackground"] == "light")
            navigationController.navigationBar.barStyle = isLightBackground ? .default : .black
        }
    }
}
