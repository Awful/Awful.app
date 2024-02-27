//  TaggedIDs.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// A tagged string representing a forum ID.
public struct ForumID: Codable, Hashable, Identifiable, RawRepresentable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public var id: String { rawValue }

    public init(rawValue: String) { self.init(rawValue) }
}
