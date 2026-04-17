//  UserDefaults+Settings.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

// MARK: Keys still used in Objective-C code

public extension UserDefaults {

    // If you can't find anywhere these properties are used, please delete them!

    @objc class var automaticallyEnableDarkModeKey: String {
        Settings.autoDarkTheme.key
    }
    
    @objc class var isDarkModeEnabledKey: String {
        Settings.darkMode.key
    }
}

// MARK: Mass deletion

private let sessionKeys: Set<String> = [
    Settings.userID.key,
    Settings.username.key,
    Settings.canSendPrivateMessages.key,
    Settings.lastOfferedPasteboardURLString.key,
    Settings.imgurUploadMode.key,
]

public extension UserDefaults {
    /// Removes only session/auth-related keys, preserving user preferences.
    func removeSessionObjects() {
        for key in sessionKeys {
            removeObject(forKey: key)
        }
    }

    /// Removes all preference keys (everything except session/auth keys),
    /// restoring them to their defaults. The user stays logged in.
    ///
    /// Keys are removed individually rather than via `setPersistentDomain`
    /// so that KVO fires for each key and `@AppStorage` updates immediately.
    func resetPreferences() {
        for key in dictionaryRepresentation().keys where !sessionKeys.contains(key) {
            removeObject(forKey: key)
        }
    }
}
