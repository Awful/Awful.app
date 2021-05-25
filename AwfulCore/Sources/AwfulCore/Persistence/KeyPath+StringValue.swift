//  KeyPath+StringValue.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension KeyPath where Root: NSObject {
    var stringValue: String {
        // This feels dodgy as it's not explicitly documented to work, but it seems to be the only way to turn a KeyPath into a String (convenient when using some Objective-C frameworks) using public API.
        NSExpression(forKeyPath: self).keyPath
    }
}
