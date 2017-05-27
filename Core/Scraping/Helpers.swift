//
//  Helpers.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-26.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import Foundation
import HTMLReader

internal func LocalizedString(_ key: String) -> String {
    return NSLocalizedString(key, bundle: Bundle(for: ForumsClient.self), comment: "")
}


internal extension HTMLNode {
    var nextSibling: HTMLNode? {
        guard let parent = parent else { return nil }

        let i = parent.index(ofChild: self)
        guard i != UInt(NSNotFound), i + 1 < parent.numberOfChildren else { return nil }

        return parent.child(at: i + 1)
    }
}


internal func makeScrapingDateFormatter(format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = format
    return formatter
}


internal extension Scanner {
    func scanCharacters(from cs: CharacterSet) -> String? {
        var result: NSString?
        guard scanCharacters(from: cs, into: &result) else { return nil }
        return result as String?
    }

    func scanInt() -> Int? {
        var result: Int = 0
        guard scanInt(&result) else { return nil }
        return result
    }

    func scanUpToAndPast(_ s: String) -> Bool {
        scanUpTo(s, into: nil)
        return scanString(s, into: nil)
    }
}
