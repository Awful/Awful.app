//  NSURL-QueryDictionary.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

public extension NSURL {
    var awful_queryDictionary: [String: String] {
        guard let
            components = NSURLComponents(url: self as URL, resolvingAgainstBaseURL: true),
            queryItems = components.queryItems
            else { return [:] }
        return queryItems.reduce([:]) { acc, item in
            var acc = acc
            acc[item.name] = item.value ?? ""
            return acc
        }
    }
}
