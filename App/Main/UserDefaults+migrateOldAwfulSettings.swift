//  UserDefaults+migrateOldAwfulSettings.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import Foundation

extension UserDefaults {

    private enum OldSettingsKeys {

        /// Value was an array of forumID strings. As of Awful 3.2, favorite forums are stored in Core Data.
        static let favoriteForums = "favorite_forums"

        /// Possible values: "never", "landscape", "portrait", "always".
        static let keepSidebarOpen = "keep_sidebar_open"

        /// Possible values: `true`, `false`.
        static let isAlternateThemeEnabled = "alternate_theme"

        /// An array of strings representing theme names of themes that should be made available for selection in any forum, not just the specific forum that the theme was created for. This is no longer a relevant concept, as we allow users to choose any theme. We don't even bother deleting the now-unused value for this key. It's simply documented here for posterity.
        static let ubiquitousThemeNames = "ubiquitous_theme_names"

        /// Possible values: "green", "amber", "macinyos", "winpos95".
        static let yosposStyle = "yospos_style"
    }

    func migrateOldAwfulSettings() {
        let userSpecifiedSettings = persistentDomain(forName: Bundle.main.bundleIdentifier!) ?? [:]

        var newYOSPOSStyle: String? {
            switch userSpecifiedSettings[OldSettingsKeys.yosposStyle] as? String {
            case "green": return "YOSPOS"
            case "amber": return "YOSPOS (amber)"
            case "macinyos": return "Macinyos"
            case "winpos95": return "Winpos 95"
            default: return nil
            }
        }
        if let newYOSPOSStyle = newYOSPOSStyle {
            Theme.setThemeName(newYOSPOSStyle, forForumIdentifiedBy: "219", modes: [.light, .dark])
            removeObject(forKey: OldSettingsKeys.yosposStyle)
        }

        switch userSpecifiedSettings[OldSettingsKeys.keepSidebarOpen] as? String {
        case "never", "portrait":
            @FoilDefaultStorage(Settings.hideSidebarInLandscape, userDefaults: self) var hideSidebarInLandscape
            hideSidebarInLandscape = true
            removeObject(forKey: OldSettingsKeys.keepSidebarOpen)
        default:
            break
        }

        // "Alternate App Theme" used to be a separate setting. Now we have default theme settings for each mode.
        if userSpecifiedSettings[OldSettingsKeys.isAlternateThemeEnabled] as? Bool == true {
            @FoilDefaultStorage(Settings.defaultDarkThemeName, userDefaults: self) var darkTheme
            darkTheme = .alternateDark
            @FoilDefaultStorage(Settings.defaultLightThemeName, userDefaults: self) var lightTheme
            lightTheme = .alternateDefault
            removeObject(forKey: OldSettingsKeys.isAlternateThemeEnabled)
        }

        // Now we set forum-specific themes for each mode, so migrate the old keys over.
        func parseForumSpecificThemeKey(_ key: String) -> String? {
            let scanner = Scanner(string: key)
            scanner.caseSensitive = true
            scanner.charactersToBeSkipped = nil
            guard
                scanner.scanString("theme-") != nil,
                let forumID = scanner.scanInt(),
                scanner.isAtEnd
                else { return nil }
            return String(forumID)
        }
        var keysToRemove: [String] = []
        // We don't want any registered defaults, just ones the user has set.
        for (key, themeName) in userSpecifiedSettings {
            guard
                let forumID = parseForumSpecificThemeKey(key),
                let themeName = themeName as? String
                else { continue }
            Theme.setThemeName(themeName, forForumIdentifiedBy: forumID, modes: [.light, .dark])
            keysToRemove.append(key)
        }
        for key in keysToRemove {
            removeObject(forKey: key)
        }
    }

    var oldFavoriteForums: [String]? {
        get { return object(forKey: OldSettingsKeys.favoriteForums) as? [String] }
        set { set(newValue, forKey: OldSettingsKeys.favoriteForums) }
    }
}

// MARK: - Previously-used keys

// Keys that we no longer use, but are documented here so we hopefully don't accidentally reuse a key and get surprised by existing values:

// static let automaticDarkModeBrightnessThresholdPercent = "auto_theme_threshold"
