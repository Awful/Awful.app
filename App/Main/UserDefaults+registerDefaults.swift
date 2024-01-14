//  UserDefaults+registerDefaults.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import Foundation

extension UserDefaults {
    func registerDefaults(_ sections: [SettingsSection]) {
        var defaults = sections.reduce(into: [:]) { defaults, section in
            defaults.merge(section.defaultValues, uniquingKeysWith: { $1 })
        }
        defaults[SettingsKeys.defaultDarkTheme] = SystemCapabilities.oled ? "oledDark" : "dark"
        defaults[SettingsKeys.defaultLightTheme] = SystemCapabilities.oled ? "brightLight" : "default"
        defaults.merge(Theme.forumSpecificDefaults, uniquingKeysWith: { $1 })
        register(defaults: defaults)
    }
}
