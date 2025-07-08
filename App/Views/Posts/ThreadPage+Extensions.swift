//  ThreadPage+Extensions.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import Foundation

extension ThreadPage: Equatable {
    public static func == (lhs: ThreadPage, rhs: ThreadPage) -> Bool {
        switch (lhs, rhs) {
        case (.last, .last), (.nextUnread, .nextUnread):
            return true
        case (.specific(let l), .specific(let r)):
            return l == r
        default:
            return false
        }
    }
    var pageNumber: Int? {
        switch self {
        case .specific(let n): return n
        case .last: return nil // Will be handled separately
        case .nextUnread: return nil // Will be handled separately
        }
    }
    
    public func isLastPage(totalPages: Int) -> Bool {
        switch self {
        case .last:
            return true
        case .specific(let n):
            return n == totalPages
        case .nextUnread:
            return false
        }
    }

    var rawValue: String? {
        switch self {
        case .last: return "last"
        case .nextUnread: return "nextunread"
        case .specific(let n): return "specific\(n)"
        }
    }
    
    init?(rawValue: String) {
        if rawValue == "last" {
            self = .last
        } else if rawValue == "nextunread" {
            self = .nextUnread
        } else if rawValue.hasPrefix("specific") {
            let num = String(rawValue.dropFirst("specific".count))
            if let n = Int(num) {
                self = .specific(n)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    public func url(for thread: AwfulThread, writtenBy author: User?) -> URL? {
        guard var components = URLComponents(url: ForumsClient.shared.baseURL!, resolvingAgainstBaseURL: true) else { return nil }
        components.path = "/showthread.php"
        
        var queryItems: [URLQueryItem] = [.init(name: "threadid", value: thread.threadID)]
        switch self {
        case .last:
            queryItems.append(.init(name: "goto", value: "lastpost"))
        case .nextUnread:
            queryItems.append(.init(name: "goto", value: "newpost"))
        case .specific(let page):
            queryItems.append(.init(name: "pagenumber", value: "\(page)"))
        }
        
        if let author = author {
            queryItems.append(.init(name: "userid", value: author.userID))
        }
        
        components.queryItems = queryItems
        return components.url
    }
}