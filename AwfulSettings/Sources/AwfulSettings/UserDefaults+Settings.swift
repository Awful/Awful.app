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

public extension UserDefaults {
    func removeAllObjectsInMainBundleDomain() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        setPersistentDomain([:], forName: bundleID)
    }
}
