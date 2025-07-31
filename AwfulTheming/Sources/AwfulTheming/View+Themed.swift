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
    @AppStorage(Settings.autoDarkTheme) var autoDarkTheme
    @AppStorage(Settings.darkMode) var darkMode
    @SwiftUI.Environment(\.colorScheme) var systemColorScheme

    var effectiveDarkMode: Bool {
        if autoDarkTheme {
            return systemColorScheme == .dark
        } else {
            return darkMode
        }
    }

    var theme: Theme {
        // TODO: Wrap this up somewhere closer to the Theme.defaultTheme() implementation so we have one source of truth for resolving "default theme".
        Theme.theme(named: (effectiveDarkMode ? darkThemeName : lightThemeName).rawValue)!
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, effectiveDarkMode ? .dark : .light)
            .environment(\.theme, theme)
    }
}

public extension View {
    /// Sets and propagates the current theme based on the dark mode setting.
    func themed() -> some View {
        modifier(ThemeViewModifier())
    }
}
