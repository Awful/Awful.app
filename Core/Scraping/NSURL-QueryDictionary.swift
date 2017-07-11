//  NSURL-QueryDictionary.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

public extension NSURL {
    @objc var awful_queryDictionary: [String: String] {
        guard let absoluteString = absoluteString else { return [:] }
        return extractQueryDictionary(from: absoluteString)
    }
}

public extension URL {
    var awful_queryDictionary: [String: String] {
        return extractQueryDictionary(from: absoluteString)
    }
}

private func extractQueryDictionary(from: String) -> [String: String] {
    guard
        let url = URL(string: from),
        let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
        let queryItems = components.queryItems
        else { return [:] }
    return queryItems.reduce([:]) { acc, item in
        var acc = acc
        acc[item.name] = item.value ?? ""
        return acc
    }
}
