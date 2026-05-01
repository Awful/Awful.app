//  ThemePickerView.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import SwiftUI
import UIKit

/// Wraps `.scrollContentBackground(.hidden)` (iOS 16+) so the surrounding
/// container's background can show through; on iOS 15 it's a no-op.
private struct HiddenScrollBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

/// Hide iOS 26's scroll-edge effect on all edges so dark cells don't fade
/// into a visible light gradient at the tab-bar overlap. No-op on earlier iOS.
private struct HiddenScrollEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true)
        } else {
            content
        }
    }
}



/// A simple SwiftUI list of available themes. Each row is themed using its
/// own colours so the user can preview the look. Tapping a row records the
/// selection (either as the default light/dark theme or as a forum-specific
/// override).
struct ThemePickerView: View {

    let forumID: String?
    let mode: Theme.Mode

    private let themes = Theme.allThemes
    private let settingsKey: String

    @State private var selectedThemeName: String

    init(defaultMode mode: Theme.Mode) {
        self.forumID = nil
        self.mode = mode
        let key: String
        switch mode {
        case .dark: key = Settings.defaultDarkThemeName.key
        case .light: key = Settings.defaultLightThemeName.key
        }
        self.settingsKey = key
        self._selectedThemeName = State(initialValue: UserDefaults.standard.string(forKey: key) ?? "")
    }

    init(forumID: String, mode: Theme.Mode) {
        self.forumID = forumID
        self.mode = mode
        let key = Theme.defaultsKeyForForum(identifiedBy: forumID, mode: mode)
        self.settingsKey = key
        self._selectedThemeName = State(initialValue: UserDefaults.standard.string(forKey: key) ?? "")
    }

    var body: some View {
        List(themes, id: \.name) { theme in
            row(for: theme)
                .listRowBackground(
                    Color(theme[uicolor: "listBackgroundColor"] ?? .systemBackground)
                )
        }
        .listStyle(.plain)
        .modifier(HiddenScrollBackground())
        .modifier(HiddenScrollEdgeEffect())
    }

    @ViewBuilder
    private func row(for theme: Theme) -> some View {
        let textColor = Color(theme[uicolor: "listTextColor"] ?? .label)
        HStack {
            Text(theme.descriptiveName)
                .font(font(for: theme))
                .foregroundStyle(textColor)
            Spacer()
            if theme.name == selectedThemeName {
                Image(systemName: "checkmark")
                    .foregroundStyle(textColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            select(theme)
        }
    }

    private func font(for theme: Theme) -> Font {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
        guard
            let fontName = theme[string: "listFontName"] ?? descriptor.object(forKey: .name) as? String,
            let uiFont = UIFont(name: fontName, size: descriptor.pointSize)
        else {
            return .subheadline
        }
        return Font(uiFont)
    }

    private func select(_ theme: Theme) {
        selectedThemeName = theme.name
        if let forumID {
            Theme.setThemeName(theme.name, forForumIdentifiedBy: forumID, modes: [mode])
        } else {
            UserDefaults.standard.set(theme.name, forKey: settingsKey)
        }
    }
}
