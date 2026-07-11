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

    /// Observing CustomThemeManager triggers SwiftUI re-evaluation when custom theme overrides change.
    @ObservedObject private var customThemeManager = CustomThemeManager.shared

    var theme: Theme {
        // TODO: Wrap this up somewhere closer to the Theme.defaultTheme() implementation so we have one source of truth for resolving "default theme".
        // Access customThemeManager.overrides to establish a dependency for SwiftUI change tracking.
        _ = customThemeManager.overrides.count
        return Theme.theme(named: (darkMode ? darkThemeName : lightThemeName).rawValue)!
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, darkMode ? .dark : .light)
            .environment(\.theme, theme)
    }
}

public extension View {
    /// Sets and propagates the current theme based on the dark mode setting.
    func themed() -> some View {
        modifier(ThemeViewModifier())
    }
}
