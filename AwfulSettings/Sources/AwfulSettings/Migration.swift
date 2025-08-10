//  Migration.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulModelTypes
import Foil
import Foundation

public enum SettingsMigration {}

// MARK: - User defaults to user defaults

extension SettingsMigration {

    /**
     Move settings from no-longer-used user defaults keys into the current counterparts.

     There is one migration not covered here, because it went from user defaults to Core Data and this module doesn't know anything about Core Data: favorite forums.
     */
    public static func migrate(_ defaults: UserDefaults) {
        yosposStyle(defaults)
        keepSidebarOpen(defaults)
        alternateAppTheme(defaults)
        forumSpecificThemes(defaults)
        migrateImageHostingProvider(defaults)
    }

    static func yosposStyle(_ defaults: UserDefaults) {
        // Possible values: "green", "amber", "macinyos", "winpos95".
        let oldKey = "yospos_style"
        let newValue: String? = switch defaults.string(forKey: oldKey) {
        case "green": "YOSPOS"
        case "amber": "YOSPOS (amber)"
        case "macinyos": "Macinyos"
        case "winpos95": "Winpos 95"
        default: nil
        }

        if let newValue {
            // TODO: use actual theme module code instead of hardcoding format
            let newKeys = ["light", "dark"].map { "theme-\($0)-219" }
            for key in newKeys {
                defaults.set(newValue, forKey: key)
            }
            defaults.removeObject(forKey: oldKey)
        }
    }

    static func keepSidebarOpen(_ defaults: UserDefaults) {
        // Possible values: "never", "landscape", "portrait", "always".
        let oldKey = "keep_sidebar_open"
        switch defaults.string(forKey: oldKey) {
        case "never", "portrait":
            defaults.set(true, forKey: Settings.hideSidebarInLandscape.key)
            fallthrough
        case "landscape", "always":
            defaults.removeObject(forKey: oldKey)
        case nil:
            // Nothing to do.
            break
        default:
            // Unrecognized value. Keep it around, maybe we'll notice someday.
            break
        }
    }

    /// "Alternate App Theme" used to be a separate setting. Now we have default theme settings for each mode (light/dark).
    static func alternateAppTheme(_ defaults: UserDefaults) {
        // Possible values: `true`, `false`.
        let oldKey = "alternate_theme"
        if defaults.bool(forKey: oldKey) {
            // Kinda clunky to resort to Foil here, and a bit pointless to register defaults, but `UserDefaultsSerializable` is convenient here and outweights the clunk.
            var darkTheme = FoilDefaultStorage(Settings.defaultDarkThemeName, userDefaults: defaults)
            darkTheme.wrappedValue = .alternateDark
            var lightTheme = FoilDefaultStorage(Settings.defaultLightThemeName, userDefaults: defaults)
            lightTheme.wrappedValue = .alternateDefault
            defaults.removeObject(forKey: oldKey)
        }
    }

    /// Forums-specific themes now specify light/dark mode.
    static func forumSpecificThemes(_ defaults: UserDefaults) {
        for (oldKey, themeName) in defaults.persistentDomain(forName: Bundle.main.bundleIdentifier!) ?? [:] {
            guard let themeName = themeName as? String else { continue }
            var scanner = oldKey[...]
            guard scanner.scan("theme-"),
                  let forumID = scanner.scan(while: \.isWholeNumber),
                  scanner.isEmpty
            else { continue }

            // TODO: use actual theme module code instead of hardcoding format
            let newKeys = ["light", "dark"].map { "theme-\($0)-\(forumID)" }
            for key in newKeys {
                defaults.set(themeName, forKey: key)
            }
            defaults.removeObject(forKey: oldKey)
        }
    }
    
    /// Migrate all users to PostImages.org to encourage its use
    static func migrateImageHostingProvider(_ defaults: UserDefaults) {
        // Check if user has already been migrated
        let migrationKey = "did_migrate_to_postimages_v1"
        if defaults.bool(forKey: migrationKey) {
            return
        }
        
        // Check current Imgur mode to handle the "Off" case
        let imgurMode = defaults.string(forKey: Settings.imgurUploadMode.key)
        
        // If they had "Off", set Imgur mode to anonymous for when they switch back
        if imgurMode == "Off" {
            defaults.set("Anonymous", forKey: Settings.imgurUploadMode.key)
        }
        
        // Move everyone to PostImages.org by default (they can switch back if they want)
        defaults.set("PostImages", forKey: Settings.imageHostingProvider.key)
        
        // Mark migration as complete
        defaults.set(true, forKey: migrationKey)
    }
}

// MARK: - User defaults to Core Data

extension SettingsMigration {

    /// Returns the favorite forums stored in user defaults. May be empty. Returns nil if no favorite forum information is found.
    public static func favoriteForums(_ defaults: UserDefaults) -> [ForumID]? {
        guard let rawIDs = defaults.object(forKey: favoriteForums) as? [String] else {
            return nil
        }
        return rawIDs.map { ForumID($0) }
    }

    public static func forgetFavoriteForums(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: favoriteForums)
    }

    /// Value was an array of forum ID strings. As of Awful 3.2, favorite forums are stored in Core Data.
    private static let favoriteForums = "favorite_forums"
}
