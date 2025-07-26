//  SwiftUIThemePickerView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import SwiftUI

struct SwiftUIThemePickerView: View {
    let mode: Theme.Mode
    let forumID: String?
    let settingsKey: String
    
    @State private var selectedThemeName: String?
    @Environment(\.theme) private var currentTheme
    
    private let themes = Theme.allThemes
    
    init(mode: Theme.Mode, forumID: String? = nil) {
        self.mode = mode
        self.forumID = forumID
        
        if let forumID = forumID {
            self.settingsKey = Theme.defaultsKeyForForum(identifiedBy: forumID, mode: mode)
        } else {
            switch mode {
            case .dark:
                self.settingsKey = Settings.defaultDarkThemeName.key
            case .light:
                self.settingsKey = Settings.defaultLightThemeName.key
            }
        }
        
        self._selectedThemeName = State(initialValue: UserDefaults.standard.string(forKey: settingsKey))
    }
    
    var body: some View {
        List {
            ForEach(themes, id: \.name) { theme in
                ThemeRowView(
                    theme: theme,
                    isSelected: selectedThemeName == theme.name,
                    onSelect: {
                        selectTheme(theme)
                    }
                )
            }
        }
        .listStyle(.plain)
        .onAppear {
            selectedThemeName = UserDefaults.standard.string(forKey: settingsKey)
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            selectedThemeName = UserDefaults.standard.string(forKey: settingsKey)
        }
    }
    
    private func selectTheme(_ theme: Theme) {
        if let forumID = forumID {
            Theme.setThemeName(theme.name, forForumIdentifiedBy: forumID, modes: [mode])
        } else {
            UserDefaults.standard.set(theme.name, forKey: settingsKey)
        }
        selectedThemeName = theme.name
    }
}

private struct ThemeRowView: View {
    let theme: Theme
    let isSelected: Bool
    let onSelect: () -> Void
    
    @Environment(\.theme) private var currentTheme
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.descriptiveName)
                        .font(themeFont)
                        .foregroundColor(themeTextColor)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = themeSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(themeSecondaryTextColor)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(currentTheme[color: "tint"] ?? .blue)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(themeBackgroundColor)
    }
    
    private var themeFont: Font {
        if let fontName = theme[string: "listFontName"] {
            return Font.custom(fontName, size: 17)
        } else {
            return .body
        }
    }
    
    private var themeTextColor: Color {
        theme[color: "listTextColor"] ?? Color.primary
    }
    
    private var themeSecondaryTextColor: Color {
        theme[color: "listSecondaryTextColor"] ?? Color.secondary
    }
    
    private var themeBackgroundColor: Color {
        theme[color: "listBackgroundColor"] ?? Color(UIColor.systemBackground)
    }
    
    private var themeSubtitle: String? {
        // Show a preview of the theme's key characteristics
        if let backgroundColor = theme[color: "listBackgroundColor"],
           let textColor = theme[color: "listTextColor"] {
            return "Theme preview"
        }
        return nil
    }
}

#Preview {
    SwiftUIThemePickerView(mode: .light)
        .navigationTitle("Light Theme")
}