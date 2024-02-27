//  Setting.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Defines a user defaults key and (when non-optional) default value.
public struct Setting<DefaultsValue> {
    public let `default`: DefaultsValue
    public let key: String

    init(key: String, `default`: DefaultsValue) {
        self.default = `default`
        self.key = key
    }
    init<R>(key: String) where DefaultsValue == R? {
        self.default = nil
        self.key = key
    }
}
