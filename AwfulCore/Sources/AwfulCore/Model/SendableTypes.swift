//  SendableTypes.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US

import Foundation

/// Thread-safe representation of an AwfulThread for use across concurrency boundaries
public struct ThreadInfo: Sendable, Equatable {
    public let threadID: String
    public let title: String?
    public let isBookmarked: Bool
    public let isClosed: Bool
    public let seenPosts: Int32
    public let totalReplies: Int32
    public let threadListPage: Int32
    public let bookmarkListPage: Int32
    public let starCategory: StarCategory
    public let isSticky: Bool
    public let authorUserID: String?
    public let authorUsername: String?
    public let forumID: String?
    public let threadTagID: String?
    public let secondaryThreadTagID: String?
    
    public init(
        threadID: String,
        title: String? = nil,
        isBookmarked: Bool = false,
        isClosed: Bool = false,
        seenPosts: Int32 = 0,
        totalReplies: Int32 = 0,
        threadListPage: Int32 = 0,
        bookmarkListPage: Int32 = 0,
        starCategory: StarCategory = .none,
        isSticky: Bool = false,
        authorUserID: String? = nil,
        authorUsername: String? = nil,
        forumID: String? = nil,
        threadTagID: String? = nil,
        secondaryThreadTagID: String? = nil
    ) {
        self.threadID = threadID
        self.title = title
        self.isBookmarked = isBookmarked
        self.isClosed = isClosed
        self.seenPosts = seenPosts
        self.totalReplies = totalReplies
        self.threadListPage = threadListPage
        self.bookmarkListPage = bookmarkListPage
        self.starCategory = starCategory
        self.isSticky = isSticky
        self.authorUserID = authorUserID
        self.authorUsername = authorUsername
        self.forumID = forumID
        self.threadTagID = threadTagID
        self.secondaryThreadTagID = secondaryThreadTagID
    }
}

/// Thread-safe representation of a User for use across concurrency boundaries
public struct UserInfo: Sendable, Equatable {
    public let userID: String
    public let username: String?
    public let isAdministrator: Bool
    public let isModerator: Bool
    public let canReceivePrivateMessages: Bool
    public let regdate: Date?
    
    public init(
        userID: String,
        username: String? = nil,
        isAdministrator: Bool = false,
        isModerator: Bool = false,
        canReceivePrivateMessages: Bool = true,
        regdate: Date? = nil
    ) {
        self.userID = userID
        self.username = username
        self.isAdministrator = isAdministrator
        self.isModerator = isModerator
        self.canReceivePrivateMessages = canReceivePrivateMessages
        self.regdate = regdate
    }
}

/// Thread-safe representation of a Post for use across concurrency boundaries
public struct PostInfo: Sendable, Equatable {
    public let postID: String
    public let threadID: String?
    public let authorUserID: String?
    public let authorUsername: String?
    public let postDate: Date?
    public let postIndex: Int32
    public let isEditable: Bool
    public let isIgnored: Bool
    
    // Additional properties for rendering and navigation
    public let page: Int32
    public let singleUserPage: Int32
    public let innerHTML: String?
    
    public init(
        postID: String,
        threadID: String? = nil,
        authorUserID: String? = nil,
        authorUsername: String? = nil,
        postDate: Date? = nil,
        postIndex: Int32 = 0,
        isEditable: Bool = false,
        isIgnored: Bool = false,
        page: Int32 = 1,
        singleUserPage: Int32 = 1,
        innerHTML: String? = nil
    ) {
        self.postID = postID
        self.threadID = threadID
        self.authorUserID = authorUserID
        self.authorUsername = authorUsername
        self.postDate = postDate
        self.postIndex = postIndex
        self.isEditable = isEditable
        self.isIgnored = isIgnored
        self.page = page
        self.singleUserPage = singleUserPage
        self.innerHTML = innerHTML
    }
}

/// Thread-safe representation of a Forum for use across concurrency boundaries
public struct ForumInfo: Sendable, Equatable {
    public let forumID: String
    public let name: String?
    public let canPost: Bool
    public let parentForumID: String?
    public let index: Int32
    
    public init(
        forumID: String,
        name: String? = nil,
        canPost: Bool = true,
        parentForumID: String? = nil,
        index: Int32 = 0
    ) {
        self.forumID = forumID
        self.name = name
        self.canPost = canPost
        self.parentForumID = parentForumID
        self.index = index
    }
}

/// Thread-safe representation of a PrivateMessage for use across concurrency boundaries
public struct PrivateMessageInfo: Sendable, Equatable {
    public let messageID: String
    public let subject: String?
    public let fromUserID: String?
    public let fromUsername: String?
    public let toUserID: String?
    public let toUsername: String?
    public let sentDate: Date?
    public let hasBeenSeen: Bool
    public let hasBeenForwarded: Bool
    public let hasBeenRepliedTo: Bool
    
    public init(
        messageID: String,
        subject: String? = nil,
        fromUserID: String? = nil,
        fromUsername: String? = nil,
        toUserID: String? = nil,
        toUsername: String? = nil,
        sentDate: Date? = nil,
        hasBeenSeen: Bool = false,
        hasBeenForwarded: Bool = false,
        hasBeenRepliedTo: Bool = false
    ) {
        self.messageID = messageID
        self.subject = subject
        self.fromUserID = fromUserID
        self.fromUsername = fromUsername
        self.toUserID = toUserID
        self.toUsername = toUsername
        self.sentDate = sentDate
        self.hasBeenSeen = hasBeenSeen
        self.hasBeenForwarded = hasBeenForwarded
        self.hasBeenRepliedTo = hasBeenRepliedTo
    }
}

/// Thread-safe representation of a ThreadTag for use across concurrency boundaries
public struct ThreadTagInfo: Sendable, Equatable {
    public let threadTagID: String
    public let imageName: String?
    public let threadTagName: String?
    
    public init(
        threadTagID: String,
        imageName: String? = nil,
        threadTagName: String? = nil
    ) {
        self.threadTagID = threadTagID
        self.imageName = imageName
        self.threadTagName = threadTagName
    }
}

// MARK: - Result Types for Complex Operations

import CoreData

/// Thread-safe result from fetching posts in a thread
public struct PostsPageResult: Sendable {
    /// Sendable representations of the posts for data access
    public let postInfos: [PostInfo]
    
    /// Core Data object IDs for reconstructing Post objects on main thread
    public let postObjectIDs: [NSManagedObjectID]
    
    /// Index of first unread post (1-based), if any
    public let firstUnreadPost: Int?
    
    /// HTML for advertisement banner
    public let advertisementHTML: String
    
    /// Page number information
    public let pageNumber: Int
    public let totalPages: Int
    
    public init(
        postInfos: [PostInfo],
        postObjectIDs: [NSManagedObjectID],
        firstUnreadPost: Int? = nil,
        advertisementHTML: String = "",
        pageNumber: Int = 1,
        totalPages: Int = 1
    ) {
        self.postInfos = postInfos
        self.postObjectIDs = postObjectIDs
        self.firstUnreadPost = firstUnreadPost
        self.advertisementHTML = advertisementHTML
        self.pageNumber = pageNumber
        self.totalPages = totalPages
    }
}
