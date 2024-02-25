//  ThemeMode+Presentation.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming

extension Theme.Mode {
    var localizedDescription: String {
        switch self {
        case .light:
            return LocalizedString("theme-mode.light")
        case .dark:
            return LocalizedString("theme-mode.dark")
        }
    }
}
