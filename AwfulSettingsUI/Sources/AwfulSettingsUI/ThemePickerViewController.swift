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

    private static let themes = Theme.allThemes

    /// The selected theme's name, read from and written to the defaults key this
    /// picker edits. The default is the single source of truth, so a change made
    /// anywhere else (another screen, a settings reset) shows up here too.
    @AppStorage private var selectedThemeName: String?

    init(defaultMode mode: Theme.Mode) {
        self.forumID = nil
        self.mode = mode
        let key: String = switch mode {
        case .dark: Settings.defaultDarkThemeName.key
        case .light: Settings.defaultLightThemeName.key
        }
        _selectedThemeName = AppStorage(key)
    }

    init(forumID: String, mode: Theme.Mode) {
        self.forumID = forumID
        self.mode = mode
        _selectedThemeName = AppStorage(Theme.defaultsKeyForForum(identifiedBy: forumID, mode: mode))
    }

    var body: some View {
        List(Self.themes, id: \.name) { theme in
            let isSelected = theme.name == selectedThemeName
            Button {
                select(theme)
            } label: {
                ThemePickerRow(theme: theme, isSelected: isSelected)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .listRowBackground(
                Color(theme[uicolor: "listBackgroundColor"] ?? .systemBackground)
            )
        }
        .listStyle(.plain)
        .modifier(HiddenScrollBackground())
        .modifier(HiddenScrollEdgeEffect())
    }

    private func select(_ theme: Theme) {
        if let forumID {
            // Writes the same default that `selectedThemeName` observes, and posts
            // `Theme.themeForForumDidChangeNotification` for the app-wide cross-fade.
            Theme.setThemeName(theme.name, forForumIdentifiedBy: forumID, modes: [mode])
        } else {
            selectedThemeName = theme.name
        }
    }
}

/// One theme row, drawn in that theme's own colours and font. Its only inputs
/// are the theme (a stable reference) and whether it's selected, so SwiftUI
/// skips re-evaluating the rows that didn't change when the selection moves.
private struct ThemePickerRow: View {
    let theme: Theme
    let isSelected: Bool

    var body: some View {
        let textColor = Color(theme[uicolor: "listTextColor"] ?? .label)
        HStack {
            Text(theme.descriptiveName)
                .font(font)
                .foregroundStyle(textColor)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(textColor)
            }
        }
    }

    private var font: Font {
        if let fontName = theme[string: "listFontName"] {
            // 15pt is `.subheadline` at the default content size; `relativeTo` keeps it scaling with Dynamic Type.
            return .custom(fontName, size: 15, relativeTo: .subheadline)
        } else {
            return .subheadline
        }
    }
}
