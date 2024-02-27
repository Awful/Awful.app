//  FoilDefaultStorage+Setting.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foil
import Foundation

public extension FoilDefaultStorage {
    /**
     Creates Foil-backed storage for a ``Setting``.

     Foil handles calling ``UserDefaults.registerDefaults`` and exposes a publisher as its `projectedValue`.

     Since `Setting` defines the storage type and a default value, you must not specify either when declaring a property with this wrapper:

     ```
     @FoilDefaultStorage(Setting.darkMode) var darkMode
     ```
     */
    init(
        _ setting: Setting<T>,
        userDefaults: UserDefaults = .standard
    ) {
        self.init(wrappedValue: setting.default, key: setting.key, userDefaults: userDefaults)
    }
}

public extension FoilDefaultStorageOptional {
    /**
     Creates Foil-backed storage for a ``Setting``.

     Exposes a publisher as its `projectedValue`.

     Since `Setting` defines the storage type, you must not specify it when declaring a property with this wrapper:

     ```
     @FoilDefaultStorageOptional(Setting.lastKnownUsername) var username
     ```
     */
    init(
        _ setting: Setting<T?>,
        userDefaults: UserDefaults = .standard
    ) {
        self.init(key: setting.key, userDefaults: userDefaults)
    }
}
