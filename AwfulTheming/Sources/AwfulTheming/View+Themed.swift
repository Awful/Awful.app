//  View+Themed.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import SwiftUI

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Theme = .defaultTheme()
}

public extension EnvironmentValues {
    /// The current user interface theme.
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

/// Updates the `colorScheme` and `theme` environment values based on the dark mode setting.
public struct ThemeViewModifier: ViewModifier {
    
    @AppStorage(Settings.defaultDarkThemeName) var darkThemeName
    @AppStorage(Settings.defaultLightThemeName) var lightThemeName
    // It would be better to use SwiftUI's `colorScheme` instead of our custom setting. We could override `colorScheme` at the app/root level based on the settings for "automatic dark mode" and "dark mode". We could also override the UITraitCollection at the root level for UIKit screens. For now, though, we're watching the dark mode setting directly.
    @AppStorage(Settings.darkMode) var darkMode

    var theme: Theme {
        // TODO: Wrap this up somewhere closer to the Theme.defaultTheme() implementation so we have one source of truth for resolving "default theme".
        Theme.theme(named: (darkMode ? darkThemeName : lightThemeName).rawValue)!
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, darkMode ? .dark : .light)
            .environment(\.theme, theme)
            .onChange(of: darkMode) { _ in
                // Post notification to update UIKit components
                NotificationCenter.default.post(name: Notification.Name("ThemeDidChange"), object: nil)
            }
            .onChange(of: darkThemeName) { _ in
                // Post notification when dark theme changes (if currently in dark mode)
                if darkMode {
                    NotificationCenter.default.post(name: Notification.Name("ThemeDidChange"), object: nil)
                }
            }
            .onChange(of: lightThemeName) { _ in
                // Post notification when light theme changes (if currently in light mode)
                if !darkMode {
                    NotificationCenter.default.post(name: Notification.Name("ThemeDidChange"), object: nil)
                }
            }
    }
}

public extension View {
    /// Sets and propagates the current theme based on the dark mode setting.
    func themed() -> some View {
        modifier(ThemeViewModifier())
    }
}
