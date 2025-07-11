//  ThreadPage.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

public enum ThreadPage: Equatable, Hashable, Codable {

    /// Not sure what the last page is, but you want it.
    case last

    /// The first page that has unread posts.
    case nextUnread

    /// A particular page in the thread.
    case specific(Int)

    /// Convenient access to the oft-used "first page".
    public static let first = ThreadPage.specific(1)

    public static func == (lhs: ThreadPage, rhs: ThreadPage) -> Bool {
        switch (lhs, rhs) {
            case (.last, .last), (.nextUnread, .nextUnread):
                return true

            case (.specific(let lhs), .specific(let rhs)):
                return lhs == rhs

            case (.last, _), (.nextUnread, _), (.specific, _):
                return false
        }
    }
}

// MARK: - Codable Implementation

extension ThreadPage {
    enum CodingKeys: String, CodingKey {
        case type
        case pageNumber
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "first":
            self = .first
        case "last":
            self = .last
        case "nextUnread":
            self = .nextUnread
        case "specific":
            let pageNumber = try container.decode(Int.self, forKey: .pageNumber)
            self = .specific(pageNumber)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown ThreadPage type"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .first:
            try container.encode("first", forKey: .type)
        case .last:
            try container.encode("last", forKey: .type)
        case .nextUnread:
            try container.encode("nextUnread", forKey: .type)
        case .specific(let pageNumber):
            try container.encode("specific", forKey: .type)
            try container.encode(pageNumber, forKey: .pageNumber)
        }
    }
}
