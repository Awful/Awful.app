//  LocalizedString.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

internal func LocalizedString(_ key: String) -> String {
    return NSLocalizedString(key, bundle: Bundle(for: AppDelegate.self), comment: "")
}
