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


/// HTML markup that has been parsed and serialized, but not otherwise altered from the original.
public struct RawHTML {
    public let rawValue: String

    public var isEmpty: Bool { return rawValue.isEmpty }
}


/// Forums user IDs sure look numeric, but we don't gain anything by assuming that. We'll just treat them as opaque strings.
public struct UserID {
    public let rawValue: String

    /// Empty user IDs are invalid.
    public var isEmpty: Bool { return rawValue.isEmpty }
}
