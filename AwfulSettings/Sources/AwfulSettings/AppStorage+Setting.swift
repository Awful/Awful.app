//  AppStorage+Setting.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

/*
 Usage note: since the default value is already specified by `Setting`, you must not specify a wrapped value when declaring a wrapped property using these conveniences:

 ```
 // ok
 @AppStorage(Setting.autoplayGIFs) var autoplayGIFs

 // compile error
 @AppStorage(Setting.autoplayGIFs) var autoplayGIFs = false
 ```
 */

public extension AppStorage {
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == Bool {
        self.init(wrappedValue: setting.default, setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == Int {
        self.init(wrappedValue: setting.default, setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == Double {
        self.init(wrappedValue: setting.default, setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == String {
        self.init(wrappedValue: setting.default, setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == URL {
        self.init(wrappedValue: setting.default, setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == Data {
        self.init(wrappedValue: setting.default, setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == Int {
        self.init(wrappedValue: setting.default, setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == String {
        self.init(wrappedValue: setting.default, setting.key, store: store)
    }
}

public extension AppStorage where Value: ExpressibleByNilLiteral {
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == Bool? {
        self.init(setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == Int? {
        self.init(setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == Double? {
        self.init(setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == String? {
        self.init(setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == URL? {
        self.init(setting.key, store: store)
    }
    init(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == Data? {
        self.init(setting.key, store: store)
    }
    init<R>(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == R?, R: RawRepresentable, R.RawValue == Int {
        self.init(setting.key, store: store)
    }
    init<R>(_ setting: Setting<Value>, store: UserDefaults? = nil) where Value == R?, R: RawRepresentable, R.RawValue == String {
        self.init(setting.key, store: store)
    }
}
