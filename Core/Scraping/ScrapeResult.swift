//
//  ScrapeResult.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-26.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import HTMLReader

/**
 A common interface for all scrapers.
 */
public protocol ScrapeResult {
    init(_ html: HTMLNode) throws
}


// MARK: - Types common to several scrapers

/// Forums private message IDs sure look numeric, but we don't gain anything by assuming that. We'll just treat them as opaque strings.
public struct PrivateMessageID: Hashable {
    public let rawValue: String

    /// Empty private messageIDs are invalid.
    public var isEmpty: Bool { return rawValue.isEmpty }

    public static func ==(lhs: PrivateMessageID, rhs: PrivateMessageID) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }
}


/// HTML markup that has been parsed and serialized, but not otherwise altered from the original.
public struct RawHTML: Hashable {
    public let rawValue: String

    public static var empty: RawHTML { return RawHTML(rawValue: "") }
    public var isEmpty: Bool { return rawValue.isEmpty }

    public static func ==(lhs: RawHTML, rhs: RawHTML) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }
}


/// Forums user IDs sure look numeric, but we don't gain anything by assuming that. We'll just treat them as opaque strings.
public struct UserID: Hashable {
    public let rawValue: String

    /// Empty user IDs are invalid.
    public var isEmpty: Bool { return rawValue.isEmpty }

    public static func ==(lhs: UserID, rhs: UserID) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }
}
