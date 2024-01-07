//  String+.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

// MARK: Collapsing whitespace

public extension String {
    /// Replaces all consecutive runs of whitespace (regex `\s`) with a single space.
    mutating func collapseWhitespace() {
        self = collapseWhitespaceRegex.stringByReplacingMatches(
            in: self,
            range: NSRange(startIndex..., in: self),
            withTemplate: " "
        )
    }

    /// Returns a copy of the string with all consecutive runs of whitespace (regex `\s`) replaced by a single space.
    func collapsingWhitespace() -> String {
        var collapsed = self
        collapsed.collapseWhitespace()
        return collapsed
    }
}

private let collapseWhitespaceRegex = try! NSRegularExpression(pattern: "\\s+")
