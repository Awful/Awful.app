//  ScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

/**
 A common interface for all scrapers.
 */
public protocol ScrapeResult {
    init(_ html: HTMLNode, url: URL?) throws
}


// MARK: - Types common to several scrapers

/// Forum IDs sure look numeric but we're gonna treat them as opaque.
public struct ForumID: Hashable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}


/// Post IDs sure look numeric but we're gonna treat them as opaque.
public struct PostID: Hashable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}


/// Private message IDs sure look numeric but we're gonna treat them as opaque.
public struct PrivateMessageID: Hashable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
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
}


/// User IDs sure look numeric but we're gonna treat them as opaque.
public struct UserID: Hashable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}
