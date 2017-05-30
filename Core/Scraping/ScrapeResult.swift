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

/// Forum IDs sure look numeric but we're gonna treat them as opaque.
public struct ForumID: Hashable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    public static func ==(lhs: ForumID, rhs: ForumID) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }
}


/// Post IDs sure look numeric but we're gonna treat them as opaque.
public struct PostID: Hashable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    public static func ==(lhs: PostID, rhs: PostID) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }
}


/// Private message IDs sure look numeric but we're gonna treat them as opaque.
public struct PrivateMessageID: Hashable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    public static func ==(lhs: PrivateMessageID, rhs: PrivateMessageID) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }
}


/// HTML markup that has been parsed and serialized, but not otherwise altered from the original. Since any string can be parsed as HTML, there's no real point making this fancier than a `typealias`.
public typealias RawHTML = String


/// Thread IDs sure look numeric but we're gonna treat them as opaque.
public struct ThreadID: Hashable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    public static func ==(lhs: ThreadID, rhs: ThreadID) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }
}


/// User IDs sure look numeric but we're gonna treat them as opaque.
public struct UserID: Hashable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    public static func ==(lhs: UserID, rhs: UserID) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }
}
